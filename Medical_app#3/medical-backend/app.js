const express = require('express');
const cors = require('cors');
const swaggerUi = require('swagger-ui-express');

const { swaggerDocs } = require('./swagger');

const app = express();
app.use(express.json());
app.use(cors());

// Swagger
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocs));

// Роуты
app.use('/', require('./routes/auth'));
app.use('/', require('./routes/upload'));
app.use('/', require('./routes/norms'));
app.use('/', require('./routes/reports'));
app.use('/', require('./routes/admin'));

app.get('/ping', (req, res) => res.send('pong'));

module.exports = app;
