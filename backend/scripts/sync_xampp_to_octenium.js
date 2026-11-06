const mysql = require('mysql2/promise');

async function syncAllData() {
  console.log('Connecting to Local XAMPP and Remote Octenium...');
  const local = await mysql.createConnection({
    host: '127.0.0.1',
    user: 'root',
    password: '',
    database: 'clinic',
  });

  const remote = await mysql.createConnection({
    host: 'srv50.octenium.net',
    user: 'rnhgnubg_chifa',
    password: process.env.REMOTE_DB_PASS,
    database: 'rnhgnubg_chifa',
  });

  console.log('Both databases connected!');

  const tablesToSync = [
    'services',
    'soins_services',
    'soins_medicaux',
    'prescriptions',
    'patients_fideles',
    'duty_patients',
    'payment_services',
  ];

  for (const table of tablesToSync) {
    console.log(`\n--- Syncing ${table} ---`);
    try {
      // Get all local rows
      const [localRows] = await local.query(`SELECT * FROM \`${table}\``);
      // Get all remote UUIDs
      const [remoteRows] = await remote.query(`SELECT uuid FROM \`${table}\` WHERE uuid IS NOT NULL`);
      const remoteUuids = new Set(remoteRows.map((r) => r.uuid));

      // Filter rows present in local but missing in remote
      const missingInRemote = localRows.filter((row) => row.uuid && !remoteUuids.has(row.uuid));

      console.log(`${table}: Total Local = ${localRows.length}, Total Remote = ${remoteRows.length}, Missing on Remote = ${missingInRemote.length}`);

      let inserted = 0;
      for (const row of missingInRemote) {
        try {
          const keys = Object.keys(row);
          const cols = keys.map((k) => `\`${k}\``).join(', ');
          const placeholders = keys.map(() => '?').join(', ');
          const values = keys.map((k) => row[k]);

          await remote.query(
            `INSERT INTO \`${table}\` (${cols}) VALUES (${placeholders}) ON DUPLICATE KEY UPDATE updated_at = VALUES(updated_at)`,
            values
          );
          inserted++;
        } catch (insertErr) {
          console.warn(`Error inserting into ${table}:`, insertErr.message);
        }
      }

      console.log(`✓ ${table}: ${inserted} rows pushed to Octenium`);
    } catch (tblErr) {
      console.error(`Error syncing table ${table}:`, tblErr.message);
    }
  }

  await local.end();
  await remote.end();
  console.log('\n=== Synchronization Complete! ===');
}

syncAllData().catch(console.error);

