const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const db = require('../db');
const { authenticate } = require('../middleware/auth');

const SYNC_KEY = process.env.SYNC_KEY || 'chifa_sync_secure_key_2026';

// Allow authentication via dedicated X-Sync-Key (for Flutter desktop background sync) OR Bearer JWT
function authenticateSync(req, res, next) {
  const syncKey = req.headers['x-sync-key'];
  if (syncKey && syncKey === SYNC_KEY) {
    req.user = { role: 'Admin', email: 'sync_daemon' };
    return next();
  }
  return authenticate(req, res, next);
}

router.use(authenticateSync);

// Complete list of tables synced between Flutter SQLite and Cloud MySQL
const SYNCABLE_TABLES = [
  'patients',
  'appointments',
  'medicalrecords',
  'medicalrecord_services',
  'prescriptions',
  'modern_prescriptions',
  'bilans',
  'bilan_type',
  'invoices',
  'payments',
  'payment_services',
  'services',
  'expenses',
  'employees',
  'hospitalizations',
  'inventory',
  'soins_medicaux',
  'soins_services',
  'lettres',
  'arret_de_travail',
  'certificat_bonne_sante',
  'certificat_dispense_sport',
  'certificat_aptitude_sport',
  'interpretation_ecg',
  'certificat_maladie_chronique',
  'certificat_prenuptial',
  'ordonnance_type',
  'patients_fideles',
  'patients_suivi',
  'patient_suivi_categories',
  'medalgeriemedics',
  'patient_portal_uploads',
  'notifications',
];

// Helper to format ISO date strings for MySQL
function formatSqlDate(val) {
  if (!val) return null;
  if (typeof val === 'string' && val.includes('T')) {
    return val.replace('T', ' ').substring(0, 19);
  }
  return val;
}

// Cache of table columns to prevent SQL injection and filter invalid fields
const tableColumnsCache = new Map();

async function getTableColumns(tableName) {
  if (tableColumnsCache.has(tableName)) {
    return tableColumnsCache.get(tableName);
  }
  try {
    const [rows] = await db.query(
      `SELECT COLUMN_NAME FROM information_schema.columns 
       WHERE table_schema = DATABASE() AND table_name = ?`,
      [tableName]
    );
    const cols = new Set(rows.map(r => r.column_name || r.COLUMN_NAME));
    tableColumnsCache.set(tableName, cols);
    return cols;
  } catch (err) {
    console.error(`[sync] Failed to get columns for ${tableName}:`, err);
    return new Set();
  }
}

// ─── GET /api/sync/status ─────────────────────────────────────────────────────
router.get('/status', async (req, res) => {
  try {
    const counts = {};
    let totalPending = 0;

    for (const table of SYNCABLE_TABLES) {
      try {
        const cols = await getTableColumns(table);
        if (!cols.has('needs_sync')) {
          counts[table] = 0;
          continue;
        }
        const [rows] = await db.query(`SELECT COUNT(*) as count FROM \`${table}\` WHERE needs_sync = 1`);
        const count = rows[0]?.count || 0;
        counts[table] = count;
        totalPending += count;
      } catch (_) {
        counts[table] = 0;
      }
    }

    res.json({
      totalPending,
      tableCounts: counts,
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    console.error('[sync:status]', err);
    res.status(500).json({ error: err.message });
  }
});

// ─── GET /api/sync/pending ────────────────────────────────────────────────────
router.get('/pending', async (req, res) => {
  try {
    const pendingData = {};

    for (const table of SYNCABLE_TABLES) {
      try {
        const cols = await getTableColumns(table);
        if (!cols.has('needs_sync')) {
          pendingData[table] = [];
          continue;
        }
        const [rows] = await db.query(`SELECT * FROM \`${table}\` WHERE needs_sync = 1 LIMIT 500`);
        pendingData[table] = rows;
      } catch (err) {
        pendingData[table] = [];
      }
    }

    res.json({
      changes: pendingData,
      sourceId: 'cloud_server',
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    console.error('[sync:pending]', err);
    res.status(500).json({ error: err.message });
  }
});

// ─── POST /api/sync/push ──────────────────────────────────────────────────────
router.post('/push', async (req, res) => {
  const { changes, source_id } = req.body;
  if (!changes || typeof changes !== 'object') {
    return res.status(400).json({ error: 'Le corps de la requête doit contenir un objet changes.' });
  }

  const acknowledged = {};
  const origin = source_id || 'desktop_client';

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();

    for (const table of SYNCABLE_TABLES) {
      const records = changes[table];
      if (!Array.isArray(records) || records.length === 0) continue;

      const validColumns = await getTableColumns(table);
      if (validColumns.size === 0) continue;

      acknowledged[table] = [];

      for (const record of records) {
        if (!record.uuid) {
          record.uuid = crypto.randomUUID();
        }

        // Build clean key-value map matching existing columns in table
        const cleanRecord = {};
        for (const [key, val] of Object.entries(record)) {
          if (!validColumns.has(key)) continue;

          // Format dates appropriately
          if (key.endsWith('_at') || key.endsWith('_date') || key === 'dob' || key === 'date') {
            cleanRecord[key] = formatSqlDate(val);
          } else {
            cleanRecord[key] = val;
          }
        }

        cleanRecord.needs_sync = 0;
        cleanRecord.source_id = origin;
        if (!cleanRecord.updated_at) {
          cleanRecord.updated_at = new Date();
        }

        // Check if row exists by uuid
        const [existing] = await connection.query(
          `SELECT uuid, updated_at FROM \`${table}\` WHERE uuid = ?`,
          [record.uuid]
        );

        if (existing.length > 0) {
          // UPDATE
          const updateKeys = Object.keys(cleanRecord).filter(k => k !== 'uuid' && !k.endsWith('_id') || k === 'source_id');
          if (updateKeys.length > 0) {
            const setClause = updateKeys.map(k => `\`${k}\` = ?`).join(', ');
            const updateValues = updateKeys.map(k => cleanRecord[k]);
            updateValues.push(record.uuid);

            await connection.query(
              `UPDATE \`${table}\` SET ${setClause} WHERE uuid = ?`,
              updateValues
            );
          }
        } else {
          // INSERT
          const insertKeys = Object.keys(cleanRecord);
          const insertCols = insertKeys.map(k => `\`${k}\``).join(', ');
          const placeholders = insertKeys.map(() => '?').join(', ');
          const insertValues = insertKeys.map(k => cleanRecord[k]);

          await connection.query(
            `INSERT INTO \`${table}\` (${insertCols}) VALUES (${placeholders})`,
            insertValues
          );
        }

        acknowledged[table].push(record.uuid);
      }
    }

    await connection.commit();
    res.json({ success: true, acknowledged });
  } catch (err) {
    await connection.rollback();
    console.error('[sync:push] Error:', err);
    res.status(500).json({ error: err.message });
  } finally {
    connection.release();
  }
});

// ─── POST /api/sync/acknowledge ───────────────────────────────────────────────
router.post('/acknowledge', async (req, res) => {
  const { acknowledged, all } = req.body;

  try {
    if (all === true) {
      for (const table of SYNCABLE_TABLES) {
        try {
          const cols = await getTableColumns(table);
          if (cols.has('needs_sync')) {
            await db.query(`UPDATE \`${table}\` SET needs_sync = 0 WHERE needs_sync = 1`);
          }
        } catch (_) {}
      }
      return res.json({ success: true, all: true });
    }

    if (!acknowledged || typeof acknowledged !== 'object') {
      return res.status(400).json({ error: 'Format acknowledged invalide' });
    }

    for (const table of SYNCABLE_TABLES) {
      const uuids = acknowledged[table];
      if (!Array.isArray(uuids) || uuids.length === 0) continue;

      const placeholders = uuids.map(() => '?').join(',');
      await db.query(
        `UPDATE \`${table}\` SET needs_sync = 0 WHERE uuid IN (${placeholders})`,
        uuids
      );
    }
    res.json({ success: true });
  } catch (err) {
    console.error('[sync:acknowledge]', err);
    res.status(500).json({ error: err.message });
  }
});

// ─── GET /api/sync/pull ───────────────────────────────────────────────────────
router.get('/pull', async (req, res) => {
  const since = req.query.since ? formatSqlDate(req.query.since) : '1970-01-01 00:00:00';
  const excludeSource = req.query.source_id || '';

  try {
    const pulledData = {};

    for (const table of SYNCABLE_TABLES) {
      try {
        const cols = await getTableColumns(table);
        if (!cols.has('updated_at')) {
          pulledData[table] = [];
          continue;
        }

        let query = `SELECT * FROM \`${table}\` WHERE updated_at > ?`;
        const params = [since];

        if (excludeSource && cols.has('source_id')) {
          query += ` AND (source_id != ? OR source_id IS NULL)`;
          params.push(excludeSource);
        }

        query += ` ORDER BY updated_at ASC LIMIT 1000`;

        const [rows] = await db.query(query, params);
        pulledData[table] = rows;
      } catch (err) {
        console.warn(`[sync:pull] Skip table ${table}:`, err.message);
        pulledData[table] = [];
      }
    }

    res.json({
      changes: pulledData,
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    console.error('[sync:pull]', err);
    res.status(500).json({ error: err.message });
  }
});

// ─── POST /api/sync/query (Web Client SQL Relay) ──────────────────────────────
router.post('/query', async (req, res) => {
  const { sql, params, is_insert } = req.body;
  if (!sql || typeof sql !== 'string') {
    return res.status(400).json({ error: 'La requête SQL est requise.' });
  }

  // Basic guard against destructive global drops
  const trimmed = sql.trim().toUpperCase();
  if (trimmed.startsWith('DROP DATABASE') || trimmed.startsWith('DROP USER')) {
    return res.status(403).json({ error: 'Opération interdite.' });
  }

  try {
    // Ensure all data created or updated from the Web app is tagged as cloud_server
    let processedSql = sql;
    if (processedSql.includes("'local_server'")) {
      processedSql = processedSql.replace(/'local_server'/g, "'cloud_server'");
    }
    if (processedSql.includes('"local_server"')) {
      processedSql = processedSql.replace(/"local_server"/g, '"cloud_server"');
    }

    const formattedParams = Array.isArray(params)
      ? params.map(p => (p === 'local_server' ? 'cloud_server' : p))
      : [];

    const [result] = await db.query(processedSql, formattedParams);

    if (is_insert || trimmed.startsWith('INSERT')) {
      const insertId = result && typeof result.insertId !== 'undefined' ? result.insertId : 0;
      return res.json({ success: true, insertId, affectedRows: result?.affectedRows || 0 });
    }

    if (trimmed.startsWith('UPDATE') || trimmed.startsWith('DELETE')) {
      return res.json({ success: true, affectedRows: result?.affectedRows || 0 });
    }

    // Default: SELECT or SHOW
    res.json({ success: true, data: result || [] });
  } catch (err) {
    console.error('[sync:query]', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;

