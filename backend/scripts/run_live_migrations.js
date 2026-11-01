const mysql = require('mysql2/promise');

async function migrateDatabase(cfg, name) {
  console.log(`\n=== Migrating ${name} (${cfg.host} / ${cfg.database}) ===`);
  const conn = await mysql.createConnection(cfg);

  try {
    // 1. activation_keys
    await conn.query(`
      CREATE TABLE IF NOT EXISTS \`activation_keys\` (
        \`id\` INT AUTO_INCREMENT PRIMARY KEY,
        \`license_key\` VARCHAR(100) UNIQUE NOT NULL,
        \`description\` VARCHAR(255) DEFAULT 'Clé Établissement Clinique Chifa',
        \`max_devices\` INT DEFAULT 50,
        \`used_devices\` INT DEFAULT 0,
        \`is_active\` TINYINT(1) DEFAULT 1,
        \`expires_at\` DATETIME DEFAULT NULL,
        \`created_at\` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);
    console.log('✓ activation_keys table ready');

    await conn.query(`
      INSERT IGNORE INTO \`activation_keys\` (\`license_key\`, \`description\`, \`max_devices\`)
      VALUES ('CHIFA-CLINIC-2026-HQ', 'Clé Maître Clinique Chifa HQ', 50);
    `);
    console.log('✓ master activation key seeded');

    // 2. activation_devices
    await conn.query(`
      CREATE TABLE IF NOT EXISTS \`activation_devices\` (
        \`id\` INT AUTO_INCREMENT PRIMARY KEY,
        \`key_id\` INT NOT NULL,
        \`machine_id\` VARCHAR(150) NOT NULL,
        \`machine_name\` VARCHAR(150) DEFAULT NULL,
        \`ip_address\` VARCHAR(45) DEFAULT NULL,
        \`activated_at\` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        \`last_seen_at\` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY \`uq_key_machine\` (\`key_id\`, \`machine_id\`),
        CONSTRAINT \`fk_act_device_key_${name}\` FOREIGN KEY (\`key_id\`) REFERENCES \`activation_keys\`(\`id\`) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);
    console.log('✓ activation_devices table ready');

    // 3. patient_portal_uploads
    await conn.query(`
      CREATE TABLE IF NOT EXISTS \`patient_portal_uploads\` (
        \`id\` INT AUTO_INCREMENT PRIMARY KEY,
        \`uuid\` VARCHAR(36) UNIQUE NOT NULL,
        \`patient_id\` INT NOT NULL,
        \`file_path\` VARCHAR(255) NOT NULL,
        \`original_name\` VARCHAR(255) NOT NULL,
        \`file_type\` VARCHAR(100) NOT NULL,
        \`file_size\` INT DEFAULT 0,
        \`category\` VARCHAR(100) DEFAULT 'Analyses Biologiques',
        \`notes\` TEXT DEFAULT NULL,
        \`status\` VARCHAR(20) DEFAULT 'pending',
        \`viewed_by\` INT DEFAULT NULL,
        \`viewed_at\` DATETIME DEFAULT NULL,
        \`created_at\` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        \`updated_at\` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        \`is_deleted\` TINYINT(1) DEFAULT 0,
        \`needs_sync\` TINYINT(1) DEFAULT 0,
        \`source_id\` VARCHAR(50) DEFAULT 'local_server'
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);
    console.log('✓ patient_portal_uploads table ready');

    // 4. notifications
    await conn.query(`
      CREATE TABLE IF NOT EXISTS \`notifications\` (
        \`id\` INT AUTO_INCREMENT PRIMARY KEY,
        \`uuid\` VARCHAR(36) UNIQUE NOT NULL,
        \`doctor_id\` INT DEFAULT NULL,
        \`patient_id\` INT NOT NULL,
        \`title\` VARCHAR(150) NOT NULL,
        \`message\` TEXT NOT NULL,
        \`type\` VARCHAR(50) DEFAULT 'patient_upload',
        \`reference_id\` INT DEFAULT NULL,
        \`is_read\` TINYINT(1) DEFAULT 0,
        \`created_at\` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        \`updated_at\` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        \`is_deleted\` TINYINT(1) DEFAULT 0,
        \`needs_sync\` TINYINT(1) DEFAULT 0,
        \`source_id\` VARCHAR(50) DEFAULT 'local_server'
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);
    console.log('✓ notifications table ready');

    // 5. Add columns to employees
    const [eCols] = await conn.query("SHOW COLUMNS FROM employees LIKE 'is_active'");
    if (eCols.length === 0) {
      await conn.query("ALTER TABLE employees ADD COLUMN is_active TINYINT(1) DEFAULT 1");
      await conn.query("ALTER TABLE employees ADD COLUMN approved_at DATETIME DEFAULT NULL");
      await conn.query("ALTER TABLE employees ADD COLUMN approved_by VARCHAR(100) DEFAULT NULL");
      await conn.query("UPDATE employees SET is_active = 1 WHERE is_active IS NULL");
      console.log('✓ employees approval columns added and existing employees activated');
    } else {
      console.log('✓ employees approval columns already present');
    }

    // 6. Add columns to patients
    const [pCols] = await conn.query("SHOW COLUMNS FROM patients LIKE 'portal_pin_hash'");
    if (pCols.length === 0) {
      await conn.query("ALTER TABLE patients ADD COLUMN portal_pin_hash VARCHAR(255) DEFAULT NULL");
      await conn.query("ALTER TABLE patients ADD COLUMN portal_access_enabled TINYINT(1) DEFAULT 1");
      console.log('✓ patients portal columns added');
    } else {
      console.log('✓ patients portal columns already present');
    }

    console.log(`=== Migration for ${name} completed successfully! ===\n`);
  } catch (err) {
    console.error(`Error migrating ${name}:`, err.message);
  } finally {
    await conn.end();
  }
}

async function main() {
  // Migrate Local XAMPP
  await migrateDatabase({ host: '127.0.0.1', user: 'root', password: '', database: 'clinic' }, 'LOCAL_XAMPP');

  // Migrate Remote Octenium
  await migrateDatabase({ host: 'srv50.octenium.net', user: 'rnhgnubg_chifa', password: 'MyNetPass@2026', database: 'rnhgnubg_chifa' }, 'OCTENIUM_CLOUD');
}

main().catch(console.error);

