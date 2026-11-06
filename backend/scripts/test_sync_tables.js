const mysql = require('mysql2/promise');

async function testPush() {
  const local = await mysql.createConnection({ host: '127.0.0.1', user: 'root', password: '', database: 'clinic' });
  const remote = await mysql.createConnection({ host: 'srv50.octenium.net', user: 'rnhgnubg_chifa', password: process.env.REMOTE_DB_PASS, database: 'rnhgnubg_chifa' });

  // Check payment_services differences
  const [localPS] = await local.query('SELECT * FROM payment_services ORDER BY updated_at DESC LIMIT 5');
  console.log('Sample local payment_services row keys:', Object.keys(localPS[0]));

  const [remoteCols] = await remote.query('SHOW COLUMNS FROM payment_services');
  console.log('Remote payment_services column count:', remoteCols.length);

  const [localCols] = await local.query('SHOW COLUMNS FROM payment_services');
  console.log('Local payment_services column count:', localCols.length);

  const rNames = new Set(remoteCols.map(c => c.Field));
  const lNames = new Set(localCols.map(c => c.Field));

  const onlyInLocal = [...lNames].filter(x => !rNames.has(x));
  const onlyInRemote = [...rNames].filter(x => !lNames.has(x));

  console.log('Columns in payment_services only in local:', onlyInLocal);
  console.log('Columns in payment_services only in remote:', onlyInRemote);

  // Check soins_medicaux
  const [smL] = await local.query('SHOW COLUMNS FROM soins_medicaux');
  const [smR] = await remote.query('SHOW COLUMNS FROM soins_medicaux');
  const smLNames = new Set(smL.map(c => c.Field));
  const smRNames = new Set(smR.map(c => c.Field));
  console.log('Columns in soins_medicaux only in local:', [...smLNames].filter(x => !smRNames.has(x)));
  console.log('Columns in soins_medicaux only in remote:', [...smRNames].filter(x => !smLNames.has(x)));

  await local.end();
  await remote.end();
}

testPush().catch(console.error);

