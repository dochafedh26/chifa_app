const mysql = require('mysql2/promise');

async function inspect() {
  const remote = await mysql.createConnection({
    host: 'srv50.octenium.net',
    user: 'rnhgnubg_chifa',
    password: process.env.REMOTE_DB_PASS,
    database: 'rnhgnubg_chifa'
  });

  const local = await mysql.createConnection({
    host: '127.0.0.1',
    user: 'root',
    password: '',
    database: 'clinic'
  });

  // Check patients date_of_birth
  const [nullDob] = await remote.query('SELECT patient_id, first_name, last_name, date_of_birth FROM patients WHERE date_of_birth IS NULL LIMIT 5');
  console.log('REMOTE PATIENTS WITH NULL date_of_birth:', nullDob);

  const [colsLocal] = await local.query("SHOW COLUMNS FROM patients LIKE 'date_of_birth'");
  console.log('LOCAL date_of_birth COLUMN:', colsLocal);

  const [colsRemote] = await remote.query("SHOW COLUMNS FROM patients LIKE 'date_of_birth'");
  console.log('REMOTE date_of_birth COLUMN:', colsRemote);

  // Check medicalrecords record_date
  const [nullRecDate] = await remote.query('SELECT record_id, patient_id, record_date FROM medicalrecords WHERE record_date IS NULL LIMIT 5');
  console.log('REMOTE MEDICALRECORDS WITH NULL record_date:', nullRecDate);

  const [mrColsLocal] = await local.query("SHOW COLUMNS FROM medicalrecords LIKE 'record_date'");
  console.log('LOCAL record_date COLUMN:', mrColsLocal);

  const [mrColsRemote] = await remote.query("SHOW COLUMNS FROM medicalrecords LIKE 'record_date'");
  console.log('REMOTE record_date COLUMN:', mrColsRemote);

  await local.end();
  await remote.end();
}

inspect().catch(console.error);
