require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const helmet = require('helmet');

if (!process.env.JWT_SECRET) {
  console.warn('[SECURITY WARNING] JWT_SECRET is not set! Using development fallback.');
  process.env.JWT_SECRET = 'chifa_clinic_cloud_jwt_secret_2026_dev_key';
}

const activationRoutes = require('./routes/activation');
const authRoutes = require('./routes/auth');
const syncRoutes = require('./routes/sync');
const portalRoutes = require('./routes/portal');
const notificationRoutes = require('./routes/notifications');
const tvRoutes = require('./routes/tv');
const db = require('./db');

// Auto-migrate Octenium MySQL schema on startup so clients never need to run heavy DDL over HTTP
(async function runStartupMigrations() {
  try {
    await db.query('ALTER TABLE `appointments` MODIFY COLUMN `status` VARCHAR(50) DEFAULT "Scheduled"').catch(() => {});
    await db.query(`
      CREATE TABLE IF NOT EXISTS \`sync_status\` (
        \`table_name\` varchar(50) NOT NULL,
        \`last_push_at\` timestamp NOT NULL DEFAULT '1970-01-01 00:00:00',
        \`last_pull_at\` timestamp NOT NULL DEFAULT '1970-01-01 00:00:00',
        PRIMARY KEY (\`table_name\`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    `).catch(() => {});
    await db.query(`
      CREATE TABLE IF NOT EXISTS \`hospitalizations\` (
        \`id\` int(11) NOT NULL AUTO_INCREMENT,
        \`patient_id\` int(11) NOT NULL,
        \`admission_date\` datetime NOT NULL,
        \`discharge_date\` datetime DEFAULT NULL,
        \`diagnosis\` text DEFAULT NULL,
        \`room_number\` varchar(50) DEFAULT NULL,
        \`status\` enum('active','discharged','transferred') DEFAULT 'active',
        \`uuid\` varchar(36) DEFAULT NULL,
        \`updated_at\` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        \`is_deleted\` tinyint(1) DEFAULT 0,
        \`needs_sync\` tinyint(1) DEFAULT 0,
        PRIMARY KEY (\`id\`),
        UNIQUE KEY \`idx_hosp_uuid\` (\`uuid\`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `).catch(() => {});
    await db.query(`
      CREATE TABLE IF NOT EXISTS \`patients_fideles\` (
        \`id\` int(11) NOT NULL AUTO_INCREMENT,
        \`patient_id\` int(11) NOT NULL,
        \`medical_records_count\` int(11) NOT NULL DEFAULT 0,
        \`created_at\` timestamp NOT NULL DEFAULT current_timestamp(),
        \`updated_at\` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
        PRIMARY KEY (\`id\`),
        UNIQUE KEY \`patient_id\` (\`patient_id\`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `).catch(() => {});
    await db.query(`
      CREATE TABLE IF NOT EXISTS \`patients_suivi\` (
        \`id\` int(11) NOT NULL AUTO_INCREMENT,
        \`patient_id\` int(11) NOT NULL,
        \`doctor_id\` int(11) DEFAULT 1,
        \`pathologies\` text DEFAULT NULL,
        \`created_at\` timestamp NOT NULL DEFAULT current_timestamp(),
        \`updated_at\` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
        PRIMARY KEY (\`id\`),
        UNIQUE KEY \`patient_id\` (\`patient_id\`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `).catch(() => {});
    await db.query(`
      CREATE TABLE IF NOT EXISTS \`patient_suivi_categories\` (
        \`id\` int(11) NOT NULL AUTO_INCREMENT,
        \`patient_id\` int(11) NOT NULL,
        \`category\` varchar(100) NOT NULL,
        PRIMARY KEY (\`id\`),
        KEY \`idx_psc_patient\` (\`patient_id\`),
        KEY \`idx_psc_category\` (\`category\`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    `).catch(() => {});

    // Ensure modern_prescriptions.id has AUTO_INCREMENT
    const [mpCols] = await db.query(
      "SELECT EXTRA FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'modern_prescriptions' AND column_name = 'id'"
    ).catch(() => [[]]);
    if (mpCols && mpCols.length > 0 && !String(mpCols[0].EXTRA || mpCols[0].extra || '').toLowerCase().includes('auto_increment')) {
      await db.query('ALTER TABLE `modern_prescriptions` MODIFY `id` int(11) NOT NULL AUTO_INCREMENT').catch(() => {});
    }

    console.log('[Chifa Backend] Startup schema checks completed.');
  } catch (err) {
    console.warn('[Chifa Backend] Startup schema check notice:', err.message);
  }
})();

const app = express();

// ─── SECURITY & CORS ──────────────────────────────────────────────────────────
app.use(
  helmet({
    contentSecurityPolicy: false, // Allow inline scripts/styles for patient portal SPA
    crossOriginResourcePolicy: { policy: 'cross-origin' },
  })
);

const allowedOrigins = (process.env.ALLOWED_ORIGINS || process.env.ALLOWED_ORIGIN || '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

app.use(
  cors({
    origin: true,
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Sync-Key'],
    exposedHeaders: ['X-Chifa-Backend'],
  })
);
app.options('*', cors());

// Identify every response as originating from Chifa Node.js Backend
app.use((req, res, next) => {
  res.setHeader('X-Chifa-Backend', '1');
  next();
});

// ─── TRUST PROXY (for cPanel / Passenger / Nginx) ───────────────────────────
app.enable('trust proxy');

// ─── BODY PARSING ─────────────────────────────────────────────────────────────
app.use(express.json({ limit: '30mb' }));
app.use(express.urlencoded({ extended: true, limit: '30mb' }));

// ─── STATIC FLUTTER WEB APP (Chifa Complete Clinic Application) ───────────────
const appStaticDir = path.join(__dirname, 'public', 'app');
if (!fs.existsSync(appStaticDir)) {
  fs.mkdirSync(appStaticDir, { recursive: true });
}

// Serve Flutter Web static assets with correct MIME types and headers
const setAppStaticHeaders = (res, filePath) => {
  if (filePath.endsWith('.wasm')) {
    res.setHeader('Content-Type', 'application/wasm');
  } else if (filePath.endsWith('.js')) {
    res.setHeader('Content-Type', 'application/javascript');
  } else if (filePath.endsWith('.json')) {
    res.setHeader('Content-Type', 'application/json');
  } else if (filePath.endsWith('.ttf')) {
    res.setHeader('Content-Type', 'font/ttf');
  } else if (filePath.endsWith('.otf')) {
    res.setHeader('Content-Type', 'font/otf');
  } else if (filePath.endsWith('.woff')) {
    res.setHeader('Content-Type', 'font/woff');
  } else if (filePath.endsWith('.woff2')) {
    res.setHeader('Content-Type', 'font/woff2');
  }
  res.setHeader('Access-Control-Allow-Origin', '*');
};

app.use('/chifa/app', express.static(appStaticDir, { setHeaders: setAppStaticHeaders }));
app.use('/app', express.static(appStaticDir, { setHeaders: setAppStaticHeaders }));

// Respond with 200 to any legacy or cached .env asset requests so it never yields 403
app.get([
  '/chifa/app/assets/.env',
  '/app/assets/.env',
  '*/assets/.env'
], (req, res) => {
  res.type('text/plain').send('# Web env placeholder\n');
});

// Fallback index.html for client-side GoRouter navigation
app.get([
  '/chifa/app',
  '/chifa/app/',
  '/chifa/app/*',
  '/app',
  '/app/',
  '/app/*'
], (req, res, next) => {
  // Never serve index.html for files with extensions (fonts, scripts, images, etc.)
  if (path.extname(req.path)) {
    return next();
  }
  const filePath = path.join(appStaticDir, 'index.html');
  if (fs.existsSync(filePath)) {
    res.setHeader('Content-Type', 'text/html');
    res.sendFile(filePath);
  } else {
    res.status(404).send('Application Chifa Web non encore déployée.');
  }
});

// ─── STATIC WEB PORTAL ────────────────────────────────────────────────────────
// Patient portal available at /chifa, /chifa/portal, /portal and /
const portalStaticDir = path.join(__dirname, 'public', 'portal');

// Explicit asset handlers to guarantee correct MIME types under Passenger
app.get(['/style.css', '/portal/style.css', '/chifa/style.css', '/chifa/portal/style.css'], (req, res) => {
  res.type('text/css');
  res.sendFile(path.join(portalStaticDir, 'style.css'));
});

app.get(['/app.js', '/portal/app.js', '/chifa/app.js', '/chifa/portal/app.js'], (req, res) => {
  res.type('application/javascript');
  res.sendFile(path.join(portalStaticDir, 'app.js'));
});

// Serve static assets from all mount points
app.use(express.static(portalStaticDir));
app.use('/portal', express.static(portalStaticDir));
app.use('/chifa', express.static(portalStaticDir));
app.use('/chifa/portal', express.static(portalStaticDir));

// ─── QUERY ROUTER & PASSENGER DIRECT POST FALLBACKS ─────────────────────────
// Handles environments where Apache parent .htaccess catches sub-paths
app.use((req, res, next) => {
  if (req.query && req.query.route) {
    const target = req.query.route.startsWith('/') ? req.query.route : `/${req.query.route}`;
    req.url = `/chifa/api${target}`;
  }
  next();
});

// Direct POST to / or /chifa or /chifa/ (auto-detects sync query, sync push, activation, or portal login)
app.post(['/', '/chifa', '/chifa/'], (req, res, next) => {
  if (req.body && typeof req.body.sql === 'string') {
    req.url = '/query';
    return syncRoutes(req, res, next);
  }
  if (req.body && req.body.changes && typeof req.body.changes === 'object') {
    req.url = '/push';
    return syncRoutes(req, res, next);
  }
  if (req.body && (req.body.key || req.body.activation_key || req.query.action === 'verify')) {
    req.url = '/verify';
    return activationRoutes(req, res, next);
  }
  if (req.body && (req.body.phone || req.body.cin) && req.body.pin) {
    req.url = '/login';
    return portalRoutes(req, res, next);
  }
  next();
});

// Serve index.html for root, /chifa, /chifa/, /portal, /portal/, and /chifa/portal
app.get([
  '/', 
  '/chifa', 
  '/chifa/', 
  '/portal', 
  '/portal/', 
  '/portal/index.html',
  '/chifa/portal',
  '/chifa/portal/',
  '/chifa/portal/index.html'
], (req, res, next) => {
  if (req.query && req.query.route) {
    return next();
  }
  res.sendFile(path.join(portalStaticDir, 'index.html'));
});

// ─── STATIC SMART TV DISPLAY ──────────────────────────────────────────────────
const tvStaticDir = path.join(__dirname, 'public', 'tv');
app.use('/tv', express.static(tvStaticDir));
app.use('/chifa/tv', express.static(tvStaticDir));
app.get([
  '/tv',
  '/tv/',
  '/tv/index.html',
  '/chifa/tv',
  '/chifa/tv/',
  '/chifa/tv/index.html'
], (req, res) => {
  res.sendFile(path.join(tvStaticDir, 'index.html'));
});

// ─── STATIC WEBCAM / SMARTPHONE SCANNER ───────────────────────────────────────
const scannerStaticDir = path.join(__dirname, 'public', 'scanner');
app.use('/scanner', express.static(scannerStaticDir));
app.use('/chifa/scanner', express.static(scannerStaticDir));
app.get([
  '/scanner',
  '/scanner/',
  '/scanner/index.html',
  '/chifa/scanner',
  '/chifa/scanner/',
  '/chifa/scanner/index.html'
], (req, res) => {
  res.sendFile(path.join(scannerStaticDir, 'index.html'));
});


// ─── API ROUTES ───────────────────────────────────────────────────────────────
// Support /chifa/api, /api, /chifa, and /portal/api prefixes
const registerApiRoutes = (prefix) => {
  app.use(`${prefix}/activation`, activationRoutes);
  app.use(`${prefix}/auth`, authRoutes);
  app.use(`${prefix}/sync`, syncRoutes);
  app.use(`${prefix}/portal`, portalRoutes);
  app.use(`${prefix}/notifications`, notificationRoutes);
  app.use(`${prefix}/tv`, tvRoutes);
};

registerApiRoutes('/chifa/api');
registerApiRoutes('/api');
registerApiRoutes('/chifa');
registerApiRoutes('/portal/api');

// ─── HEALTH CHECKS ────────────────────────────────────────────────────────────
const healthHandler = (req, res) => res.json({ status: 'ok', service: 'chifa-backend', time: new Date() });
app.get('/health', healthHandler);
app.get('/api/health', healthHandler);
app.get('/chifa/health', healthHandler);
app.get('/chifa/api/health', healthHandler);

// ─── GLOBAL ERROR HANDLER ─────────────────────────────────────────────────────
app.use((err, req, res, _next) => {
  console.error('[server:error]', err);
  res.status(500).json({ error: err.message || 'Erreur interne du serveur' });
});

// Graceful process error handlers for Phusion Passenger
process.on('uncaughtException', (err) => {
  console.error('[server] Uncaught Exception:', err);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('[server] Unhandled Rejection at:', promise, 'reason:', reason);
});

// ─── PASSENGER PORT BINDING ───────────────────────────────────────────────────
let PORT = process.env.PORT || 3000;
if (PORT === 'passenger') {
  PORT = 3000;
}

const server = app.listen(PORT, () => {
  console.log(`[Chifa Backend] Server running on port ${PORT}`);
});

server.on('error', (err) => {
  console.error('[server] HTTP Listen Error:', err);
});

module.exports = app;

