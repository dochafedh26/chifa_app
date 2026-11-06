require('dotenv').config();
const { Pool } = require('pg');
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL || 'https://orvdwwuzmcfrbtkwsosc.supabase.co';
const supabaseKey = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9ydmR3d3V6bWNmcmJ0a3dzb3NjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ0Njk3NTgsImV4cCI6MjEwMDA0NTc1OH0.2r8w_2LW-z3HfmZpEpWnsxOdWubbX3yLSUdnUppouZs';

const supabase = createClient(supabaseUrl, supabaseKey);

const pool = new Pool({
  host: process.env.DB_HOST || 'aws-0-eu-west-3.pooler.supabase.com',
  port: parseInt(process.env.DB_PORT || '6543'),
  user: process.env.DB_USER || 'chifa_admin.orvdwwuzmcfrbtkwsosc',
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'postgres',
  ssl: { rejectUnauthorized: false },
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
});

pool.on('error', (err) => {
  console.error('[db:pool] Unexpected error on Supabase PostgreSQL connection:', err);
});

/**
 * Translate MySQL SQL dialects to PostgreSQL syntax
 */
function translateSql(sql, params) {
  let s = sql.trim();
  let p = Array.isArray(params) ? [...params] : [];

  // Handle SHOW COLUMNS FROM <table> LIKE '<col>'
  const showColLike = s.match(/SHOW\s+COLUMNS\s+FROM\s+([`"\w]+)\s+LIKE\s+['"]([^'"]+)['"]/i);
  if (showColLike) {
    const tbl = showColLike[1].replace(/[`"]/g, '');
    const col = showColLike[2];
    s = `SELECT column_name as "Field", data_type as "Type" FROM information_schema.columns WHERE table_schema = 'public' AND table_name = $1 AND column_name = $2`;
    p = [tbl, col];
    return { sql: s, params: p };
  }

  // Handle SHOW COLUMNS FROM <table>
  const showCol = s.match(/SHOW\s+COLUMNS\s+FROM\s+([`"\w]+)/i);
  if (showCol) {
    const tbl = showCol[1].replace(/[`"]/g, '');
    s = `SELECT column_name as "Field", data_type as "Type" FROM information_schema.columns WHERE table_schema = 'public' AND table_name = $1`;
    p = [tbl];
    return { sql: s, params: p };
  }

  // Handle SHOW TABLES LIKE '<tbl>'
  const showTblLike = s.match(/SHOW\s+TABLES\s+LIKE\s+['"]([^'"]+)['"]/i);
  if (showTblLike) {
    const tbl = showTblLike[1].replace(/[`"_%]/g, '');
    s = `SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name = $1`;
    p = [tbl];
    return { sql: s, params: p };
  }

  // Handle SHOW TABLES
  if (/^SHOW\s+TABLES$/i.test(s)) {
    s = `SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE'`;
    return { sql: s, params: p };
  }

  // Replace MySQL backticks with double quotes
  s = s.replace(/`([^`]+)`/g, '"$1"');

  // Replace table_schema = DATABASE() with table_schema = 'public'
  s = s.replace(/table_schema\s*=\s*DATABASE\(\)/gi, "table_schema = 'public'");

  // Replace IFNULL( with COALESCE(
  s = s.replace(/IFNULL\s*\(/gi, 'COALESCE(');

  // Replace DATE(a.col) = ? with (a.col)::date = ?
  s = s.replace(/DATE\(([^)]+)\)/gi, '($1)::date');

  // If INSERT without RETURNING, append RETURNING *
  const isInsert = /^\s*INSERT\s+INTO\s+/i.test(s);
  if (isInsert && !/RETURNING/i.test(s)) {
    s = s.replace(/;?\s*$/, ' RETURNING *');
  }

  // Convert MySQL positional ? placeholders to PostgreSQL $1, $2, ...
  let pIdx = 1;
  s = s.replace(/\?/g, () => `$${pIdx++}`);

  return { sql: s, params: p };
}

/**
 * Execute query and return MySQL2-compatible [rows, fields] tuple
 */
async function executeQuery(clientOrPool, sql, params = []) {
  const { sql: finalSql, params: finalParams } = translateSql(sql, params);

  const res = await clientOrPool.query(finalSql, finalParams);

  const rows = res.rows || [];
  rows.affectedRows = res.rowCount || 0;

  if (rows.length > 0) {
    const first = rows[0];
    const possibleId = first.id || first.patient_id || first.appointment_id || first.employee_id || first.invoice_id || first.payment_id;
    if (possibleId !== undefined) {
      rows.insertId = typeof possibleId === 'number' ? possibleId : parseInt(possibleId, 10) || 0;
    } else {
      rows.insertId = 0;
    }
  } else {
    rows.insertId = 0;
  }

  const fields = res.fields || [];
  return [rows, fields];
}

const db = {
  pool,
  supabase,

  async query(sql, params) {
    return await executeQuery(pool, sql, params);
  },

  async getConnection() {
    const client = await pool.connect();
    return {
      async query(sql, params) {
        return await executeQuery(client, sql, params);
      },
      async beginTransaction() {
        await client.query('BEGIN');
      },
      async commit() {
        await client.query('COMMIT');
      },
      async rollback() {
        await client.query('ROLLBACK');
      },
      release() {
        client.release();
      },
    };
  },
};

module.exports = db;
