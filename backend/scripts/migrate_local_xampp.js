const mysql = require('mysql2/promise');

async function checkAndMigrateLocal() {
  const conn = await mysql.createConnection({
    host: '127.0.0.1',
    user: 'root',
    password: '',
    database: 'clinic',
  });

  console.log('Connected to local XAMPP "clinic" database.');

  // 1. Check Tables
  const [tables] = await conn.query('SHOW TABLES');
  const tableNames = tables.map((t) => Object.values(t)[0]);

  console.log('Tables status:');
  console.log(' - activation_keys:', tableNames.includes('activation_keys'));
  console.log(' - activation_devices:', tableNames.includes('activation_devices'));
  console.log(' - patient_portal_uploads:', tableNames.includes('patient_portal_uploads'));
  console.log(' - notifications:', tableNames.includes('notifications'));

  // 2. Check Columns
  const [pCols] = await conn.query("SHOW COLUMNS FROM patients WHERE Field IN ('portal_pin_hash', 'portal_access_enabled')");
  console.log(' - patients portal columns:', pCols.map((c) => c.Field));

  const [eCols] = await conn.query("SHOW COLUMNS FROM employees WHERE Field IN ('is_active', 'approved_at', 'approved_by')");
  console.log(' - employees approval columns:', eCols.map((c) => c.Field));

  await conn.end();
}

checkAndMigrateLocal().catch(console.error);

