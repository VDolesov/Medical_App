const express = require('express');
const multer = require('multer');
const xlsx = require('xlsx');
const fs = require('fs');

const pool = require('../db');
const { authenticate } = require('../middleware/auth');

const router = express.Router();
const upload = multer({ dest: 'uploads/' });

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
    try {
        const wb = xlsx.readFile(req.file.path);
        const ws = wb.Sheets[wb.SheetNames[0]];
        const rows = xlsx.utils.sheet_to_json(ws);
        const report = [];

        const normsRes = await pool.query('SELECT * FROM analysis_norms');
        const norms = {};
        normsRes.rows.forEach(n => {
            norms[n.name] = n;
        });

        for (const row of rows) {
            const code = row['Код пациента'];
            const age = row['Возраст'];

            if (!code || code.toString().trim() === '' || !age) continue;

            const patientRes = await pool.query('SELECT * FROM patients WHERE code=$1', [code]);
            let patient;
            if (patientRes.rows.length === 0) {
                const inserted = await pool.query(
                    'INSERT INTO patients (code, age) VALUES ($1, $2) RETURNING *',
                    [code, age]
                );
                patient = inserted.rows[0];
            } else {
                patient = patientRes.rows[0];
            }

            const patientReport = { code, age, outOfNorms: [] };

            for (const col of Object.keys(row)) {
                if (col === 'Код пациента' || col === 'Возраст') continue;
                const norm = norms[col];
                if (!norm) continue;

                const value = parseFloat(row[col]);
                if (isNaN(value)) continue;

                await pool.query(
                    'INSERT INTO analysis_results (patient_id, norm_id, value, date) VALUES ($1, $2, $3, NOW())',
                    [patient.id, norm.id, value]
                );
                if (value < norm.min_value || value > norm.max_value) {
                    patientReport.outOfNorms.push({
                        analysis: col,
                        value,
                        min: norm.min_value,
                        max: norm.max_value,
                        unit: norm.unit,
                        status: value < norm.min_value ? 'ниже нормы' : 'выше нормы',
                    });
                }
            }

            if (patientReport.outOfNorms.length === 0) {
                patientReport.outOfNorms = ['Все значения в норме'];
            }
            report.push(patientReport);
        }

        const reportInsert = await pool.query(
            'INSERT INTO analysis_reports (user_id, file_name, report_data) VALUES ($1, $2, $3) RETURNING id',
            [req.user.userId, req.file.originalname, JSON.stringify(report)]
        );

        fs.unlinkSync(req.file.path);
        res.json({ reportId: reportInsert.rows[0].id, report });
    } catch (e) {
        console.error('upload failed:', e);
        res.status(500).json({ error: 'Не удалось обработать файл' });
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
