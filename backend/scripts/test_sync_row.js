const mysql = require('mysql2/promise');

async function testSyncRow() {
  const local = await mysql.createConnection({ host: '127.0.0.1', user: 'root', password: '', database: 'clinic' });
  const remote = await mysql.createConnection({ host: 'srv50.octenium.net', user: 'rnhgnubg_chifa', password: process.env.REMOTE_DB_PASS, database: 'rnhgnubg_chifa' });

  // Find a row in local payment_services that is not in remote
  const [missing] = await local.query(`
    SELECT l.* FROM payment_services l
    LEFT JOIN (SELECT uuid FROM rnhgnubg_chifa.payment_services) r ON l.uuid = r.uuid
    WHERE r.uuid IS NULL
    LIMIT 5
  `);
  console.log('Found missing payment_services rows count in sample:', missing.length);
  if (missing.length > 0) {
    console.log('Missing row 0:', missing[0]);
    try {
      const row = missing[0];
      const keys = Object.keys(row);
      const cols = keys.map(k => '`' + k + '`').join(', ');
      const placeholders = keys.map(() => '?').join(', ');
      const values = keys.map(k => row[k]);
      await remote.query(`INSERT INTO payment_services (${cols}) VALUES (${placeholders})`, values);
      console.log('SUCCESSFULLY INSERTED ROW INTO REMOTE!');
    } catch (e) {
      console.log('FAILED TO INSERT ROW:', e.message);
    }
  }

  // Same for soins_medicaux
  const [missingSM] = await local.query(`
    SELECT l.* FROM soins_medicaux l
    LEFT JOIN (SELECT uuid FROM rnhgnubg_chifa.soins_medicaux) r ON l.uuid = r.uuid
    WHERE r.uuid IS NULL
    LIMIT 5
  `);
  console.log('Found missing soins_medicaux rows count in sample:', missingSM.length);
  if (missingSM.length > 0) {
    console.log('Missing SM row 0:', missingSM[0]);
    try {
      const row = missingSM[0];
      const keys = Object.keys(row);
      const cols = keys.map(k => '`' + k + '`').join(', ');
      const placeholders = keys.map(() => '?').join(', ');
      const values = keys.map(k => row[k]);
      await remote.query(`INSERT INTO soins_medicaux (${cols}) VALUES (${placeholders})`, values);
      console.log('SUCCESSFULLY INSERTED SM ROW INTO REMOTE!');
    } catch (e) {
      console.log('FAILED TO INSERT SM ROW:', e.message);
    }
  }

  await local.end();
  await remote.end();
}

testSyncRow().catch(console.error);

