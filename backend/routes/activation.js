const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const db = require('../db');
const { authenticate, requireAdmin } = require('../middleware/auth');

// Auto-create activation tables if not present
(async function initActivationTables() {
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS activation_keys (
        id INT AUTO_INCREMENT PRIMARY KEY,
        license_key VARCHAR(100) UNIQUE NOT NULL,
        description VARCHAR(255) DEFAULT 'Clé Établissement Clinique Chifa',
        max_devices INT DEFAULT 50,
        used_devices INT DEFAULT 0,
        is_active TINYINT DEFAULT 1,
        expires_at DATETIME DEFAULT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    `);

    await db.query(`
      CREATE TABLE IF NOT EXISTS activation_devices (
        id INT AUTO_INCREMENT PRIMARY KEY,
        key_id INT NOT NULL,
        machine_id VARCHAR(150) NOT NULL,
        machine_name VARCHAR(150) DEFAULT NULL,
        ip_address VARCHAR(45) DEFAULT NULL,
        activated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        last_seen_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uq_key_machine (key_id, machine_id),
        CONSTRAINT fk_dev_key FOREIGN KEY (key_id) REFERENCES activation_keys(id) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    `);

    // Ensure at least one default master establishment key exists
    const [rows] = await db.query('SELECT id FROM activation_keys LIMIT 1');
    if (rows.length === 0) {
      const defaultKey = process.env.MASTER_ACTIVATION_KEY || 'CHIFA-CLINIC-2026-HQ';
      await db.query(
        'INSERT INTO activation_keys (license_key, description, max_devices) VALUES (?, ?, ?)',
        [defaultKey, 'Clé Maître Clinique Chifa HQ', 50]
      );
      console.log(`[Activation] Initialized master activation key: ${defaultKey}`);
    }
  } catch (err) {
    console.warn('[Activation] Notice during table initialization:', err.message);
  }
})();

// ─── POST /api/activation/verify or / ─────────────────────────────────────────
// Public endpoint used by newly installed desktop apps to activate the machine
router.post(['/', '/verify'], async (req, res) => {
  const rawKey = req.body.key || req.body.activation_key || req.query.key;
  const { machine_id, machine_name } = req.body;
  if (!rawKey || typeof rawKey !== 'string' || !rawKey.trim()) {
    return res.status(400).json({ error: "La clé d'activation est requise." });
  }

  const cleanKey = rawKey.trim().toUpperCase();
  const cleanMachineId = (machine_id || '').trim() || 'unknown_device';
  const cleanMachineName = (machine_name || '').trim() || 'Poste Windows';
  const ip = req.ip || req.connection?.remoteAddress || '';

  try {
    const [rows] = await db.query(
      'SELECT * FROM activation_keys WHERE UPPER(license_key) = ?',
      [cleanKey]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        error: "Clé d'activation invalide ou inexistante. Veuillez contacter l'administrateur de la clinique.",
      });
    }

    const keyRecord = rows[0];

    if (keyRecord.is_active !== 1) {
      return res.status(403).json({
        error: "Cette clé d'activation a été désactivée ou révoquée.",
      });
    }

    if (keyRecord.expires_at && new Date(keyRecord.expires_at) < new Date()) {
      return res.status(403).json({
        error: "Cette clé d'activation a expiré.",
      });
    }

    // Check if this machine was already registered for this key
    const [existingDevice] = await db.query(
      'SELECT id FROM activation_devices WHERE key_id = ? AND machine_id = ?',
      [keyRecord.id, cleanMachineId]
    );

    if (existingDevice.length > 0) {
      // Already registered, update last seen
      await db.query(
        'UPDATE activation_devices SET last_seen_at = NOW(), ip_address = ? WHERE id = ?',
        [ip, existingDevice[0].id]
      );

      return res.json({
        success: true,
        message: "Poste déjà validé et actif.",
        license_key: keyRecord.license_key,
        description: keyRecord.description,
        machine_id: cleanMachineId,
      });
    }

    // New machine registration: check quota
    if (keyRecord.used_devices >= keyRecord.max_devices) {
      return res.status(403).json({
        error: `Le nombre maximal de postes autorisés (${keyRecord.max_devices}) pour cette clé a été atteint.`,
      });
    }

    // Register device and increment count
    await db.query(
      'INSERT INTO activation_devices (key_id, machine_id, machine_name, ip_address) VALUES (?, ?, ?, ?)',
      [keyRecord.id, cleanMachineId, cleanMachineName, ip]
    );

    await db.query(
      'UPDATE activation_keys SET used_devices = used_devices + 1 WHERE id = ?',
      [keyRecord.id]
    );

    res.json({
      success: true,
      message: "Poste activé avec succès auprès du Cloud établissement.",
      license_key: keyRecord.license_key,
      description: keyRecord.description,
      machine_id: cleanMachineId,
    });
  } catch (err) {
    console.error('[Activation] Verification error:', err);
    res.status(500).json({ error: "Erreur lors de la vérification de la clé: " + err.message });
  }
});

// ─── GET /api/activation/keys (Admin only) ────────────────────────────────────
router.get('/keys', authenticate, requireAdmin, async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT k.*, 
        (SELECT COUNT(*) FROM activation_devices d WHERE d.key_id = k.id) as active_devices_count
      FROM activation_keys k 
      ORDER BY k.id DESC
    `);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── POST /api/activation/keys (Admin only) ───────────────────────────────────
router.post('/keys', authenticate, requireAdmin, async (req, res) => {
  const { license_key, description, max_devices, expires_at } = req.body;
  
  // Auto-generate key if not supplied
  const keyToUse = (license_key && license_key.trim())
    ? license_key.trim().toUpperCase()
    : 'CHIFA-' + crypto.randomBytes(4).toString('hex').toUpperCase() + '-' + new Date().getFullYear();

  try {
    const [result] = await db.query(
      'INSERT INTO activation_keys (license_key, description, max_devices, expires_at) VALUES (?, ?, ?, ?)',
      [
        keyToUse,
        description || 'Poste Clinique Chifa',
        max_devices ? parseInt(max_devices) : 25,
        expires_at || null,
      ]
    );
    res.status(201).json({
      id: result.insertId,
      license_key: keyToUse,
      message: "Nouvelle clé d'activation créée avec succès.",
    });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: "Cette clé d'activation existe déjà." });
    }
    res.status(500).json({ error: err.message });
  }
});

// ─── PUT /api/activation/keys/:id/toggle (Admin only) ─────────────────────────
router.put('/keys/:id/toggle', authenticate, requireAdmin, async (req, res) => {
  try {
    const [rows] = await db.query('SELECT is_active FROM activation_keys WHERE id = ?', [req.params.id]);
    if (rows.length === 0) return res.status(404).json({ error: 'Clé introuvable' });

    const newStatus = rows[0].is_active === 1 ? 0 : 1;
    await db.query('UPDATE activation_keys SET is_active = ? WHERE id = ?', [newStatus, req.params.id]);
    res.json({ success: true, is_active: newStatus });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── GET /api/activation/keys/:id/devices (Admin only) ────────────────────────
router.get('/keys/:id/devices', authenticate, requireAdmin, async (req, res) => {
  try {
    const [rows] = await db.query(
      'SELECT * FROM activation_devices WHERE key_id = ? ORDER BY activated_at DESC',
      [req.params.id]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── DELETE /api/activation/devices/:id (Admin only) ──────────────────────────
router.delete('/devices/:id', authenticate, requireAdmin, async (req, res) => {
  try {
    const [device] = await db.query('SELECT key_id FROM activation_devices WHERE id = ?', [req.params.id]);
    if (device.length > 0) {
      await db.query('DELETE FROM activation_devices WHERE id = ?', [req.params.id]);
      await db.query(
        'UPDATE activation_keys SET used_devices = GREATEST(0, used_devices - 1) WHERE id = ?',
        [device[0].key_id]
      );
    }
    res.json({ success: true, message: 'Poste révoqué.' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

