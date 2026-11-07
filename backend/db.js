require('dotenv').config();
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.DB_HOST || process.env.REMOTE_DB_HOST || 'srv50.octenium.net',
  port: parseInt(process.env.DB_PORT || process.env.REMOTE_DB_PORT || '3306'),
  user: process.env.DB_USER || process.env.REMOTE_DB_USER || 'rnhgnubg_chifa',
  password: process.env.DB_PASSWORD || process.env.REMOTE_DB_PASS || 'MyNetPass@2026',
  database: process.env.DB_NAME || process.env.REMOTE_DB_NAME || 'rnhgnubg_chifa',
  waitForConnections: true,
  connectionLimit: 15,
  queueLimit: 0,
  charset: 'utf8mb4',
  timezone: '+00:00',
});

// Prevent unhandled node crashes if MySQL connection drops
pool.on('error', (err) => {
  console.error('[db:pool] Unexpected error on Octenium MySQL database connection:', err);
});

module.exports = pool;
