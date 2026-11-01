const express = require('express');
const router = express.Router();
const db = require('../db');
const { authenticate } = require('../middleware/auth');

router.use(authenticate);

// ─── GET /api/notifications/count ────────────────────────────────────────────
// Lightweight endpoint for frequent badge polling in Flutter desktop
router.get('/count', async (req, res) => {
  try {
    const doctorId = req.user.employeeId;
    const [rows] = await db.query(
      `SELECT COUNT(*) as count 
       FROM notifications 
       WHERE is_read = 0 AND is_deleted = 0 
         AND (doctor_id = ? OR doctor_id IS NULL)`,
      [doctorId]
    );
    res.json({ unread_count: rows[0]?.count || 0 });
  } catch (err) {
    console.error('[notifications:count]', err);
    res.status(500).json({ error: err.message });
  }
});

// ─── GET /api/notifications ──────────────────────────────────────────────────
// Returns recent notifications with patient name and document information
router.get('/', async (req, res) => {
  const limit = parseInt(req.query.limit) || 30;
  const doctorId = req.user.employeeId;

  try {
    const [rows] = await db.query(
      `SELECT n.id, n.uuid, n.doctor_id, n.patient_id, n.title, n.message, n.type, 
              n.reference_id, n.is_read, n.created_at,
              CONCAT(p.first_name, ' ', p.last_name) as patient_name,
              p.phone as patient_phone,
              u.file_path, u.original_name, u.file_type, u.category as doc_category, u.status as doc_status
       FROM notifications n
       LEFT JOIN patients p ON n.patient_id = p.patient_id
       LEFT JOIN patient_portal_uploads u ON n.reference_id = u.id AND n.type = 'patient_upload'
       WHERE n.is_deleted = 0 AND (n.doctor_id = ? OR n.doctor_id IS NULL)
       ORDER BY n.created_at DESC 
       LIMIT ?`,
      [doctorId, limit]
    );

    res.json(rows);
  } catch (err) {
    console.error('[notifications:list]', err);
    res.status(500).json({ error: err.message });
  }
});

// ─── PUT /api/notifications/:id/read ──────────────────────────────────────────
router.put('/:id/read', async (req, res) => {
  try {
    await db.query(
      'UPDATE notifications SET is_read = 1, needs_sync = 1 WHERE id = ?',
      [req.params.id]
    );

    // If it is a patient_upload, also mark the upload as viewed
    const [notif] = await db.query('SELECT reference_id, type FROM notifications WHERE id = ?', [req.params.id]);
    if (notif.length > 0 && notif[0].type === 'patient_upload' && notif[0].reference_id) {
      await db.query(
        'UPDATE patient_portal_uploads SET status = "viewed", viewed_by = ?, viewed_at = NOW(), needs_sync = 1 WHERE id = ?',
        [req.user.employeeId, notif[0].reference_id]
      );
    }

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── PUT /api/notifications/read-all ──────────────────────────────────────────
router.put('/read-all', async (req, res) => {
  try {
    const doctorId = req.user.employeeId;
    await db.query(
      'UPDATE notifications SET is_read = 1, needs_sync = 1 WHERE is_read = 0 AND (doctor_id = ? OR doctor_id IS NULL)',
      [doctorId]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

