const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const db = require('../db');
const { authenticate, requireAdmin } = require('../middleware/auth');

// Rate limiting for auth endpoints
const loginAttempts = new Map();
function rateLimiter(req, res, next) {
  const ip = req.ip || req.connection?.remoteAddress || 'unknown';
  const now = Date.now();
  const windowMs = 60 * 1000;
  const maxAttempts = 15;

  const record = loginAttempts.get(ip);
  if (record && record.resetTime > now) {
    if (record.count >= maxAttempts) {
      const waitSec = Math.ceil((record.resetTime - now) / 1000);
      return res.status(429).json({
        error: `Trop de tentatives. Veuillez patienter ${waitSec} secondes.`,
      });
    }
    record.count++;
  } else {
    loginAttempts.set(ip, { count: 1, resetTime: now + windowMs });
  }

  if (loginAttempts.size > 500) {
    for (const [key, val] of loginAttempts.entries()) {
      if (val.resetTime <= now) loginAttempts.delete(key);
    }
  }

  next();
}

// Ensure column is_active exists in employees table
(async function initEmployeeApproval() {
  try {
    const [cols] = await db.query("SHOW COLUMNS FROM employees LIKE 'is_active'");
    if (cols.length === 0) {
      await db.query("ALTER TABLE employees ADD COLUMN IF NOT EXISTS is_active SMALLINT DEFAULT 1");
      console.log("[Auth] Added 'is_active' column to employees table.");
    }
    const [approvedCols] = await db.query("SHOW COLUMNS FROM employees LIKE 'approved_at'");
    if (approvedCols.length === 0) {
      await db.query("ALTER TABLE employees ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP DEFAULT NULL");
      await db.query("ALTER TABLE employees ADD COLUMN IF NOT EXISTS approved_by VARCHAR(100) DEFAULT NULL");
      console.log("[Auth] Added approval audit columns to employees table.");
    }
  } catch (e) {
    console.warn("[Auth] Notice during employees schema check:", e.message);
  }
})();

// ─── POST /api/auth/login ─────────────────────────────────────────────────────
router.post('/login', rateLimiter, async (req, res) => {
  const { email, password, username } = req.body;
  const identifier = (email || username || '').trim();

  if (!identifier || !password) {
    return res.status(400).json({ error: 'Identifiant (email) et mot de passe requis.' });
  }

  try {
    const [rows] = await db.query(
      'SELECT * FROM employees WHERE (email = ? OR phone = ?) AND is_deleted = 0',
      [identifier, identifier]
    );

    if (rows.length === 0) {
      return res.status(401).json({ error: 'Utilisateur introuvable.' });
    }

    const employee = rows[0];

    // Check password
    let hash = employee.password || '';
    if (hash.startsWith('$2y$')) hash = hash.replace('$2y$', '$2a$');

    const valid = await bcrypt.compare(password, hash);
    if (!valid) {
      return res.status(401).json({ error: 'Mot de passe incorrect.' });
    }

    // Check account approval
    if (employee.is_active === 0 || employee.is_active === false) {
      return res.status(403).json({
        error: "Votre compte est en attente de validation par l'administrateur de la clinique. Veuillez contacter la direction.",
        pending_approval: true,
      });
    }

    const token = jwt.sign(
      {
        employeeId: employee.employee_id,
        email: employee.email,
        role: employee.role,
        firstName: employee.first_name,
        lastName: employee.last_name,
      },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    const { password: _pw, ...safeEmployee } = employee;
    res.json({ token, employee: safeEmployee });
  } catch (err) {
    console.error('[Auth] Login error:', err);
    res.status(500).json({ error: 'Erreur lors de la connexion: ' + err.message });
  }
});

// ─── POST /api/auth/signup ───────────────────────────────────────────────────
// Public signup for staff/doctors: creates account with is_active = 0
router.post('/signup', rateLimiter, async (req, res) => {
  const { first_name, last_name, email, phone, password, role, specialization } = req.body;

  if (!first_name || !last_name || !email || !password) {
    return res.status(400).json({ error: 'Nom, prénom, email et mot de passe sont requis.' });
  }

  try {
    const cleanEmail = email.trim().toLowerCase();
    const [existing] = await db.query(
      'SELECT employee_id FROM employees WHERE LOWER(email) = ? AND is_deleted = 0',
      [cleanEmail]
    );

    if (existing.length > 0) {
      return res.status(409).json({ error: 'Cet email est déjà utilisé par un autre compte.' });
    }

    const salt = await bcrypt.genSalt(10);
    const hash = await bcrypt.hash(password, salt);
    const newUuid = crypto.randomUUID();
    const assignedRole = role || 'Doctor';
    const accessLevel = assignedRole.toLowerCase() === 'admin' ? 'full' : 'limited';

    const [result] = await db.query(
      `INSERT INTO employees 
        (uuid, first_name, last_name, role, specialization, email, phone, password, access_level, is_active, needs_sync)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 1)`,
      [
        newUuid,
        first_name.trim(),
        last_name.trim(),
        assignedRole,
        specialization || '',
        cleanEmail,
        phone || '',
        hash,
        accessLevel,
      ]
    );

    res.status(201).json({
      success: true,
      employee_id: result.insertId,
      uuid: newUuid,
      message: "Votre compte a été enregistré avec succès. Pour des motifs de confidentialité médicale, votre compte doit être approuvé par l'administrateur avant votre première connexion.",
      is_active: 0,
    });
  } catch (err) {
    console.error('[Auth] Signup error:', err);
    res.status(500).json({ error: "Erreur lors de l'enregistrement: " + err.message });
  }
});

// ─── GET /api/auth/pending-users (Admin only) ─────────────────────────────────
router.get('/pending-users', authenticate, requireAdmin, async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT employee_id, uuid, first_name, last_name, role, specialization, email, phone, access_level, created_at, is_active 
      FROM employees 
      WHERE is_active = 0 AND is_deleted = 0
      ORDER BY created_at DESC
    `);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── PUT /api/auth/users/:id/approve (Admin only) ──────────────────────────────
router.put('/users/:id/approve', authenticate, requireAdmin, async (req, res) => {
  try {
    const adminName = req.user.firstName ? `${req.user.firstName} ${req.user.lastName}` : (req.user.email || 'Admin');
    await db.query(
      'UPDATE employees SET is_active = 1, approved_at = NOW(), approved_by = ?, needs_sync = 1 WHERE employee_id = ?',
      [adminName, req.params.id]
    );
    res.json({ success: true, message: "Compte praticien validé et activé avec succès." });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── PUT /api/auth/users/:id/toggle-active (Admin only) ─────────────────────────
router.put('/users/:id/toggle-active', authenticate, requireAdmin, async (req, res) => {
  const { is_active } = req.body;
  try {
    const status = is_active ? 1 : 0;
    await db.query(
      'UPDATE employees SET is_active = ?, needs_sync = 1 WHERE employee_id = ?',
      [status, req.params.id]
    );
    res.json({ success: true, is_active: status });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── GET /api/auth/me ─────────────────────────────────────────────────────────
router.get('/me', authenticate, async (req, res) => {
  try {
    const [rows] = await db.query(
      'SELECT employee_id, uuid, first_name, last_name, role, specialization, email, phone, access_level, is_active FROM employees WHERE employee_id = ?',
      [req.user.employeeId]
    );
    if (rows.length === 0) return res.status(404).json({ error: 'Utilisateur introuvable.' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

