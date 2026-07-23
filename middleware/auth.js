const jwt = require('jsonwebtoken');

function authenticate(req, res, next) {
    const header = req.headers['authorization'];
    if (!header) {
        return res.status(401).json({ error: 'Требуется авторизация' });
    }
    try {
        req.user = jwt.verify(header.split(' ')[1], process.env.JWT_SECRET);
        next();
    } catch (e) {
        res.status(403).json({ error: 'Неверный токен' });
    }
}

function requireAdmin(req, res, next) {
    if (req.user.role !== 'admin') {
        return res.status(403).json({ error: 'Требуются права администратора' });
    }
    next();
}

module.exports = { authenticate, requireAdmin };
