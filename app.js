require('dotenv').config();

const express = require('express');
const cors = require('cors');
const compression = require('compression');

const swagger = require('./config/swagger');
const authRoutes = require('./routes/auth');
const normsRoutes = require('./routes/norms');
const reportsRoutes = require('./routes/reports');
const adminRoutes = require('./routes/admin');
const analyticsRoutes = require('./routes/analytics');

const app = express();

app.use(compression());
app.use(express.json());

const allowedOrigins = ['http://localhost:3000', 'http://localhost:3001'];
if (process.env.CORS_ORIGIN) {
    for (const origin of process.env.CORS_ORIGIN.split(',')) {
        const trimmed = origin.trim();
        if (trimmed) allowedOrigins.push(trimmed);
    }
}

app.use(cors({
    origin: allowedOrigins,
    credentials: true,
    optionsSuccessStatus: 200,
}));

app.use('/api-docs', swagger.serve, swagger.setup);

app.get('/ping', (req, res) => res.send('pong'));

app.use(authRoutes);
app.use(normsRoutes);
app.use(reportsRoutes);
app.use(adminRoutes);
app.use(analyticsRoutes);

module.exports = app;
