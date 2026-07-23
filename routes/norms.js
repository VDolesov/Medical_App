const express = require('express');

const pool = require('../db');
const { authenticate, requireAdmin } = require('../middleware/auth');

const router = express.Router();

/**
 * @swagger
 * /norms:
 *   get:
 *     summary: Получить все нормы анализов
 *     description: Возвращает полный список медицинских норм. Только для авторизованных пользователей.
 *     tags: [Norms]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Список норм
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/Norm'
 *       401:
 *         description: Требуется авторизация
 */
router.get('/norms', authenticate, async (req, res) => {
    const norms = await pool.query('SELECT * FROM analysis_norms ORDER BY id');
    res.json(norms.rows);
});

/**
 * @swagger
 * /norms:
 *   post:
 *     summary: Добавить новую норму анализа (только администратор)
 *     tags: [Norms]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *               - min_value
 *               - max_value
 *               - unit
 *             properties:
 *               name: { type: string, example: Калий }
 *               min_value: { type: number, example: 3.5 }
 *               max_value: { type: number, example: 5.1 }
 *               unit: { type: string, example: ммоль/л }
 *     responses:
 *       200:
 *         description: Норма успешно добавлена
 *       400:
 *         description: Ошибка валидации
 *       403:
 *         description: Требуются права администратора
 */
router.post('/norms', authenticate, requireAdmin, async (req, res) => {
    const { name, min_value, max_value, unit } = req.body;
    if (!name || min_value == null || max_value == null || !unit) {
        return res.status(400).json({ error: 'Все поля обязательны' });
    }
    try {
        await pool.query(
            'INSERT INTO analysis_norms (name, min_value, max_value, unit) VALUES ($1, $2, $3, $4)',
            [name, min_value, max_value, unit]
        );
        res.json({ message: 'Норма успешно добавлена' });
    } catch (err) {
        if (err && err.code === '23505') {
            return res.status(400).json({ error: 'Норма с таким названием уже существует' });
        }
        console.error('create norm failed:', err);
        res.status(500).json({ error: 'Внутренняя ошибка сервера' });
    }
});

/**
 * @swagger
 * /norms/{id}:
 *   put:
 *     summary: Редактировать норму анализа (только администратор)
 *     tags: [Norms]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         schema: { type: integer }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name: { type: string }
 *               min_value: { type: number }
 *               max_value: { type: number }
 *               unit: { type: string }
 *     responses:
 *       200:
 *         description: Норма успешно обновлена
 *       404:
 *         description: Норма не найдена
 */
router.put('/norms/:id', authenticate, requireAdmin, async (req, res) => {
    const { id } = req.params;
    const { name, min_value, max_value, unit } = req.body;
    if (!name || min_value == null || max_value == null || !unit) {
        return res.status(400).json({ error: 'Все поля обязательны' });
    }
    const updateRes = await pool.query(
        'UPDATE analysis_norms SET name=$1, min_value=$2, max_value=$3, unit=$4 WHERE id=$5 RETURNING *',
        [name, min_value, max_value, unit, id]
    );
    if (updateRes.rowCount === 0) {
        return res.status(404).json({ error: 'Норма не найдена' });
    }
    res.json({ message: 'Норма успешно обновлена' });
});

/**
 * @swagger
 * /norms/{id}:
 *   delete:
 *     summary: Удалить норму анализа (только администратор)
 *     tags: [Norms]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: Норма успешно удалена
 *       404:
 *         description: Норма не найдена
 */
router.delete('/norms/:id', authenticate, requireAdmin, async (req, res) => {
    const { id } = req.params;
    const del = await pool.query('DELETE FROM analysis_norms WHERE id=$1 RETURNING *', [id]);
    if (del.rowCount === 0) {
        return res.status(404).json({ error: 'Норма не найдена' });
    }
    res.json({ message: 'Норма успешно удалена' });
});

module.exports = router;
