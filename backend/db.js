require('dotenv').config();
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: parseInt(process.env.DB_PORT || '3306'),
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'chifa',
  waitForConnections: true,
  connectionLimit: 15,
  queueLimit: 0,
  charset: 'utf8mb4',
  timezone: '+00:00',
});

// Prevent unhandled node crashes if MySQL connection drops
pool.on('error', (err) => {
  console.error('[db:pool] Unexpected error on database connection:', err);
});

module.exports = pool;

