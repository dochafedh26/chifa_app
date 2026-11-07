const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

console.log('[Deploy] Preparing Chifa Backend deployment archive for chifa.medevsync.com...');

const targetZip = path.join(__dirname, 'chifa-backend-octenium.zip');
if (fs.existsSync(targetZip)) {
  fs.unlinkSync(targetZip);
}

// 1. Bundle portal and TV assets into self-contained HTML files
try {
  require('./scripts/bundle_portal');
} catch (e) {
  console.warn('[Deploy] Bundle portal note:', e.message);
}

// 2. Ensure uploads/patient_documents exists with .gitkeep
const uploadsDir = path.join(__dirname, 'uploads', 'patient_documents');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}
const gitkeep = path.join(uploadsDir, '.gitkeep');
if (!fs.existsSync(gitkeep)) {
  fs.writeFileSync(gitkeep, '');
}

// 3. Ensure .env exists inside the archive (copied from .env.example if not present)
const envFile = path.join(__dirname, '.env');
const envExample = path.join(__dirname, '.env.example');
let createdTempEnv = false;
if (!fs.existsSync(envFile) && fs.existsSync(envExample)) {
  fs.copyFileSync(envExample, envFile);
  createdTempEnv = true;
}

try {
  if (process.platform === 'win32') {
    execSync(
      `powershell -NoProfile -Command "Get-ChildItem -Force -Path '${__dirname}' -Exclude 'node_modules','*.zip','.git' | Compress-Archive -DestinationPath '${targetZip}' -Force"`,
      { stdio: 'inherit' }
    );
  } else {
    execSync(
      `zip -r "${targetZip}" . -x "node_modules/*" "*.zip" ".git/*"`,
      { cwd: __dirname, stdio: 'inherit' }
    );
  }
  const sizeBytes = fs.statSync(targetZip).size;
  console.log(`[Deploy] Archive created: ${targetZip} (${(sizeBytes / 1024).toFixed(1)} KB)`);
} finally {
  if (createdTempEnv && fs.existsSync(envFile)) {
    fs.unlinkSync(envFile);
  }
}

console.log('\n[Deploy] Ready! To deploy on Octenium cPanel (https://chifa.medevsync.com):');
console.log('1. In cPanel > "Domains", create subdomain: chifa.medevsync.com');
console.log('2. In cPanel > "Setup Node.js App", create/edit the app for Application URL: chifa.medevsync.com and Startup File: server.js');
console.log('3. Upload and extract chifa-backend-octenium.zip into the application root directory.');
console.log('4. Click "Run NPM Install" then "Restart" in cPanel Node.js App Manager.');
console.log('5. Verify health endpoint: https://chifa.medevsync.com/api/health');
