const { Pool } = require('pg');
require('dotenv').config();

const poolTuning = {
    max: Number(process.env.DB_POOL_MAX) || 5,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 20000,
    keepAlive: true,
};

const pool = process.env.DATABASE_URL
    ? new Pool({
        connectionString: process.env.DATABASE_URL,
        ssl: { rejectUnauthorized: false },
        ...poolTuning,
    })
    : new Pool({
        user: process.env.PGUSER,
        host: process.env.PGHOST,
        database: process.env.PGDATABASE,
        password: process.env.PGPASSWORD,
        port: process.env.PGPORT,
        ...poolTuning,
    });

pool.on('error', err => {
    console.error('postgres pool error:', err.message);
});

module.exports = pool;
