const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

console.log('[Deploy] Preparing Chifa Backend deployment archive...');

const targetZip = path.join(__dirname, 'chifa-backend-octenium.zip');
if (fs.existsSync(targetZip)) {
  fs.unlinkSync(targetZip);
}

// Ensure uploads/patient_documents exists with .gitkeep
const uploadsDir = path.join(__dirname, 'uploads', 'patient_documents');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}
const gitkeep = path.join(uploadsDir, '.gitkeep');
if (!fs.existsSync(gitkeep)) {
  fs.writeFileSync(gitkeep, '');
}

console.log('[Deploy] Ready! To deploy on Octenium cPanel:');
console.log('1. Upload files from backend/ to your cPanel Node.js application directory.');
console.log('2. In cPanel > "Setup Node.js App", select Node version 18+ or 20+, App Root and Application startup file: server.js');
console.log('3. Click "Run NPM Install".');
console.log('4. Ensure your .env has your MySQL database credentials (DB_NAME, DB_USER, DB_PASSWORD).');
console.log('5. Import scripts/init_db.sql in phpMyAdmin if not already migrated.');
console.log('6. Click "Restart" in cPanel Node.js app manager. Access portal at: https://your-domain.com/portal');

