import 'package:flutter/foundation.dart';
import 'package:chifa/services/db/database_manager.dart';
import 'package:chifa/services/db/utils/encoding_fix.dart';

class DatabaseMigrations {
  static Future<void> runMigrations(RemoteDatabaseService db) async {
    try {
      // ── sync_status: ensure table exists for tracking ───────────────────
      await db.execute('''
        CREATE TABLE IF NOT EXISTS `sync_status` (
          `table_name` varchar(50) NOT NULL,
          `last_push_at` timestamp NOT NULL DEFAULT '1970-01-01 00:00:00',
          `last_pull_at` timestamp NOT NULL DEFAULT '1970-01-01 00:00:00',
          PRIMARY KEY (`table_name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
      ''');

      // ── hospitalizations: ensure table exists ──────────────────────────
      await db.execute('''
        CREATE TABLE IF NOT EXISTS `hospitalizations` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `patient_id` int(11) NOT NULL,
          `admission_date` datetime NOT NULL,
          `discharge_date` datetime DEFAULT NULL,
          `diagnosis` text DEFAULT NULL,
          `room_number` varchar(50) DEFAULT NULL,
          `status` enum('active','discharged','transferred') DEFAULT 'active',
          `uuid` varchar(36) DEFAULT NULL,
          `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          `is_deleted` tinyint(1) DEFAULT 0,
          `needs_sync` tinyint(1) DEFAULT 0,
          PRIMARY KEY (`id`),
          UNIQUE KEY `idx_hosp_uuid` (`uuid`),
          CONSTRAINT `fk_hosp_patient` FOREIGN KEY (`patient_id`)
            REFERENCES `patients` (`patient_id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      ''');



      // ── payments table migrations ──────────────────────────────────────
      if (!await db.columnExists('payments', 'payment_method')) {
        await db.execute(
          'ALTER TABLE payments ADD COLUMN payment_method VARCHAR(50) DEFAULT "Cash"',
        );
      }

      // Standardize note/notes columns
      if (await db.columnExists('payments', 'notes') &&
          !await db.columnExists('payments', 'note')) {
        await db.execute('ALTER TABLE payments CHANGE COLUMN notes note TEXT');
      } else if (!await db.columnExists('payments', 'note')) {
        await db.execute('ALTER TABLE payments ADD COLUMN note TEXT');
      }



      // ── fidelity and suivi migrations ────────────────────────────────────
      await db.execute('''
        CREATE TABLE IF NOT EXISTS `patients_fideles` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `patient_id` int(11) NOT NULL,
          `medical_records_count` int(11) NOT NULL DEFAULT 0,
          `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
          `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
          PRIMARY KEY (`id`),
          UNIQUE KEY `patient_id` (`patient_id`),
          CONSTRAINT `fk_fidele_patient` FOREIGN KEY (`patient_id`)
            REFERENCES `patients` (`patient_id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      ''');

      if (!await db.columnExists('patients_fideles', 'medical_records_count')) {
        await db.execute(
          'ALTER TABLE patients_fideles ADD COLUMN medical_records_count int(11) NOT NULL DEFAULT 0',
        );
      }

      // ── Fix modern_prescriptions: add AUTO_INCREMENT to id column ────────
      debugPrint('🔄 Migration: Fixing modern_prescriptions id column...');
      try {
        // Check if id column already has AUTO_INCREMENT
        final checkResult = await db.query(
          "SELECT EXTRA FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'modern_prescriptions' AND column_name = 'id'",
        );
        final hasAutoIncrement = checkResult.isNotEmpty &&
            checkResult.first['extra'].toString().contains('auto_increment');

        if (!hasAutoIncrement) {
          // Add PRIMARY KEY if missing
          final pkCheck = await db.query(
            "SELECT COUNT(*) as cnt FROM information_schema.table_constraints WHERE table_schema = DATABASE() AND table_name = 'modern_prescriptions' AND constraint_name = 'PRIMARY'",
          );
          final hasPK = (int.tryParse(pkCheck.first['cnt'].toString()) ?? 0) > 0;

          if (!hasPK) {
            // Re-index existing rows with id=0 first
            await db.execute(
              'SET @row_num = 0',
            );
            await db.execute(
              'UPDATE `modern_prescriptions` SET `id` = (@row_num := @row_num + 1) WHERE `id` = 0 ORDER BY `updated_at` ASC',
            );
            await db.execute(
              'ALTER TABLE `modern_prescriptions` ADD PRIMARY KEY (`id`)',
            );
          }

          // Add AUTO_INCREMENT
          await db.execute(
            'ALTER TABLE `modern_prescriptions` MODIFY `id` int(11) NOT NULL AUTO_INCREMENT',
          );

          // Reset AUTO_INCREMENT counter (query max first, then set)
          final maxIdResult = await db.query(
            'SELECT COALESCE(MAX(id), 0) as max_id FROM `modern_prescriptions`',
          );
          final maxId = int.tryParse(maxIdResult.first['max_id'].toString()) ?? 0;
          final nextId = maxId + 1;
          await db.execute(
            'ALTER TABLE `modern_prescriptions` AUTO_INCREMENT = $nextId',
          );

          debugPrint('✅ modern_prescriptions id column fixed with AUTO_INCREMENT (next id: $nextId)');
        } else {
          debugPrint('✅ modern_prescriptions id column already has AUTO_INCREMENT');
        }
      } catch (e) {
        debugPrint('⚠️ modern_prescriptions migration skipped: $e');
      }

      await db.execute('''
        CREATE TABLE IF NOT EXISTS `patients_suivi` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `patient_id` int(11) NOT NULL,
          `doctor_id` int(11) DEFAULT 1,
          `pathologies` text DEFAULT NULL,
          `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
          `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
          PRIMARY KEY (`id`),
          UNIQUE KEY `patient_id` (`patient_id`),
          CONSTRAINT `fk_suivi_patient` FOREIGN KEY (`patient_id`)
            REFERENCES `patients` (`patient_id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS `patient_suivi_categories` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `patient_id` int(11) NOT NULL,
          `category` varchar(100) NOT NULL,
          PRIMARY KEY (`id`),
          KEY `idx_psc_patient` (`patient_id`),
          KEY `idx_psc_category` (`category`),
          CONSTRAINT `fk_psc_patient` FOREIGN KEY (`patient_id`)
            REFERENCES `patients` (`patient_id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      ''');

      // ── clinical certificates tables ─────────────────────────────────────
      await db.execute('''
        CREATE TABLE IF NOT EXISTS `certificat_bonne_sante` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `patient_id` int(11) NOT NULL,
          `doctor_id` int(11) DEFAULT NULL,
          `created_at` datetime DEFAULT current_timestamp(),
          `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp(),
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS `certificat_dispension_sport` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `patient_id` int(11) NOT NULL,
          `doctor_id` int(11) DEFAULT NULL,
          `motif` text NOT NULL,
          `created_at` datetime DEFAULT current_timestamp(),
          `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp(),
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS `certificat_maladie_chronique` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `patient_id` int(11) NOT NULL,
          `doctor_id` int(11) DEFAULT NULL,
          `maladie_chronique` text DEFAULT NULL,
          `diagnostic` text DEFAULT NULL,
          `traitement` text DEFAULT NULL,
          `created_at` datetime DEFAULT current_timestamp(),
          `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp(),
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      ''');

      if (!await db.columnExists('certificat_maladie_chronique', 'maladie_chronique')) {
        await db.execute(
          'ALTER TABLE `certificat_maladie_chronique` ADD COLUMN `maladie_chronique` TEXT DEFAULT NULL',
        );
      }

      await db.execute('''
        CREATE TABLE IF NOT EXISTS `certificat_prenuptial` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `patient_id` int(11) NOT NULL,
          `doctor_id` int(11) DEFAULT NULL,
          `groupe_sanguin` varchar(20) DEFAULT NULL,
          `created_at` datetime DEFAULT current_timestamp(),
          `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp(),
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      ''');

      // ── certificat_aptitude_sport: ensure table exists ───────────────────
      await db.execute('''
        CREATE TABLE IF NOT EXISTS `certificat_aptitude_sport` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `patient_id` int(11) NOT NULL,
          `doctor_id` int(11) DEFAULT NULL,
          `sport` varchar(255) DEFAULT 'Toutes disciplines sportives',
          `type_pratique` varchar(100) DEFAULT 'Entraînement et Loisir',
          `examen_clinique` text DEFAULT NULL,
          `remarques` text DEFAULT NULL,
          `created_at` datetime DEFAULT current_timestamp(),
          `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp(),
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      ''');

      // ── interpretation_ecg: ensure table exists ──────────────────────────
      await db.execute('''
        CREATE TABLE IF NOT EXISTS `interpretation_ecg` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `patient_id` int(11) NOT NULL,
          `doctor_id` int(11) DEFAULT NULL,
          `motif` varchar(255) DEFAULT 'Bilan systématique',
          `rythme` varchar(100) DEFAULT 'Sinusal régulier',
          `frequence_cardiaque` int(11) DEFAULT 75,
          `axe_qrs` varchar(100) DEFAULT 'Normal (~60°)',
          `onde_p` varchar(100) DEFAULT 'Normale',
          `espace_pr` varchar(100) DEFAULT 'Normal (120-200 ms)',
          `complexe_qrs` varchar(150) DEFAULT 'Fin (< 100 ms)',
          `segment_st` varchar(100) DEFAULT 'Isoélectrique',
          `onde_t` varchar(100) DEFAULT 'Positive et normale',
          `intervalle_qt` varchar(100) DEFAULT 'Normal',
          `conclusion` text NOT NULL,
          `remarques` text DEFAULT NULL,
          `created_at` datetime DEFAULT current_timestamp(),
          `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp(),
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      ''');

      // ── bilans: add medicalrecord_id column ──────────────────────────────
      if (!await db.columnExists('bilans', 'medicalrecord_id')) {
        await db.execute(
          'ALTER TABLE bilans ADD COLUMN medicalrecord_id INT(11) DEFAULT NULL',
        );
      }

      // ── medalgeriemedics: add posologie_adulte, posologie_pediatrique, dosage, conditionnement, liste columns ───────────────────
      if (!await db.columnExists('medalgeriemedics', 'posologie_adulte')) {
        await db.execute(
          'ALTER TABLE medalgeriemedics ADD COLUMN posologie_adulte TEXT DEFAULT NULL',
        );
      }
      if (!await db.columnExists('medalgeriemedics', 'posologie_pediatrique')) {
        await db.execute(
          'ALTER TABLE medalgeriemedics ADD COLUMN posologie_pediatrique TEXT DEFAULT NULL',
        );
      }
      if (!await db.columnExists('medalgeriemedics', 'dosage')) {
        await db.execute(
          'ALTER TABLE medalgeriemedics ADD COLUMN dosage VARCHAR(255) DEFAULT NULL',
        );
      }
      if (!await db.columnExists('medalgeriemedics', 'conditionnement')) {
        await db.execute(
          'ALTER TABLE medalgeriemedics ADD COLUMN conditionnement VARCHAR(255) DEFAULT NULL',
        );
      }
      if (!await db.columnExists('medalgeriemedics', 'liste')) {
        await db.execute(
          'ALTER TABLE medalgeriemedics ADD COLUMN liste VARCHAR(100) DEFAULT NULL',
        );
      }

      // ── soins_services and soins_medicaux ────────────────────────────────
      await db.execute('''
        CREATE TABLE IF NOT EXISTS `soins_services` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `nom` varchar(255) NOT NULL,
          `prix` decimal(10,2) DEFAULT 0.00,
          `is_deleted` tinyint(1) DEFAULT 0,
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS `soins_medicaux` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `patient_id` int(11) NOT NULL,
          `doctor_id` int(11) DEFAULT NULL,
          `medicalrecord_id` int(11) DEFAULT NULL,
          `soins` text DEFAULT NULL,
          `created_at` datetime DEFAULT current_timestamp(),
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      ''');

      // Seed default services if the table is empty
      final soinsCount = await db.query(
        'SELECT COUNT(*) as count FROM soins_services',
      );
      if (soinsCount.isNotEmpty &&
          (int.tryParse(soinsCount.first['count'].toString()) ?? 0) == 0) {
        final defaultSoins = [
          'Consultation Générale',
          'Consultation Spécialisée',
          'Injection IM/IV',
          'Pansement simple',
          'Pansement complexe',
          'Aérosol',
          'ECG',
          'Prélèvement sanguin',
          'Suture',
          'Ablation de fils',
          'Nébularisation',
          'Lavage d\'oreille',
        ];
        for (final soin in defaultSoins) {
          await db.execute('INSERT INTO soins_services (nom) VALUES (?)', [
            soin,
          ]);
        }
      }

      // ── Dynamic Sync Columns Migration for ALL tables ───────────────────
      final allTables = await db.getTables();

      for (final table in allTables) {
        // Skip system tables or tables already updated
        if (table == 'sync_status') continue;

        if (await db.tableExists(table)) {
          try {
            final indexCheck = await db.query(
              "SELECT COUNT(*) as cnt FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name = ? AND index_name = 'idx_uuid'",
              [table],
            );
            final hasIndex =
                (int.tryParse(indexCheck.first['cnt'].toString()) ?? 0) > 0;
            if (!hasIndex) {
              await db.execute(
                'ALTER TABLE `$table` ADD UNIQUE INDEX `idx_uuid` (`uuid`)',
              );
            }
          } catch (e) {
            // Handle index creation error
          }

          // Add updated_at if missing
          if (!await db.columnExists(table, 'updated_at')) {
            await db.execute(
              'ALTER TABLE `$table` ADD COLUMN `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
            );
          }

          // Add is_deleted if missing
          if (!await db.columnExists(table, 'is_deleted')) {
            await db.execute(
              'ALTER TABLE `$table` ADD COLUMN `is_deleted` TINYINT(1) DEFAULT 0',
            );
          }

          // Add needs_sync if missing (local only, but safe for remote)
          if (!await db.columnExists(table, 'needs_sync')) {
            await db.execute(
              'ALTER TABLE `$table` ADD COLUMN `needs_sync` TINYINT(1) DEFAULT 0',
            );
          }

          // Add source_id if missing
          if (!await db.columnExists(table, 'source_id')) {
            await db.execute(
              'ALTER TABLE `$table` ADD COLUMN `source_id` VARCHAR(50) DEFAULT "local_server"',
            );
          }

          // Initialize UUIDs for existing rows if any were null
          await db.execute(
            'UPDATE `$table` SET `uuid` = (SELECT UUID()) WHERE `uuid` IS NULL',
          );
        }
      }
    // ── Fix double-encoded UTF-8 French characters ──────────────────
    try {
      await repairAllDoubleEncodedData(db);
    } catch (e) {
      debugPrint('Encoding repair migration error: $e');
    }
    } catch (e, stackTrace) {
      debugPrint('Database migration error: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
}
