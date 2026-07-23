const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');

const pool = require('../db');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

const DUMMY_PASSWORD_HASH = bcrypt.hashSync('placeholder', 10);

function staffSecretMatches(provided) {
    const secret = process.env.ADMIN_SECRET;
    if (!secret || typeof provided !== 'string' || provided.length === 0) {
        return false;
    }
    const a = crypto.createHash('sha256').update(provided, 'utf8').digest();
    const b = crypto.createHash('sha256').update(secret, 'utf8').digest();
    return crypto.timingSafeEqual(a, b);
}

/**
 * @swagger
 * /register:
 *   post:
 *     summary: Регистрация нового пользователя (врач или админ)
 *     tags: [Auth]
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
 *               username:
 *                 type: string
 *                 example: doctor1
 *               password:
 *                 type: string
 *                 example: 123456
 *               email:
 *                 type: string
 *                 example: doctor1@example.com
 *               firstName:
 *                 type: string
 *                 example: Иван
 *               lastName:
 *                 type: string
 *                 example: Иванов
 *               role:
 *                 type: string
 *                 enum: [doctor, admin]
 *                 example: doctor
 *               adminSecret:
 *                 type: string
 *                 description: 'Код регистрации персонала (обязателен и для doctor, и для admin)'
 *     responses:
 *       200:
 *         description: Пользователь зарегистрирован
 *       403:
 *         description: Неверный код регистрации персонала
 *       400:
 *         description: Ошибка роли
 *       500:
 *         description: Внутренняя ошибка сервера
 */
router.post('/register', async (req, res) => {
    const { username, password, email, firstName, lastName, role, adminSecret } = req.body;
    const allowedRoles = ['doctor', 'admin'];

    if (!allowedRoles.includes(role)) {
        return res.status(400).json({ error: 'Роль должна быть doctor или admin' });
    }
    if (!staffSecretMatches(adminSecret)) {
        return res.status(403).json({ error: 'Неверный код регистрации персонала' });
    }
    if (typeof username !== 'string' || username.trim().length < 3) {
        return res.status(400).json({ error: 'Логин должен быть не короче 3 символов' });
    }
    if (typeof password !== 'string' || password.length < 8) {
        return res.status(400).json({ error: 'Минимальная длина пароля — 8 символов' });
    }

    const nameRegex = /^[\p{L}\s'-]+$/u;
    if (!nameRegex.test(firstName) || !nameRegex.test(lastName)) {
        return res.status(400).json({ error: 'Имя и фамилия могут содержать только буквы, пробелы, апострофы и дефисы' });
    }

    const hash = await bcrypt.hash(password, 10);
    try {
        await pool.query(
            'INSERT INTO users (username, password_hash, email, first_name, last_name, role) VALUES ($1, $2, $3, $4, $5, $6)',
            [username.trim(), hash, email, firstName, lastName, role]
        );
        res.json({ message: 'Пользователь зарегистрирован' });
    } catch (err) {
        if (err && err.code === '23505') {
            return res.status(400).json({ error: 'Пользователь с таким username или email уже существует' });
        }
        console.error('register failed:', err);
        res.status(500).json({ error: 'Внутренняя ошибка сервера' });
    }
});

/**
 * @swagger
 * /login:
 *   post:
 *     summary: Авторизация пользователя (врач или администратор)
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - username
 *               - password
 *             properties:
 *               username:
 *                 type: string
 *                 example: doctor1
 *               password:
 *                 type: string
 *                 example: 123456
 *     responses:
 *       200:
 *         description: JWT-токен и информация о пользователе
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 token:
 *                   type: string
 *                 user:
 *                   $ref: '#/components/schemas/User'
 *       401:
 *         description: Неверный логин или пароль
 */
router.post('/login', async (req, res) => {
    const { username, password } = req.body;
    const userRes = await pool.query(
        'SELECT id, username, password_hash, first_name, last_name, role FROM users WHERE username=$1',
        [username]
    );
    const user = userRes.rows[0];
    const passwordMatches = await bcrypt.compare(
        typeof password === 'string' ? password : '',
        user ? user.password_hash : DUMMY_PASSWORD_HASH
    );

    if (!user || !passwordMatches) {
        return res.status(401).json({ error: 'Неверный логин или пароль' });
    }

    const token = jwt.sign({ userId: user.id, role: user.role }, process.env.JWT_SECRET, { expiresIn: '8h' });
    res.json({
        token,
        user: {
            id: user.id,
            username: user.username,
            first_name: user.first_name,
            last_name: user.last_name,
            role: user.role,
        },
    });
});

/**
 * @swagger
 * /me:
 *   get:
 *     summary: Профиль текущего пользователя
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Данные пользователя
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/User'
 *       404:
 *         description: Пользователь не найден
 */
router.get('/me', authenticate, async (req, res) => {
    const user = await pool.query(
        'SELECT id, username, first_name, last_name, role FROM users WHERE id=$1',
        [req.user.userId]
    );
    if (!user.rows.length) {
        return res.status(404).json({ error: 'Пользователь не найден' });
    }
    res.json(user.rows[0]);
});

module.exports = router;
