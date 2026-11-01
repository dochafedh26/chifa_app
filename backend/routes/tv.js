const express = require('express');
const router = express.Router();
const db = require('../db');

// GET /api/tv/waiting-room
router.get('/waiting-room', async (req, res) => {
  try {
    const today = new Date().toISOString().slice(0, 10);
    const [rows] = await db.query(
      `SELECT a.appointment_id, a.appointment_date, a.status, a.notes,
              p.first_name, p.last_name, p.gender
       FROM appointments a
       JOIN patients p ON a.patient_id = p.patient_id
       WHERE a.is_deleted = 0 
         AND DATE(a.appointment_date) = ?
         AND a.status IN ('waitingRoom', 'inConsultation', 'scheduled')
       ORDER BY 
         CASE WHEN a.status = 'inConsultation' THEN 1
              WHEN a.status = 'waitingRoom' THEN 2
              ELSE 3 END,
         a.appointment_date ASC`,
      [today]
    );

    let ticketCounter = 1;
    const waitingQueue = [];
    let calledPatient = null;

    rows.forEach((r) => {
      const isMale = (r.gender || '').toLowerCase().startsWith('m') || r.gender === 'male';
      const title = isMale ? 'M.' : 'Mme';
      const initial = (r.last_name || '').trim().charAt(0).toUpperCase();
      const firstName = (r.first_name || '').trim().toUpperCase();
      const maskedName = `${title} ${firstName} ${initial ? initial + '.' : ''}`.trim();
      const timeStr = r.appointment_date
        ? new Date(r.appointment_date).toLocaleTimeString('fr-FR', {
            hour: '2-digit',
            minute: '2-digit',
          })
        : '--:--';

      const item = {
        id: r.appointment_id,
        ticket: ticketCounter++,
        masked_name: maskedName,
        status: r.status,
        time: timeStr,
        cabinet: r.notes && r.notes.includes('Cabinet') ? r.notes : 'Cabinet N° 1 (Dr. BENALI)',
      };

      if (!calledPatient && (r.status === 'inConsultation' || r.status === 'waitingRoom')) {
        calledPatient = item;
      }
      if (r.status === 'waitingRoom') {
        waitingQueue.push(item);
      }
    });

    res.json({
      success: true,
      clinic_name: 'Clinique Chifa',
      current_time: new Date().toISOString(),
      called_patient: calledPatient,
      waiting_queue: waitingQueue,
    });
  } catch (err) {
    console.error('[TV Waiting Room Error]', err);
    res.status(500).json({ error: 'Erreur lors de la récupération de la file: ' + err.message });
  }
});

// In-memory Scan Sessions for Smartphone / Webcam Bridge
const scanSessions = new Map();

// Cleanup sessions older than 30 minutes
setInterval(() => {
  const now = Date.now();
  for (const [id, sess] of scanSessions.entries()) {
    if (now - sess.createdAt > 30 * 60 * 1000) {
      scanSessions.delete(id);
    }
  }
}, 5 * 60 * 1000);

// POST /api/tv/scan-session (Create new session)
router.post('/scan-session', (req, res) => {
  const sessionId = 'scan_' + Math.random().toString(36).substring(2, 10);
  scanSessions.set(sessionId, { sessionId, scanResult: null, createdAt: Date.now() });
  res.json({ success: true, sessionId });
});

// GET /api/tv/scan-session/:id (Poll session status)
router.get('/scan-session/:id', (req, res) => {
  let sess = scanSessions.get(req.params.id);
  if (!sess) {
    sess = { sessionId: req.params.id, scanResult: null, createdAt: Date.now() };
    scanSessions.set(req.params.id, sess);
  }
  res.json({ success: true, scanResult: sess.scanResult });
});

// POST /api/tv/scan-result (Smartphone / Webcam posts scan result)
router.post('/scan-result', (req, res) => {
  const { sessionId, payload } = req.body;
  if (!sessionId || !payload) {
    return res.status(400).json({ error: 'Données manquantes (sessionId ou payload)' });
  }
  let sess = scanSessions.get(sessionId);
  if (!sess) {
    sess = { sessionId, scanResult: payload, createdAt: Date.now() };
    scanSessions.set(sessionId, sess);
  } else {
    sess.scanResult = payload;
  }
  res.json({ success: true, message: 'Scan reçu avec succès' });
});

module.exports = router;

