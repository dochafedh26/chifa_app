const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const backendDir = path.resolve(__dirname, '..');
const zipPath = path.join(backendDir, 'chifa-backend-octenium.zip');

if (fs.existsSync(zipPath)) {
  fs.unlinkSync(zipPath);
}

// Ensure portal and TV are bundled
try {
  require('./bundle_portal');
} catch (e) {
  console.log('Bundle note:', e.message);
}

const psScript = `
$source = '${backendDir.replace(/\\/g, '\\\\')}';
$dest = '${zipPath.replace(/\\/g, '\\\\')}';
Get-ChildItem -Force -Path $source -Exclude 'node_modules','*.zip' | Compress-Archive -DestinationPath $dest -Force;
`;

const os = require('os');
const tempPs = path.join(os.tmpdir(), 'chifa_temp_zip.ps1');
fs.writeFileSync(tempPs, psScript, 'utf8');

try {
  execSync(`powershell -ExecutionPolicy Bypass -File "${tempPs}"`, { stdio: 'inherit' });
  console.log('Successfully created:', zipPath, 'Size:', fs.statSync(zipPath).size, 'bytes');
} finally {
  if (fs.existsSync(tempPs)) fs.unlinkSync(tempPs);
}

