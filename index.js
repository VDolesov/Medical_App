const express = require('express');
const { Pool } = require('pg');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const xlsx = require('xlsx');
const cors = require('cors');
const fs = require('fs');
const upload = multer({ dest: 'uploads/' });
require('dotenv').config();


const swaggerUi = require('swagger-ui-express');
const swaggerJsdoc = require('swagger-jsdoc');

const app = express();
app.use(express.json());

// Настройка CORS для production
const corsOptions = {
  origin: [
    'https://medicalreactfrontend-production.up.railway.app',
    'http://localhost:3000',
    'http://localhost:3001'
  ],
  credentials: true,
  optionsSuccessStatus: 200
};
app.use(cors(corsOptions));

const JWT_SECRET = process.env.JWT_SECRET;
const ADMIN_SECRET = process.env.ADMIN_SECRET;

const pool = new Pool({
    user: process.env.PGUSER,
    host: process.env.PGHOST,
    database: process.env.PGDATABASE,
    password: process.env.PGPASSWORD,
    port: process.env.PGPORT,
});


const swaggerOptions = {
  swaggerDefinition: {
    openapi: '3.0.0',
    info: {
      title: 'Medical App API',
      version: '1.0.0',
      description: 'API для загрузки и анализа медицинских анализов',
    },
    servers: [
      { url: 'https://medicalprojects-production.up.railway.app' },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
      schemas: {
        User: {
          type: 'object',
          properties: {
            id: { type: 'integer', example: 1 },
            username: { type: 'string', example: 'doctor1' },
            email: { type: 'string', example: 'doctor1@mail.ru' },
            first_name: { type: 'string', example: 'Иван' },
            last_name: { type: 'string', example: 'Иванов' },
            role: { type: 'string', example: 'doctor' },
          }
        },
        Norm: {
          type: 'object',
          properties: {
            id: { type: 'integer', example: 3 },
            name: { type: 'string', example: 'Кальций общий' },
            min_value: { type: 'number', example: 2.15 },
            max_value: { type: 'number', example: 2.6 },
            unit: { type: 'string', example: 'ммоль/л' }
          }
        },
        ReportMeta: {
          type: 'object',
          properties: {
            id: { type: 'integer', example: 17 },
            user_id: { type: 'integer', example: 2 },
            file_name: { type: 'string', example: 'test_data.xlsx' },
            created_at: { type: 'string', example: '2025-06-17T11:22:13.131Z' }
          }
        },
        Report: {
          type: 'object',
          properties: {
            code: { type: 'string', example: '001' },
            age: { type: 'integer', example: 34 },
            outOfNorms: {
              type: 'array',
              items: {
                oneOf: [
                  {
                    type: 'object',
                    properties: {
                      analysis: { type: 'string', example: 'ТТГ' },
                      value: { type: 'number', example: 4.1 },
                      min: { type: 'number', example: 0.4 },
                      max: { type: 'number', example: 4.0 },
                      unit: { type: 'string', example: 'мЕд/л' },
                      status: { type: 'string', example: 'выше нормы' }
                    }
                  },
                  {
                    type: 'string',
                    example: 'Все значения в норме'
                  }
                ]
              }
            }
          }
        },
        Error: {
          type: 'object',
          properties: {
            error: { type: 'string', example: 'Сообщение об ошибке' }
          }
        }
      }
    },
    security: [{ bearerAuth: [] }]
  },
  apis: ['./index.js'],
};
const swaggerDocs = swaggerJsdoc(swaggerOptions);
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocs));

function authenticate(req, res, next) {
    const header = req.headers['authorization'];
    if (!header) return res.status(401).json({ error: "Требуется авторизация" });
    try {
        req.user = jwt.verify(header.split(' ')[1], JWT_SECRET);
        next();
    } catch (e) {
        res.status(403).json({ error: "Неверный токен" });
    }
}

function requireAdmin(req, res, next) {
    if (req.user.role !== 'admin') {
        return res.status(403).json({ error: "Требуются права администратора" });
    }
    next();
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
 *                 description: 'doctor — врач, admin — администратор'
 *               adminSecret:
 *                 type: string
 *                 example: 1111
 *                 description: 'Секретный код для создания admin (требуется только для admin)'
 *     responses:
 *       200:
 *         description: Пользователь зарегистрирован
 *       403:
 *         description: Неверный секретный код для администратора
 *       400:
 *         description: Ошибка роли
 *       500:
 *         description: Внутренняя ошибка сервера
 */
app.post('/register', async (req, res) => {
    const { username, password, email, firstName, lastName, role, adminSecret } = req.body;
    const allowedRoles = ['doctor', 'admin'];

    if (!allowedRoles.includes(role)) {
        return res.status(400).json({ error: 'Роль должна быть doctor или admin' });
    }
    if (role === 'admin') {
        if (adminSecret !== ADMIN_SECRET) {
            return res.status(403).json({ error: 'Неверный секретный код для администратора' });
        }
    }

    // Проверка на кириллицу и Unicode для firstName и lastName
    const nameRegex = /^[\p{L}\s'-]+$/u;
    if (!nameRegex.test(firstName) || !nameRegex.test(lastName)) {
        return res.status(400).json({ error: 'Имя и фамилия могут содержать только буквы, пробелы, апострофы и дефисы' });
    }

    const hash = await bcrypt.hash(password, 10);
    try {
        await pool.query(
            'INSERT INTO users (username, password_hash, email, first_name, last_name, role) VALUES ($1, $2, $3, $4, $5, $6)',
            [username, hash, email, firstName, lastName, role]
        );
        res.json({ message: 'Пользователь зарегистрирован' });
    } catch (err) {
        res.status(500).json({ error: err.message });
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
 *                   description: JWT токен
 *                 user:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: integer
 *                     username:
 *                       type: string
 *                     first_name:
 *                       type: string
 *                     last_name:
 *                       type: string
 *                     role:
 *                       type: string
 *       401:
 *         description: Неверный логин или пароль
 */
app.post('/login', async (req, res) => {
    const { username, password } = req.body;
    const userRes = await pool.query(
        'SELECT id, username, password_hash, first_name, last_name, role FROM users WHERE username=$1',
        [username]
    );
    const user = userRes.rows[0];
    if (user && await bcrypt.compare(password, user.password_hash)) {
        const token = jwt.sign({ userId: user.id, role: user.role }, JWT_SECRET, { expiresIn: '8h' });
        res.json({
            token,
            user: {
                id: user.id,
                username: user.username,
                first_name: user.first_name,
                last_name: user.last_name,
                role: user.role
            }
        });
    } else {
        res.status(401).json({ error: 'Неверный логин или пароль' });
    }
});


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
 *         description: Отчёт по анализам для каждого пациента + id отчёта
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 reportId:
 *                   type: integer
 *                 report:
 *                   type: array
 *                   items:
 *                     type: object
 *       401:
 *         description: Требуется авторизация
 *       403:
 *         description: Нет прав на загрузку
 *       500:
 *         description: Внутренняя ошибка сервера
 */
app.post('/upload', authenticate, upload.single('file'), async (req, res) => {
    if (!["doctor", "admin"].includes(req.user.role)) {
        return res.status(403).json({ error: "Нет прав на загрузку" });
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

        for (let row of rows) {
            const code = row['Код пациента'];
            const age = row['Возраст'];

            if (!code || code.toString().trim() === "" || !age) continue;

            let patientRes = await pool.query('SELECT * FROM patients WHERE code=$1', [code]);
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

            let patientReport = { code, age, outOfNorms: [] };

            for (let col of Object.keys(row)) {
                if (col === 'Код пациента' || col === 'Возраст') continue;
                const norm = norms[col];
                if (!norm) continue;

                const value = parseFloat(row[col]);
                if (!isNaN(value)) {
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
                            status: value < norm.min_value ? 'ниже нормы' : 'выше нормы'
                        });
                    }
                }
            }
            if (patientReport.outOfNorms.length === 0) {
                patientReport.outOfNorms = ["Все значения в норме"];
            }
            report.push(patientReport);
        }

        const reportInsert = await pool.query(
            'INSERT INTO analysis_reports (user_id, file_name, report_data) VALUES ($1, $2, $3) RETURNING id',
            [req.user.userId, req.file.originalname, JSON.stringify(report)]
        );

        const reportId = reportInsert.rows[0].id;
        fs.unlinkSync(req.file.path);
        res.json({ reportId, report });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});




/**
 * @swagger
 * /norms:
 *   get:
 *     summary: Получить все нормы анализов
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
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */

app.get('/norms', authenticate, async (req, res) => {
    const norms = await pool.query('SELECT * FROM analysis_norms');
    res.json(norms.rows);
});

/**
 * @swagger
 * /norms:
 *   get:
 *     summary: Получить все нормы анализов
 *     description: Возвращает полный список медицинских норм для всех анализов. Только для авторизованных пользователей (врачи и администраторы).
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
 *                 type: object
 *                 properties:
 *                   id:
 *                     type: integer
 *                     example: 3
 *                   name:
 *                     type: string
 *                     example: Кальций общий
 *                   min_value:
 *                     type: number
 *                     example: 2.15
 *                   max_value:
 *                     type: number
 *                     example: 2.6
 *                   unit:
 *                     type: string
 *                     example: ммоль/л
 *       401:
 *         description: Требуется авторизация
 */
app.get('/norms', authenticate, async (req, res) => {
    const norms = await pool.query('SELECT * FROM analysis_norms');
    res.json(norms.rows);
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
 *         schema:
 *           type: integer
 *         description: ID отчёта
 *     responses:
 *       200:
 *         description: Подробный отчёт (JSON)
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *       404:
 *         description: Не найдено
 */

app.get('/report/:id', authenticate, async (req, res) => {
    const { id } = req.params;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const offset = (page - 1) * limit;
    const row = await pool.query(
        'SELECT report_data FROM analysis_reports WHERE id=$1 AND user_id=$2',
        [id, req.user.userId]
    );
    if (row.rows.length) {
        let allPatients = row.rows[0].report_data;
        if (!Array.isArray(allPatients)) {
            allPatients = Object.values(allPatients);
        }
        const total = allPatients.length;
        const patients = allPatients.slice(offset, offset + limit);
        res.json({
            total,
            page,
            limit,
            patients
        });
    } else {
        res.status(404).json({ error: "Not found" });
    }
});


/**
 * @swagger
 * /norms:
 *   post:
 *     summary: Добавить новую норму анализа (только администратор)
 *     description: Позволяет администратору добавить новую медицинскую норму для анализа.
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
 *               name:
 *                 type: string
 *                 example: Калий
 *               min_value:
 *                 type: number
 *                 example: 3.5
 *               max_value:
 *                 type: number
 *                 example: 5.1
 *               unit:
 *                 type: string
 *                 example: ммоль/л
 *     responses:
 *       200:
 *         description: Норма успешно добавлена
 *       400:
 *         description: Ошибка валидации
 *       401:
 *         description: Требуется авторизация
 *       403:
 *         description: Требуются права администратора
 */
app.post('/norms', authenticate, requireAdmin, async (req, res) => {
    const { name, min_value, max_value, unit } = req.body;
    if (!name || min_value == null || max_value == null || !unit) {
        return res.status(400).json({ error: "Все поля обязательны" });
    }
    try {
        await pool.query(
            'INSERT INTO analysis_norms (name, min_value, max_value, unit) VALUES ($1, $2, $3, $4)',
            [name, min_value, max_value, unit]
        );
        res.json({ message: "Норма успешно добавлена" });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

/**
 * @swagger
 * /norms/{id}:
 *   put:
 *     summary: Редактировать норму анализа (только администратор)
 *     description: Позволяет администратору изменить параметры существующей нормы анализа.
 *     tags: [Norms]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - name: id
 *         in: path
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID нормы анализа
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *                 example: Кальций общий
 *               min_value:
 *                 type: number
 *                 example: 2.2
 *               max_value:
 *                 type: number
 *                 example: 2.7
 *               unit:
 *                 type: string
 *                 example: ммоль/л
 *     responses:
 *       200:
 *         description: Норма успешно обновлена
 *       400:
 *         description: Ошибка валидации
 *       401:
 *         description: Требуется авторизация
 *       403:
 *         description: Требуются права администратора
 *       404:
 *         description: Норма не найдена
 */
app.put('/norms/:id', authenticate, requireAdmin, async (req, res) => {
    const { id } = req.params;
    const { name, min_value, max_value, unit } = req.body;
    if (!name || min_value == null || max_value == null || !unit) {
        return res.status(400).json({ error: "Все поля обязательны" });
    }
    const updateRes = await pool.query(
        'UPDATE analysis_norms SET name=$1, min_value=$2, max_value=$3, unit=$4 WHERE id=$5 RETURNING *',
        [name, min_value, max_value, unit, id]
    );
    if (updateRes.rowCount === 0) {
        return res.status(404).json({ error: "Норма не найдена" });
    }
    res.json({ message: "Норма успешно обновлена" });
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
 *         schema:
 *           type: integer
 *         description: ID нормы анализа
 *     responses:
 *       200:
 *         description: Норма успешно удалена
 *       401:
 *         description: Требуется авторизация
 *       403:
 *         description: Требуются права администратора
 *       404:
 *         description: Норма не найдена
 */
app.delete('/norms/:id', authenticate, requireAdmin, async (req, res) => {
    const { id } = req.params;
    const del = await pool.query('DELETE FROM analysis_norms WHERE id=$1 RETURNING *', [id]);
    if (del.rowCount === 0) {
        return res.status(404).json({ error: "Норма не найдена" });
    }
    res.json({ message: "Норма успешно удалена" });
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
 *                 example: doctor
 *     responses:
 *       200:
 *         description: Пользователь создан
 *       400:
 *         description: Ошибка валидации
 */
app.post('/admin/users', authenticate, requireAdmin, async (req, res) => {
    const { username, password, email, firstName, lastName, role } = req.body;
    const allowedRoles = ['doctor', 'admin'];
    if (!allowedRoles.includes(role)) {
        return res.status(400).json({ error: "Роль должна быть doctor или admin" });
    }
    const exists = await pool.query(
        'SELECT id FROM users WHERE username=$1 OR email=$2',
        [username, email]
    );
    if (exists.rows.length) {
        return res.status(400).json({ error: "Пользователь с таким username или email уже существует" });
    }
    const hash = await bcrypt.hash(password, 10);
    try {
        await pool.query(
            'INSERT INTO users (username, password_hash, email, first_name, last_name, role) VALUES ($1, $2, $3, $4, $5, $6)',
            [username, hash, email, firstName, lastName, role]
        );
        res.json({ message: 'Пользователь создан' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
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
 *       200: { description: Пользователь удалён }
 */
app.delete('/admin/users/:id', authenticate, requireAdmin, async (req, res) => {
    const { id } = req.params;
    if (req.user.userId == id) {
        return res.status(400).json({ error: "Нельзя удалить самого себя!" });
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
 *       401:
 *         description: Требуется авторизация
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       403:
 *         description: Требуются права администратора
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */

app.get('/admin/reports', authenticate, requireAdmin, async (req, res) => {
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
 *       200: { description: Отчёт удалён }
 */
app.delete('/admin/report/:id', authenticate, requireAdmin, async (req, res) => {
    const { id } = req.params;
    await pool.query('DELETE FROM analysis_reports WHERE id=$1', [id]);
    res.json({ message: 'Отчёт удалён' });
});





app.get('/me', authenticate, async (req, res) => {
    const user = await pool.query('SELECT id, username, first_name, last_name, role FROM users WHERE id=$1', [req.user.userId]);
    if (!user.rows.length) {
        return res.status(404).json({ error: "Пользователь не найден" });
    }
    res.json(user.rows[0]);
});


app.get('/ping', (req, res) => res.send('pong'));

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
 *         schema:
 *           type: integer
 *         description: ID отчёта
 *     responses:
 *       200:
 *         description: Отчёт успешно удалён
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *       404:
 *         description: Не найдено
 *       401:
 *         description: Требуется авторизация
 */
app.delete('/report/:id', authenticate, async (req, res) => {
    const { id } = req.params;
    const row = await pool.query(
        'SELECT 1 FROM analysis_reports WHERE id=$1 AND user_id=$2',
        [id, req.user.userId]
    );
    if (!row.rows.length) {
        return res.status(404).json({ error: "Not found" });
    }
    await pool.query('DELETE FROM analysis_reports WHERE id=$1', [id]);
    res.json({ success: true });
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
 *         schema:
 *           type: integer
 *         description: ID отчёта
 *     responses:
 *       200:
 *         description: Подробный отчёт (JSON)
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/Report'
 *       404:
 *         description: Не найдено
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */

app.get('/admin/report/:id', authenticate, requireAdmin, async (req, res) => {
    const { id } = req.params;
    const row = await pool.query(
        'SELECT report_data FROM analysis_reports WHERE id=$1',
        [id]
    );
    if (row.rows.length) {
        res.json(row.rows[0].report_data);
    } else {
        res.status(404).json({ error: "Not found" });
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
 *         schema:
 *           type: integer
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
 *               password: { type: string, description: "Если указан, будет сменён" }
 *     responses:
 *       200:
 *         description: Данные пользователя обновлены
 *       404:
 *         description: Пользователь не найден
 */
app.patch('/admin/users/:id', authenticate, requireAdmin, async (req, res) => {
    const { id } = req.params;
    const { email, firstName, lastName, role, password } = req.body;

    const userRes = await pool.query('SELECT * FROM users WHERE id=$1', [id]);
    if (!userRes.rows.length) {
        return res.status(404).json({ error: "Пользователь не найден" });
    }

    const updates = [];
    const values = [];
    let idx = 1;

    if (email)         { updates.push(`email=$${idx++}`);     values.push(email); }
    if (firstName)     { updates.push(`first_name=$${idx++}`); values.push(firstName); }
    if (lastName)      { updates.push(`last_name=$${idx++}`);  values.push(lastName); }
    if (role)          { updates.push(`role=$${idx++}`);       values.push(role); }

    let pwHash = null;
    if (password) {
        pwHash = await bcrypt.hash(password, 10);
        updates.push(`password_hash=$${idx++}`);
        values.push(pwHash);
    }

    if (updates.length === 0) {
        return res.json({ message: "Нет изменений" });
    }

    values.push(id);
    await pool.query(
        `UPDATE users SET ${updates.join(', ')} WHERE id=$${idx}`,
        values
    );

    res.json({ message: "Пользователь обновлён" });
});

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
 *       401:
 *         description: Требуется авторизация
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       403:
 *         description: Требуются права администратора
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */

app.get('/admin/users', authenticate, requireAdmin, async (req, res) => {
    const users = await pool.query(
        'SELECT id, username, first_name, last_name, role FROM users ORDER BY id'
    );
    res.json(users.rows);
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
 *       200: { description: Норма создана }
 */
app.post('/admin/norms', authenticate, requireAdmin, async (req, res) => {
    const { name, min_value, max_value, unit } = req.body;
    if (!name || min_value === undefined || max_value === undefined || !unit)
        return res.status(400).json({ error: "Все поля обязательны" });
    try {
        await pool.query(
            'INSERT INTO analysis_norms (name, min_value, max_value, unit) VALUES ($1, $2, $3, $4)',
            [name, min_value, max_value, unit]
        );
        res.json({ message: "Норма добавлена" });
    } catch (err) {
        res.status(500).json({ error: err.message });
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
 *       200: { description: Норма обновлена }
 */
app.patch('/admin/norms/:id', authenticate, requireAdmin, async (req, res) => {
    const { id } = req.params;
    const { name, min_value, max_value, unit } = req.body;
    try {
        await pool.query(
            'UPDATE analysis_norms SET name=$1, min_value=$2, max_value=$3, unit=$4 WHERE id=$5',
            [name, min_value, max_value, unit, id]
        );
        res.json({ message: "Норма обновлена" });
    } catch (err) {
        res.status(500).json({ error: err.message });
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
 *       200: { description: Норма удалена }
 */
app.delete('/admin/norms/:id', authenticate, requireAdmin, async (req, res) => {
    const { id } = req.params;
    await pool.query('DELETE FROM analysis_norms WHERE id=$1', [id]);
    res.json({ message: "Норма удалена" });
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
 *                 type: object
 *                 properties:
 *                   id:
 *                     type: integer
 *                   file_name:
 *                     type: string
 *                   created_at:
 *                     type: string
 */
app.get('/reports', authenticate, async (req, res) => {
    if (req.user.role !== 'doctor') {
        return res.status(403).json({ error: "Доступ запрещён" });
    }
    const result = await pool.query(
        'SELECT id, file_name, created_at FROM analysis_reports WHERE user_id=$1 ORDER BY created_at DESC',
        [req.user.userId]
    );
    res.json(result.rows);
});


const PORT = process.env.PORT || 5000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Medical backend started on port ${PORT}`);
});
