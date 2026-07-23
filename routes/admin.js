const express = require('express');
const bcrypt = require('bcrypt');

const pool = require('../db');
const { authenticate, requireAdmin } = require('../middleware/auth');

const router = express.Router();

router.use('/admin', authenticate, requireAdmin);

/**
 * @swagger
 * /admin/users:
 *   get:
 *     summary: Получить список всех пользователей (только для администратора)
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Список пользователей
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/User'
 *       403:
 *         description: Требуются права администратора
 */
router.get('/admin/users', async (req, res) => {
    const users = await pool.query(
        'SELECT id, username, first_name, last_name, role FROM users ORDER BY id'
    );
    res.json(users.rows);
});

/**
 * @swagger
 * /admin/users:
 *   post:
 *     summary: Создать нового пользователя (только для администратора)
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - username
 *               - password
 *               - email
 *               - firstName
 *               - lastName
 *               - role
 *             properties:
 *               username: { type: string }
 *               password: { type: string }
 *               email: { type: string }
 *               firstName: { type: string }
 *               lastName: { type: string }
 *               role:
 *                 type: string
 *                 enum: [doctor, admin]
 *     responses:
 *       200:
 *         description: Пользователь создан
 *       400:
 *         description: Ошибка валидации
 */
router.post('/admin/users', async (req, res) => {
    const { username, password, email, firstName, lastName, role } = req.body;
    const allowedRoles = ['doctor', 'admin'];

    if (!allowedRoles.includes(role)) {
        return res.status(400).json({ error: 'Роль должна быть doctor или admin' });
    }
    if (typeof password !== 'string' || password.length < 8) {
        return res.status(400).json({ error: 'Минимальная длина пароля — 8 символов' });
    }

    const exists = await pool.query(
        'SELECT id FROM users WHERE username=$1 OR email=$2',
        [username, email]
    );
    if (exists.rows.length) {
        return res.status(400).json({ error: 'Пользователь с таким username или email уже существует' });
    }

    const hash = await bcrypt.hash(password, 10);
    try {
        await pool.query(
            'INSERT INTO users (username, password_hash, email, first_name, last_name, role) VALUES ($1, $2, $3, $4, $5, $6)',
            [username, hash, email, firstName, lastName, role]
        );
        res.json({ message: 'Пользователь создан' });
    } catch (err) {
        console.error('create user failed:', err);
        res.status(500).json({ error: 'Внутренняя ошибка сервера' });
    }
});

/**
 * @swagger
 * /admin/users/{id}:
 *   patch:
 *     summary: Изменить пользователя (только для администратора)
 *     tags: [Admin]
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
 *               email: { type: string }
 *               firstName: { type: string }
 *               lastName: { type: string }
 *               role: { type: string }
 *               password: { type: string }
 *     responses:
 *       200:
 *         description: Данные пользователя обновлены
 *       404:
 *         description: Пользователь не найден
 */
router.patch('/admin/users/:id', async (req, res) => {
    const { id } = req.params;
    const { email, firstName, lastName, role, password } = req.body;

    const userRes = await pool.query('SELECT id FROM users WHERE id=$1', [id]);
    if (!userRes.rows.length) {
        return res.status(404).json({ error: 'Пользователь не найден' });
    }

    const updates = [];
    const values = [];
    let idx = 1;

    if (email) { updates.push(`email=$${idx++}`); values.push(email); }
    if (firstName) { updates.push(`first_name=$${idx++}`); values.push(firstName); }
    if (lastName) { updates.push(`last_name=$${idx++}`); values.push(lastName); }
    if (role) { updates.push(`role=$${idx++}`); values.push(role); }

    if (password) {
        if (password.length < 8) {
            return res.status(400).json({ error: 'Минимальная длина пароля — 8 символов' });
        }
        updates.push(`password_hash=$${idx++}`);
        values.push(await bcrypt.hash(password, 10));
    }

    if (updates.length === 0) {
        return res.json({ message: 'Нет изменений' });
    }

    values.push(id);
    await pool.query(`UPDATE users SET ${updates.join(', ')} WHERE id=$${idx}`, values);
    res.json({ message: 'Пользователь обновлён' });
});

/**
 * @swagger
 * /admin/users/{id}:
 *   delete:
 *     summary: Удалить пользователя по id (только для администратора)
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: Пользователь удалён
 *       400:
 *         description: Нельзя удалить самого себя
 */
router.delete('/admin/users/:id', async (req, res) => {
    const { id } = req.params;
    if (req.user.userId == id) {
        return res.status(400).json({ error: 'Нельзя удалить самого себя!' });
    }
    await pool.query('DELETE FROM users WHERE id=$1', [id]);
    res.json({ message: 'Пользователь удалён' });
});

/**
 * @swagger
 * /admin/reports:
 *   get:
 *     summary: Получить все отчёты всех пользователей (только для администратора)
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Список всех отчётов
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/ReportMeta'
 */
router.get('/admin/reports', async (req, res) => {
    const rows = await pool.query(
        `SELECT ar.id, ar.user_id, ar.file_name, ar.created_at, u.first_name, u.last_name, u.username, u.email
         FROM analysis_reports ar
         JOIN users u ON ar.user_id = u.id
         ORDER BY ar.created_at DESC`
    );
    res.json(rows.rows);
});

/**
 * @swagger
 * /admin/report/{id}:
 *   get:
 *     summary: Получить подробный отчёт по id (только для администратора)
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: Подробный отчёт
 *       404:
 *         description: Не найдено
 */
router.get('/admin/report/:id', async (req, res) => {
    const { id } = req.params;
    const row = await pool.query('SELECT report_data FROM analysis_reports WHERE id=$1', [id]);
    if (!row.rows.length) {
        return res.status(404).json({ error: 'Not found' });
    }
    res.json(row.rows[0].report_data);
});

/**
 * @swagger
 * /admin/report/{id}:
 *   delete:
 *     summary: Удалить отчёт по id (только для администратора)
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: Отчёт удалён
 */
router.delete('/admin/report/:id', async (req, res) => {
    const { id } = req.params;
    await pool.query('DELETE FROM analysis_reports WHERE id=$1', [id]);
    res.json({ message: 'Отчёт удалён' });
});

/**
 * @swagger
 * /admin/norms:
 *   post:
 *     summary: Добавить новую норму анализа (только для администратора)
 *     tags: [Admin]
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
 *               name: { type: string }
 *               min_value: { type: number }
 *               max_value: { type: number }
 *               unit: { type: string }
 *     responses:
 *       200:
 *         description: Норма создана
 */
router.post('/admin/norms', async (req, res) => {
    const { name, min_value, max_value, unit } = req.body;
    if (!name || min_value === undefined || max_value === undefined || !unit) {
        return res.status(400).json({ error: 'Все поля обязательны' });
    }
    try {
        await pool.query(
            'INSERT INTO analysis_norms (name, min_value, max_value, unit) VALUES ($1, $2, $3, $4)',
            [name, min_value, max_value, unit]
        );
        res.json({ message: 'Норма добавлена' });
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
 * /admin/norms/{id}:
 *   patch:
 *     summary: Изменить норму анализа (только для администратора)
 *     tags: [Admin]
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
 *         description: Норма обновлена
 *       404:
 *         description: Норма не найдена
 */
router.patch('/admin/norms/:id', async (req, res) => {
    const { id } = req.params;
    const { name, min_value, max_value, unit } = req.body;
    try {
        const updated = await pool.query(
            'UPDATE analysis_norms SET name=$1, min_value=$2, max_value=$3, unit=$4 WHERE id=$5 RETURNING *',
            [name, min_value, max_value, unit, id]
        );
        if (updated.rowCount === 0) {
            return res.status(404).json({ error: 'Норма не найдена' });
        }
        res.json({ message: 'Норма обновлена' });
    } catch (err) {
        console.error('update norm failed:', err);
        res.status(500).json({ error: 'Внутренняя ошибка сервера' });
    }
});

/**
 * @swagger
 * /admin/norms/{id}:
 *   delete:
 *     summary: Удалить норму анализа (только для администратора)
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: Норма удалена
 */
router.delete('/admin/norms/:id', async (req, res) => {
    const { id } = req.params;
    await pool.query('DELETE FROM analysis_norms WHERE id=$1', [id]);
    res.json({ message: 'Норма удалена' });
});

module.exports = router;
