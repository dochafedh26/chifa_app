-- =====================================================================
-- Script d'initialisation & mise à niveau Base de Données Clinique Chifa
-- Compatible MySQL 5.7+ / MariaDB 10.3+ / Octenium cPanel
-- =====================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- 1. Table des clés d'activation établissement
CREATE TABLE IF NOT EXISTS `activation_keys` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `license_key` VARCHAR(100) UNIQUE NOT NULL,
  `description` VARCHAR(255) DEFAULT 'Clé Établissement Clinique Chifa',
  `max_devices` INT DEFAULT 50,
  `used_devices` INT DEFAULT 0,
  `is_active` TINYINT(1) DEFAULT 1,
  `expires_at` DATETIME DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Clé maître par défaut
INSERT IGNORE INTO `activation_keys` (`license_key`, `description`, `max_devices`)
VALUES ('CHIFA-CLINIC-2026-HQ', 'Clé Maître Clinique Chifa HQ', 50);

-- 2. Table des postes activés (empreinte matérielle)
CREATE TABLE IF NOT EXISTS `activation_devices` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `key_id` INT NOT NULL,
  `machine_id` VARCHAR(150) NOT NULL,
  `machine_name` VARCHAR(150) DEFAULT NULL,
  `ip_address` VARCHAR(45) DEFAULT NULL,
  `activated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `last_seen_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY `uq_key_machine` (`key_id`, `machine_id`),
  CONSTRAINT `fk_act_device_key` FOREIGN KEY (`key_id`) REFERENCES `activation_keys`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Mise à niveau table employees (approbation administrateur)
-- Note: Si les colonnes existent déjà, ces instructions seront ignorées ou gérées par le backend
ALTER TABLE `employees` ADD COLUMN IF NOT EXISTS `is_active` TINYINT(1) DEFAULT 1;
ALTER TABLE `employees` ADD COLUMN IF NOT EXISTS `approved_at` DATETIME DEFAULT NULL;
ALTER TABLE `employees` ADD COLUMN IF NOT EXISTS `approved_by` VARCHAR(100) DEFAULT NULL;

-- 4. Mise à niveau table patients (portail patient)
ALTER TABLE `patients` ADD COLUMN IF NOT EXISTS `portal_pin_hash` VARCHAR(255) DEFAULT NULL;
ALTER TABLE `patients` ADD COLUMN IF NOT EXISTS `portal_access_enabled` TINYINT(1) DEFAULT 1;

-- 5. Table des documents téléversés par les patients
CREATE TABLE IF NOT EXISTS `patient_portal_uploads` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `uuid` VARCHAR(36) UNIQUE NOT NULL,
  `patient_id` INT NOT NULL,
  `file_path` VARCHAR(255) NOT NULL,
  `original_name` VARCHAR(255) NOT NULL,
  `file_type` VARCHAR(100) NOT NULL,
  `file_size` INT DEFAULT 0,
  `category` VARCHAR(100) DEFAULT 'Analyses Biologiques',
  `notes` TEXT DEFAULT NULL,
  `status` VARCHAR(20) DEFAULT 'pending',
  `viewed_by` INT DEFAULT NULL,
  `viewed_at` DATETIME DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `is_deleted` TINYINT(1) DEFAULT 0,
  `needs_sync` TINYINT(1) DEFAULT 0,
  `source_id` VARCHAR(50) DEFAULT 'portal',
  KEY `idx_ppu_patient` (`patient_id`),
  KEY `idx_ppu_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. Table des notifications pour les médecins et le secrétariat
CREATE TABLE IF NOT EXISTS `notifications` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `uuid` VARCHAR(36) UNIQUE NOT NULL,
  `doctor_id` INT DEFAULT NULL,
  `patient_id` INT NOT NULL,
  `title` VARCHAR(150) NOT NULL,
  `message` TEXT NOT NULL,
  `type` VARCHAR(50) DEFAULT 'patient_upload',
  `reference_id` INT DEFAULT NULL,
  `is_read` TINYINT(1) DEFAULT 0,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `is_deleted` TINYINT(1) DEFAULT 0,
  `needs_sync` TINYINT(1) DEFAULT 0,
  `source_id` VARCHAR(50) DEFAULT 'portal',
  KEY `idx_notif_doc` (`doctor_id`),
  KEY `idx_notif_patient` (`patient_id`),
  KEY `idx_notif_read` (`is_read`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 7. Table sync_status
CREATE TABLE IF NOT EXISTS `sync_status` (
  `table_name` VARCHAR(50) NOT NULL,
  `last_push_at` TIMESTAMP NOT NULL DEFAULT '1970-01-01 00:00:00',
  `last_pull_at` TIMESTAMP NOT NULL DEFAULT '1970-01-01 00:00:00',
  PRIMARY KEY (`table_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

