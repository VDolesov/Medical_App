const express = require('express');
const multer = require('multer');
const xlsx = require('xlsx');
const fs = require('fs');

const pool = require('../db');
const { authenticate } = require('../middleware/auth');
const { buildReport, collectPatients } = require('../services/reports/build');

const router = express.Router();
const upload = multer({ dest: 'uploads/' });

const CHUNK = 500;

async function upsertPatients(client, patients) {
    const ids = new Map();
    if (patients.length === 0) {
        return ids;
    }

    const existing = await client.query(
        'SELECT id, code FROM patients WHERE code = ANY($1::text[])',
        [patients.map(p => p.code)]
    );
    for (const row of existing.rows) {
        ids.set(row.code, row.id);
    }

    const missing = patients.filter(p => !ids.has(p.code));
    for (let i = 0; i < missing.length; i += CHUNK) {
        const chunk = missing.slice(i, i + CHUNK);
        const values = [];
        const params = [];
        chunk.forEach((patient, idx) => {
            const base = idx * 2;
            values.push(`($${base + 1}, $${base + 2})`);
            params.push(patient.code, patient.age);
        });
        const inserted = await client.query(
            `INSERT INTO patients (code, age) VALUES ${values.join(', ')} ON CONFLICT (code) DO NOTHING RETURNING id, code`,
            params
        );
        for (const row of inserted.rows) {
            ids.set(row.code, row.id);
        }
    }

    const stillMissing = missing.filter(p => !ids.has(p.code)).map(p => p.code);
    if (stillMissing.length > 0) {
        const refetched = await client.query(
            'SELECT id, code FROM patients WHERE code = ANY($1::text[])',
            [stillMissing]
        );
        for (const row of refetched.rows) {
            ids.set(row.code, row.id);
        }
    }
    return ids;
}

async function insertResults(client, results, patientIds) {
    const rows = results
        .map(r => ({ patientId: patientIds.get(r.code), normId: r.normId, value: r.value }))
        .filter(r => r.patientId !== undefined);

    for (let i = 0; i < rows.length; i += CHUNK) {
        const chunk = rows.slice(i, i + CHUNK);
        const values = [];
        const params = [];
        chunk.forEach((row, idx) => {
            const base = idx * 3;
            values.push(`($${base + 1}, $${base + 2}, $${base + 3}, NOW())`);
            params.push(row.patientId, row.normId, row.value);
        });
        await client.query(
            `INSERT INTO analysis_results (patient_id, norm_id, value, date) VALUES ${values.join(', ')}`,
            params
        );
    }
}

/**
 * @swagger
 * /upload:
 *   post:
 *     summary: Загрузка файла с анализами (только для врача или администратора)
 *     tags: [Analysis]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               file:
 *                 type: string
 *                 format: binary
 *     responses:
 *       200:
 *         description: Отчёт по анализам для каждого пациента и id отчёта
 *       403:
 *         description: Нет прав на загрузку
 *       500:
 *         description: Внутренняя ошибка сервера
 */
router.post('/upload', authenticate, upload.single('file'), async (req, res) => {
    if (!['doctor', 'admin'].includes(req.user.role)) {
        return res.status(403).json({ error: 'Нет прав на загрузку' });
    }
    if (!req.file) {
        return res.status(400).json({ error: 'Файл не передан' });
    }

    const client = await pool.connect();
    try {
        const wb = xlsx.readFile(req.file.path);
        const ws = wb.Sheets[wb.SheetNames[0]];
        const rows = xlsx.utils.sheet_to_json(ws);

        const normsRes = await client.query('SELECT * FROM analysis_norms');
        const norms = {};
        normsRes.rows.forEach(n => {
            norms[n.name] = n;
        });

        const { report, results } = buildReport(rows, norms);
        const patients = collectPatients(rows);

        await client.query('BEGIN');

        const patientIds = await upsertPatients(client, patients);
        await insertResults(client, results, patientIds);

        const reportInsert = await client.query(
            'INSERT INTO analysis_reports (user_id, file_name, report_data) VALUES ($1, $2, $3) RETURNING id',
            [req.user.userId, req.file.originalname, JSON.stringify(report)]
        );

        await client.query('COMMIT');
        res.json({ reportId: reportInsert.rows[0].id, report });
    } catch (e) {
        await client.query('ROLLBACK').catch(() => {});
        console.error('upload failed:', e);
        res.status(500).json({ error: 'Не удалось обработать файл' });
    } finally {
        client.release();
        fs.unlink(req.file.path, () => {});
    }
});

/**
 * @swagger
 * /reports:
 *   get:
 *     summary: Получить список своих отчётов (только для врача)
 *     tags: [Reports]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Список отчётов пользователя
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/ReportMeta'
 *       403:
 *         description: Доступ запрещён
 */
router.get('/reports', authenticate, async (req, res) => {
    if (req.user.role !== 'doctor') {
        return res.status(403).json({ error: 'Доступ запрещён' });
    }
    const result = await pool.query(
        'SELECT id, file_name, created_at FROM analysis_reports WHERE user_id=$1 ORDER BY created_at DESC',
        [req.user.userId]
    );
    res.json(result.rows);
});

/**
 * @swagger
 * /report/{id}:
 *   get:
 *     summary: Получить подробный отчёт по id
 *     tags: [Reports]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         schema: { type: integer }
 *       - name: page
 *         in: query
 *         schema: { type: integer }
 *       - name: limit
 *         in: query
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: Подробный отчёт с постраничной разбивкой
 *       404:
 *         description: Не найдено
 */
router.get('/report/:id', authenticate, async (req, res) => {
    const { id } = req.params;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const offset = (page - 1) * limit;

    const row = await pool.query(
        'SELECT report_data FROM analysis_reports WHERE id=$1 AND user_id=$2',
        [id, req.user.userId]
    );
    if (!row.rows.length) {
        return res.status(404).json({ error: 'Not found' });
    }

    let allPatients = row.rows[0].report_data;
    if (!Array.isArray(allPatients)) {
        allPatients = Object.values(allPatients);
    }

    res.json({
        total: allPatients.length,
        page,
        limit,
        patients: allPatients.slice(offset, offset + limit),
    });
});

/**
 * @swagger
 * /report/{id}:
 *   delete:
 *     summary: Удалить отчёт по id
 *     tags: [Reports]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: Отчёт успешно удалён
 *       404:
 *         description: Не найдено
 */
router.delete('/report/:id', authenticate, async (req, res) => {
    const { id } = req.params;
    const row = await pool.query(
        'SELECT 1 FROM analysis_reports WHERE id=$1 AND user_id=$2',
        [id, req.user.userId]
    );
    if (!row.rows.length) {
        return res.status(404).json({ error: 'Not found' });
    }
    await pool.query('DELETE FROM analysis_reports WHERE id=$1', [id]);
    res.json({ success: true });
});

module.exports = router;
