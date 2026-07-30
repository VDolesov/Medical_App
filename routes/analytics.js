const express = require('express');

const pool = require('../db');
const { authenticate } = require('../middleware/auth');
const scoring = require('../services/analytics/scoring');

const router = express.Router();

const HISTORY_DEPTH = 5;

function rowsOf(reportData) {
    if (Array.isArray(reportData)) {
        return reportData;
    }
    if (reportData && typeof reportData === 'object') {
        return Object.values(reportData);
    }
    return [];
}

function codeOf(slice) {
    if (!slice || slice.code === undefined || slice.code === null) {
        return null;
    }
    return String(slice.code);
}

async function loadReport(id, user) {
    if (!/^\d+$/.test(String(id))) {
        return null;
    }
    const result = user.role === 'admin'
        ? await pool.query('SELECT id, user_id, report_data, created_at FROM analysis_reports WHERE id=$1', [id])
        : await pool.query(
            'SELECT id, user_id, report_data, created_at FROM analysis_reports WHERE id=$1 AND user_id=$2',
            [id, user.userId]
        );
    return result.rows[0] || null;
}

async function previousScores(report) {
    const result = await pool.query(
        `SELECT report_data FROM analysis_reports
         WHERE user_id=$1 AND id <> $2 AND created_at < $3
         ORDER BY created_at DESC
         LIMIT $4`,
        [report.user_id, report.id, report.created_at, HISTORY_DEPTH]
    );
    const scores = new Map();
    for (const row of result.rows) {
        for (const slice of rowsOf(row.report_data)) {
            const code = codeOf(slice);
            if (code === null || scores.has(code)) {
                continue;
            }
            scores.set(code, scoring.compute(slice).riskScore);
        }
    }
    return scores;
}

function buildViews(report, previous) {
    return rowsOf(report.report_data).map((slice, index) => {
        const code = codeOf(slice);
        const score = scoring.compute(slice);
        const prev = code !== null && previous.has(code) ? previous.get(code) : null;
        const trend = scoring.compareTrend(score.riskScore, prev);
        return {
            reportPatientId: index,
            sortOrder: index,
            patientCode: code === null ? '?' : code,
            age: slice && slice.age !== undefined ? slice.age : null,
            riskScore: score.riskScore,
            riskLevel: score.riskLevel,
            features: {
                deviationCount: score.deviationCount,
                markerStrengths: score.markerStrengths,
                topFactors: score.topFactors,
                trend,
            },
            explanationText: scoring.buildExplanation(score, trend, prev),
        };
    });
}

function buildSummary(views) {
    let sum = 0;
    let countLow = 0;
    let countMedium = 0;
    let countHigh = 0;
    for (const view of views) {
        sum += view.riskScore;
        if (view.riskLevel === 'LOW') countLow++;
        else if (view.riskLevel === 'MEDIUM') countMedium++;
        else if (view.riskLevel === 'HIGH') countHigh++;
    }
    return {
        restrictedView: false,
        linkedPatientCount: views.length,
        generatedCount: views.length,
        averageRisk: views.length > 0 ? Math.round(sum / views.length) : null,
        countLow,
        countMedium,
        countHigh,
        scores: views.map(view => ({
            sortOrder: view.sortOrder,
            patientCode: view.patientCode,
            riskScore: view.riskScore,
            riskLevel: view.riskLevel,
        })),
    };
}

async function viewsForReport(req, res) {
    const report = await loadReport(req.params.id, req.user);
    if (!report) {
        res.status(404).json({ error: 'Not found' });
        return null;
    }
    const previous = await previousScores(report);
    return buildViews(report, previous);
}

/**
 * @swagger
 * /analytics/report/{id}/summary:
 *   get:
 *     summary: Сводка по отчёту — распределение по уровням и точки графика
 *     tags: [Analytics]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: Агрегированные показатели по отчёту
 *       404:
 *         description: Отчёт не найден или нет доступа
 */
router.get('/analytics/report/:id/summary', authenticate, async (req, res) => {
    try {
        const views = await viewsForReport(req, res);
        if (!views) return;
        res.json(buildSummary(views));
    } catch (e) {
        console.error('analytics summary failed:', e);
        res.status(500).json({ error: 'Не удалось посчитать аналитику' });
    }
});

/**
 * @swagger
 * /analytics/report/{id}/patients:
 *   get:
 *     summary: Пациенты отчёта с индексом отклонений и объяснением
 *     tags: [Analytics]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: Массив пациентов с оценкой
 *       404:
 *         description: Отчёт не найден или нет доступа
 */
router.get('/analytics/report/:id/patients', authenticate, async (req, res) => {
    try {
        const views = await viewsForReport(req, res);
        if (!views) return;
        res.json(views);
    } catch (e) {
        console.error('analytics patients failed:', e);
        res.status(500).json({ error: 'Не удалось посчитать аналитику' });
    }
});

/**
 * @swagger
 * /analytics/report/{id}/generate:
 *   post:
 *     summary: Пересчитать аналитику отчёта
 *     description: Оценка считается по актуальному содержимому отчёта, доступно врачу и администратору.
 *     tags: [Analytics]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: Пересчитанные оценки по пациентам
 *       403:
 *         description: Нет прав на пересчёт
 *       404:
 *         description: Отчёт не найден или нет доступа
 */
router.post('/analytics/report/:id/generate', authenticate, async (req, res) => {
    if (!['doctor', 'admin'].includes(req.user.role)) {
        return res.status(403).json({ error: 'Нет прав на пересчёт аналитики' });
    }
    try {
        const views = await viewsForReport(req, res);
        if (!views) return;
        res.json(views);
    } catch (e) {
        console.error('analytics generate failed:', e);
        res.status(500).json({ error: 'Не удалось посчитать аналитику' });
    }
});

module.exports = router;
