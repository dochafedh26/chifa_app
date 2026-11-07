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

// Auto-migrate appointments.status to VARCHAR(50) to support waitingRoom
(async () => {
  try {
    await db.query('ALTER TABLE `appointments` MODIFY COLUMN `status` VARCHAR(50)');
    console.log('[Chifa Backend] Ensured appointments.status is VARCHAR(50)');
  } catch (_) {}
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
  })
);
app.options('*', cors());

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
], (req, res) => {
  res.sendFile(path.join(portalStaticDir, 'index.html'));
});

// ─── QUERY ROUTER & PASSENGER DIRECT POST FALLBACKS ─────────────────────────
// Handles environments where Apache parent .htaccess catches sub-paths
app.use((req, res, next) => {
  if (req.query && req.query.route) {
    const target = req.query.route.startsWith('/') ? req.query.route : `/${req.query.route}`;
    req.url = `/chifa/api${target}`;
  }
  next();
});

// Direct POST to / or /chifa or /chifa/ (auto-detects activation vs portal login)
app.post(['/', '/chifa', '/chifa/'], (req, res, next) => {
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

