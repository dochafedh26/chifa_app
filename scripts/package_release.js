const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const projectRoot = path.resolve(__dirname, '..');
const releaseDir = path.join(projectRoot, 'build', 'windows', 'x64', 'runner', 'Release');
const distDir = path.join(projectRoot, 'dist');
const portableDir = path.join(distDir, 'Chifa-Windows-v1.0.0');

console.log('[1/4] Preparing dist directories...');
if (!fs.existsSync(distDir)) {
  fs.mkdirSync(distDir, { recursive: true });
}
if (fs.existsSync(portableDir)) {
  fs.rmSync(portableDir, { recursive: true, force: true });
}
fs.mkdirSync(portableDir, { recursive: true });

console.log('[2/4] Copying release files to portable distribution folder...');
function copyRecursive(src, dest) {
  const stat = fs.statSync(src);
  if (stat.isDirectory()) {
    if (!fs.existsSync(dest)) fs.mkdirSync(dest, { recursive: true });
    for (const item of fs.readdirSync(src)) {
      copyRecursive(path.join(src, item), path.join(dest, item));
    }
  } else {
    fs.copyFileSync(src, dest);
  }
}
copyRecursive(releaseDir, portableDir);

const sevenZipExe = 'C:\\Program Files\\7-Zip\\7z.exe';
const sevenZipSfx = 'C:\\Program Files\\7-Zip\\7z.sfx';
const temp7zArchive = path.join(distDir, 'payload.7z');
const setupExe = path.join(distDir, 'Chifa-Setup-v1.0.0.exe');
const portableZip = path.join(distDir, 'Chifa-Windows-v1.0.0-Portable.zip');
const sfxConfigPath = path.join(distDir, 'sfx_config.txt');

if (fs.existsSync(temp7zArchive)) fs.unlinkSync(temp7zArchive);
if (fs.existsSync(setupExe)) fs.unlinkSync(setupExe);
if (fs.existsSync(portableZip)) fs.unlinkSync(portableZip);

console.log('[3/4] Creating single-file installer (Chifa-Setup-v1.0.0.exe)...');
// Create 7z archive of the release folder
execSync(`"${sevenZipExe}" a -t7z -mx=9 "${temp7zArchive}" "${portableDir}\\*"`, { stdio: 'inherit' });

// Create SFX config
const sfxConfig = `;!@Install@!UTF-8!
Title="Clinique Chifa - Installation du Logiciel"
BeginPrompt="Voulez-vous installer et lancer Clinique Chifa ?"
RunProgram="chifa.exe"
;!@InstallEnd@!
`;
fs.writeFileSync(sfxConfigPath, sfxConfig, 'utf8');

// Combine: 7z.sfx + config + payload.7z => Chifa-Setup-v1.0.0.exe
execSync(`cmd.exe /c copy /b "${sevenZipSfx}" + "${sfxConfigPath}" + "${temp7zArchive}" "${setupExe}"`, { stdio: 'inherit' });

console.log('[4/4] Creating ZIP package (Chifa-Windows-v1.0.0-Portable.zip)...');
execSync(`"${sevenZipExe}" a -tzip -mx=7 "${portableZip}" "${portableDir}"`, { stdio: 'inherit' });

// Clean up temporary files
if (fs.existsSync(temp7zArchive)) fs.unlinkSync(temp7zArchive);
if (fs.existsSync(sfxConfigPath)) fs.unlinkSync(sfxConfigPath);

const setupSize = (fs.statSync(setupExe).size / (1024 * 1024)).toFixed(2);
const zipSize = (fs.statSync(portableZip).size / (1024 * 1024)).toFixed(2);

console.log('\n======================================================');
console.log('🎉 BUILD SUCCESSFUL! Redistribution packages ready:');
console.log(`1. Installer EXE : ${setupExe} (${setupSize} MB)`);
console.log(`2. Portable ZIP  : ${portableZip} (${zipSize} MB)`);
console.log(`3. Folder Binaries: ${portableDir}`);
console.log('======================================================\n');

