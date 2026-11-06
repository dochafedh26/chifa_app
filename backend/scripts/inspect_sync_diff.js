const mysql = require('mysql2/promise');

async function main() {
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

  console.log('--- DETAILED TABLE COMPARISON ---');
  const [localTables] = await local.query('SHOW TABLES');
  const tables = localTables.map((t) => Object.values(t)[0]);

  for (const t of tables) {
    try {
      const [lc] = await local.query(`SELECT COUNT(*) as cnt, MAX(updated_at) as max_up FROM \`${t}\``);
      const [rc] = await remote.query(`SELECT COUNT(*) as cnt, MAX(updated_at) as max_up FROM \`${t}\``);

      const lCount = lc[0].cnt;
      const rCount = rc[0].cnt;

      if (lCount !== rCount) {
        console.log(`[DIFF] ${t}: LOCAL=${lCount} rows (latest: ${lc[0].max_up}) vs REMOTE=${rCount} rows (latest: ${rc[0].max_up})`);
      }
    } catch (e) {
      console.log(`[ERR] ${t}: ${e.message}`);
    }
  }

  await local.end();
  await remote.end();
}

main().catch(console.error);

