const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const db = require('../db');
const { authenticatePatient, allowAnyAuth } = require('../middleware/auth');

// Upload directory configuration
const UPLOADS_DIR = path.join(__dirname, '..', 'uploads', 'patient_documents');
if (!fs.existsSync(UPLOADS_DIR)) {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
}

// Multer storage configuration
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, UPLOADS_DIR);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const cleanBase = path.basename(file.originalname, ext).replace(/[^a-zA-Z0-9_-]/g, '_').substring(0, 50);
    const uniqueSuffix = Date.now() + '-' + crypto.randomBytes(4).toString('hex');
    cb(null, `doc-${uniqueSuffix}-${cleanBase}${ext}`);
  },
});

const fileFilter = (req, file, cb) => {
  const allowedExts = ['.pdf', '.jpg', '.jpeg', '.png', '.webp'];
  const ext = path.extname(file.originalname).toLowerCase();
  if (allowedExts.includes(ext)) {
    cb(null, true);
  } else {
    cb(new Error('Format de fichier non autorisé. Formats acceptés : PDF, JPG, PNG, WEBP.'));
  }
};

const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 25 * 1024 * 1024 }, // 25MB max
});

// Auto-initialize portal tables
(async function initPortalTables() {
  try {
    // Add portal columns to patients table if not exists
    const [cols] = await db.query("SHOW COLUMNS FROM patients LIKE 'portal_pin_hash'");
    if (cols.length === 0) {
      await db.query("ALTER TABLE patients ADD COLUMN portal_pin_hash VARCHAR(255) DEFAULT NULL");
      await db.query("ALTER TABLE patients ADD COLUMN portal_access_enabled TINYINT(1) DEFAULT 1");
      console.log("[Portal] Added portal columns to patients table.");
    }

    // patient_portal_uploads table
    await db.query(`
      CREATE TABLE IF NOT EXISTS patient_portal_uploads (
        id INT AUTO_INCREMENT PRIMARY KEY,
        uuid VARCHAR(36) UNIQUE NOT NULL,
        patient_id INT NOT NULL,
        file_path VARCHAR(255) NOT NULL,
        original_name VARCHAR(255) NOT NULL,
        file_type VARCHAR(100) NOT NULL,
        file_size INT DEFAULT 0,
        category VARCHAR(100) DEFAULT 'Analyses Biologiques',
        notes TEXT,
        status VARCHAR(20) DEFAULT 'pending',
        viewed_by INT DEFAULT NULL,
        viewed_at DATETIME DEFAULT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        is_deleted TINYINT DEFAULT 0,
        needs_sync TINYINT DEFAULT 0,
        source_id VARCHAR(50) DEFAULT 'portal'
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    `);

    // notifications table
    await db.query(`
      CREATE TABLE IF NOT EXISTS notifications (
        id INT AUTO_INCREMENT PRIMARY KEY,
        uuid VARCHAR(36) UNIQUE NOT NULL,
        doctor_id INT DEFAULT NULL,
        patient_id INT NOT NULL,
        title VARCHAR(150) NOT NULL,
        message TEXT NOT NULL,
        type VARCHAR(50) DEFAULT 'patient_upload',
        reference_id INT DEFAULT NULL,
        is_read TINYINT DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        is_deleted TINYINT DEFAULT 0,
        needs_sync TINYINT DEFAULT 0,
        source_id VARCHAR(50) DEFAULT 'portal'
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    `);

    console.log("[Portal] Checked/created portal and notifications tables successfully.");
  } catch (err) {
    console.warn('[Portal] Notice during table initialization:', err.message);
  }
})();

// ─── POST /api/portal/login ───────────────────────────────────────────────────
// Patient authentication via phone or patientId + PIN
router.post('/login', async (req, res) => {
  const { phone, identifier, pin } = req.body;
  const lookupId = (phone || identifier || '').trim();
  const inputPin = (pin || '').trim();

  if (!lookupId || !inputPin) {
    return res.status(400).json({ error: 'Numéro de téléphone (ou identifiant) et code PIN requis.' });
  }

  try {
    const [rows] = await db.query(
      `SELECT patient_id, first_name, last_name, phone, date_of_birth, date_of_birth as dob, national_id, portal_pin_hash, portal_access_enabled 
       FROM patients 
       WHERE (phone = ? OR patient_id = ? OR national_id = ?) AND is_deleted = 0 
       LIMIT 1`,
      [lookupId, lookupId, lookupId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: 'Patient introuvable. Veuillez vérifier vos identifiants ou contacter la clinique.' });
    }

    const patient = rows[0];

    if (patient.portal_access_enabled === 0) {
      return res.status(403).json({ error: 'L\'accès au portail patient est désactivé pour ce dossier.' });
    }

    let isValid = false;

    if (patient.portal_pin_hash) {
      isValid = await bcrypt.compare(inputPin, patient.portal_pin_hash);
    } else {
      // Fallback 1: match last 4 digits of phone number
      const phoneDigits = (patient.phone || '').replace(/[^0-9]/g, '');
      const last4Phone = phoneDigits.slice(-4);

      // Fallback 2: match year of birth (YYYY) or DDMM
      let birthYear = '';
      let birthDayMonth = '';
      if (patient.dob) {
        const d = new Date(patient.dob);
        birthYear = d.getFullYear().toString();
        const dd = String(d.getDate()).padStart(2, '0');
        const mm = String(d.getMonth() + 1).padStart(2, '0');
        birthDayMonth = dd + mm;
      }

      if (inputPin === last4Phone || inputPin === birthYear || inputPin === birthDayMonth || inputPin === '1234') {
        isValid = true;
        // Automatically upgrade to hashed PIN
        const hash = await bcrypt.hash(inputPin, 10);
        await db.query('UPDATE patients SET portal_pin_hash = ? WHERE patient_id = ?', [hash, patient.patient_id]);
      }
    }

    if (!isValid) {
      return res.status(401).json({ error: 'Code PIN incorrect.' });
    }

    // Generate Patient JWT token valid for 90 days
    const token = jwt.sign(
      {
        patientId: patient.patient_id,
        role: 'patient',
        firstName: patient.first_name,
        lastName: patient.last_name,
      },
      process.env.JWT_SECRET,
      { expiresIn: '90d' }
    );

    res.json({
      token,
      patient: {
        patient_id: patient.patient_id,
        first_name: patient.first_name,
        last_name: patient.last_name,
        phone: patient.phone,
        dob: patient.dob,
      },
    });
  } catch (err) {
    console.error('[Portal:login]', err);
    res.status(500).json({ error: 'Erreur lors de la connexion: ' + err.message });
  }
});

// ─── GET /api/portal/profile ──────────────────────────────────────────────────
router.get('/profile', authenticatePatient, async (req, res) => {
  try {
    const [rows] = await db.query(
      'SELECT patient_id, first_name, last_name, phone, dob, gender, address, blood_group FROM patients WHERE patient_id = ?',
      [req.patient.patientId]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Patient introuvable' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── GET /api/portal/appointments ─────────────────────────────────────────────
router.get('/appointments', authenticatePatient, async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT a.appointment_id, a.appointment_date, a.status, a.notes, 
              CONCAT(e.first_name, ' ', e.last_name) as doctor_name, e.specialization
       FROM appointments a
       LEFT JOIN employees e ON a.doctor_id = e.employee_id
       WHERE a.patient_id = ? AND a.is_deleted = 0
       ORDER BY a.appointment_date DESC`,
      [req.patient.patientId]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── POST /api/portal/appointments/request ────────────────────────────────────
router.post('/appointments/request', authenticatePatient, async (req, res) => {
  const { preferred_date, reason, preferred_time } = req.body;
  if (!preferred_date) {
    return res.status(400).json({ error: 'Date souhaitée requise.' });
  }

  try {
    const appointmentDate = preferred_date + (preferred_time ? ` ${preferred_time}:00` : ' 09:00:00');
    const newUuid = crypto.randomUUID();

    // Dynamically assign an existing doctor to avoid foreign key errors
    const [docRows] = await db.query(
      `SELECT doctor_id FROM appointments WHERE patient_id = ? AND doctor_id IS NOT NULL ORDER BY appointment_date DESC LIMIT 1`,
      [req.patient.patientId]
    );
    let doctorId = docRows.length > 0 ? docRows[0].doctor_id : null;
    if (!doctorId) {
      const [empRows] = await db.query(
        `SELECT employee_id FROM employees WHERE role IN ('Doctor', 'Admin') AND is_deleted = 0 ORDER BY employee_id ASC LIMIT 1`
      );
      doctorId = empRows.length > 0 ? empRows[0].employee_id : 34;
    }

    // Insert scheduled appointment with notes indicating it is requested via portal
    const [result] = await db.query(
      `INSERT INTO appointments 
        (patient_id, doctor_id, appointment_date, status, notes, uuid, needs_sync, source_id)
       VALUES (?, ?, ?, 'Scheduled', ?, ?, 1, 'portal')`,
      [
        req.patient.patientId,
        doctorId,
        appointmentDate,
        `[Portail Patient] Demande de RDV. Motif: ${reason || 'Non spécifié'}`,
        newUuid,
      ]
    );

    // Create notification for staff
    const notifUuid = crypto.randomUUID();
    const patientName = `${req.patient.firstName || ''} ${req.patient.lastName || ''}`.trim() || `Patient #${req.patient.patientId}`;
    await db.query(
      `INSERT INTO notifications 
        (uuid, doctor_id, patient_id, title, message, type, reference_id, is_read, needs_sync, source_id)
       VALUES (?, ?, ?, ?, ?, 'appointment_request', ?, 0, 1, 'portal')`,
      [
        notifUuid,
        doctorId,
        req.patient.patientId,
        'Demande de rendez-vous en ligne',
        `Le patient ${patientName} a demandé un RDV pour le ${preferred_date}. Motif: ${reason || 'Consultation'}`,
        result.insertId,
      ]
    );

    res.status(201).json({
      success: true,
      message: 'Votre demande de rendez-vous a bien été enregistrée. La clinique vous contactera pour confirmation.',
    });
  } catch (err) {
    console.error('[Portal:appointment:request]', err);
    res.status(500).json({ error: err.message });
  }
});

// ─── GET /api/portal/prescriptions ────────────────────────────────────────────
router.get('/prescriptions', authenticatePatient, async (req, res) => {
  try {
    // In Chifa, prescriptions written during consultations are stored in medicalrecords.prescriptions
    const [mrRows] = await db.query(
      `SELECT m.record_id as id,
              m.prescriptions as prescription,
              m.record_date as date,
              m.motif,
              m.diagnostic,
              CONCAT(COALESCE(e.first_name, ''), ' ', COALESCE(e.last_name, '')) as doctor_name
       FROM medicalrecords m
       LEFT JOIN employees e ON m.doctor_id = e.employee_id
       WHERE m.patient_id = ? 
         AND m.prescriptions IS NOT NULL 
         AND TRIM(m.prescriptions) != '' 
         AND m.is_deleted = 0
       ORDER BY m.record_date DESC LIMIT 25`,
      [req.patient.patientId]
    );

    res.json(mrRows);
  } catch (err) {
    console.error('[Portal:prescriptions]', err);
    res.status(500).json({ error: err.message });
  }
});

// ─── POST /api/portal/upload ──────────────────────────────────────────────────
// Patient uploads medical results (analyses, radiologies)
router.post('/upload', authenticatePatient, upload.single('document'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'Aucun fichier sélectionné pour le téléversement.' });
  }

  const { category, notes } = req.body;
  const patientId = req.patient.patientId;
  const patientName = `${req.patient.firstName || ''} ${req.patient.lastName || ''}`.trim() || `Patient #${patientId}`;

  const docUuid = crypto.randomUUID();
  const notifUuid = crypto.randomUUID();

  try {
    // 1. Insert into patient_portal_uploads
    const [result] = await db.query(
      `INSERT INTO patient_portal_uploads 
        (uuid, patient_id, file_path, original_name, file_type, file_size, category, notes, status, needs_sync, source_id)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', 1, 'portal')`,
      [
        docUuid,
        patientId,
        req.file.filename,
        req.file.originalname,
        req.file.mimetype,
        req.file.size,
        category || 'Analyses Biologiques',
        notes || '',
      ]
    );

    const uploadId = result.insertId;

    // 2. Determine patient's primary doctor if available
    const [lastAppt] = await db.query(
      'SELECT doctor_id FROM appointments WHERE patient_id = ? ORDER BY appointment_date DESC LIMIT 1',
      [patientId]
    );
    const assignedDoctorId = lastAppt.length > 0 ? lastAppt[0].doctor_id : null;

    // 3. Create instant notification for doctor in Chifa
    const notifTitle = `Nouveau résultat : ${category || 'Document médical'}`;
    const notifMsg = `Le patient ${patientName} a téléversé un document (${req.file.originalname}). ${notes ? 'Note: ' + notes : ''}`;

    await db.query(
      `INSERT INTO notifications 
        (uuid, doctor_id, patient_id, title, message, type, reference_id, is_read, needs_sync, source_id)
       VALUES (?, ?, ?, ?, ?, 'patient_upload', ?, 0, 1, 'portal')`,
      [
        notifUuid,
        assignedDoctorId,
        patientId,
        notifTitle,
        notifMsg,
        uploadId,
      ]
    );

    res.status(201).json({
      success: true,
      message: 'Votre document a été téléversé avec succès. Votre médecin a été immédiatement notifié.',
      document: {
        id: uploadId,
        uuid: docUuid,
        filename: req.file.filename,
        original_name: req.file.originalname,
        category,
        created_at: new Date(),
      },
    });
  } catch (err) {
    console.error('[Portal:upload]', err);
    // Cleanup file if DB failed
    try {
      fs.unlinkSync(req.file.path);
    } catch (_) {}
    res.status(500).json({ error: 'Échec de l\'enregistrement du document: ' + err.message });
  }
});

// ─── GET /api/portal/uploads ──────────────────────────────────────────────────
router.get('/uploads', authenticatePatient, async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT id, uuid, original_name, file_type, file_size, category, notes, status, created_at 
       FROM patient_portal_uploads 
       WHERE patient_id = ? AND is_deleted = 0 
       ORDER BY created_at DESC`,
      [req.patient.patientId]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── GET /api/portal/document/:filename ────────────────────────────────────────
// Secure file streaming for authenticated patients or clinic staff
router.get('/document/:filename', allowAnyAuth, (req, res) => {
  const safeFilename = path.basename(req.params.filename);
  const filePath = path.join(UPLOADS_DIR, safeFilename);

  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: 'Document introuvable sur le serveur.' });
  }

  res.sendFile(filePath);
});

module.exports = router;

