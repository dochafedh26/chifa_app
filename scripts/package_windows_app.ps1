# Set strict error handling
$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path "$PSScriptRoot\.."
$buildDir = "$projectRoot\build\windows\x64\runner\Release"
$deploymentDir = "$projectRoot\deployment"
$winDeployDir = "$deploymentDir\windows\Chifa"
$zipPath = "$deploymentDir\Chifa_Windows_x64.zip"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Chifa Windows Package & Installer Builder" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Check / Build Flutter Windows Release
if (-not (Test-Path "$buildDir\chifa.exe")) {
    Write-Host "Building Flutter Windows Release application..." -ForegroundColor Green
    Push-Location $projectRoot
    try {
        flutter build windows --release
    } catch {
        Write-Error "Flutter Windows build failed!"
        Pop-Location
        exit 1
    }
    Pop-Location
} else {
    Write-Host "Release binary found at $buildDir\chifa.exe" -ForegroundColor Green
}

# 2. Check if build directory exists
if (-not (Test-Path $buildDir)) {
    Write-Error "Build directory does not exist: $buildDir"
    exit 1
}

# 3. Clean and prepare packaging directory
Write-Host "Preparing deployment package directories..." -ForegroundColor Green
if (Test-Path $winDeployDir) {
    Remove-Item -Path $winDeployDir -Recurse -Force
}
if (Test-Path $zipPath) {
    Remove-Item -Path $zipPath -Force
}
New-Item -ItemType Directory -Force -Path $winDeployDir | Out-Null
New-Item -ItemType Directory -Force -Path $deploymentDir | Out-Null

# 4. Copy Release files to package folder
Write-Host "Copying application binaries, DLLs, and assets..." -ForegroundColor Green
Copy-Item -Path "$buildDir\*" -Destination $winDeployDir -Recurse -Force

# 4.0 Copy root assets folder for dual compatibility (rootBundle + disk files)
if (Test-Path "$projectRoot\assets") {
    Copy-Item -Path "$projectRoot\assets" -Destination "$winDeployDir\assets" -Recurse -Force
}

# 4.1 Bundle Microsoft Visual C++ Runtime DLLs
Write-Host "Bundling Microsoft Visual C++ CRT DLLs (msvcp140, vcruntime140)..." -ForegroundColor Green
$vcDlls = @(
    "$env:SystemRoot\System32\msvcp140.dll",
    "$env:SystemRoot\System32\vcruntime140.dll",
    "$env:SystemRoot\System32\vcruntime140_1.dll"
)
foreach ($dll in $vcDlls) {
    if (Test-Path $dll) {
        Copy-Item -Path $dll -Destination $winDeployDir -Force
    }
}

# 4.2 Create a 1-click Desktop Shortcut script inside the package
$shortcutScript = @"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "`$ws = New-Object -ComObject WScript.Shell; `$s = `$ws.CreateShortcut([Environment]::GetFolderPath('Desktop') + '\Chifa.lnk'); `$s.TargetPath = '%~dp0chifa.exe'; `$s.WorkingDirectory = '%~dp0'; `$s.IconLocation = '%~dp0chifa.exe,0'; `$s.Description = 'Clinique Chifa Management System'; `$s.Save()"
echo.
echo =========================================================
echo  Raccourci Clinique Chifa cree sur votre Bureau avec succes !
echo =========================================================
echo.
timeout /t 3 >nul
"@
[System.IO.File]::WriteAllText("$winDeployDir\Creer_Raccourci_Bureau.bat", $shortcutScript)

# 5. Generate User README Instructions
Write-Host "Creating deployment README.txt..." -ForegroundColor Green
$readmeContent = @"
========================================================================
 Clinique Chifa - Windows Desktop Application (Redistributable Package)
 Version: 1.1.0 (Production Ready)
========================================================================

SYSTEM REQUIREMENTS:
--------------------
- OS: Windows 10 / 11 (64-bit)
- Network: Internet connection for Cloud synchronization & activation
- Dependencies: Included in this package (no installation required)

INSTALLATION & EXECUTION:
--------------------------
1. Double-click "Chifa_Setup_v1.1.0.exe" to install the app automatically
   with Desktop and Start Menu shortcuts.
   OR:
   Extract the ZIP package into any folder (e.g. C:\Chifa) and run "chifa.exe".

2. First Launch Activation:
   Enter your clinic master key: CHIFA-CLINIC-2026-HQ
   Click "Activer ce terminal" to bind your device to the clinic cloud.

SERVERS & PORTAL:
-----------------
- Cloud API: https://medevsync.com/chifa
- Patient Web Portal: https://medevsync.com/chifa/portal

Support & Documentation: https://medevsync.com/chifa
"@
[System.IO.File]::WriteAllText("$winDeployDir\README.txt", $readmeContent)

# 6. Compress package into a redistributable ZIP file
Write-Host "Compressing redistributable ZIP package..." -ForegroundColor Green
Push-Location "$deploymentDir\windows"
try {
    Compress-Archive -Path "Chifa" -DestinationPath $zipPath -Force
} catch {
    tar.exe -a -c -f $zipPath -C "$deploymentDir\windows" Chifa
}
Pop-Location

# 7. Inno Setup Compiler execution
$innoCandidates = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\iscc.exe",
    "$env:ProgramFiles\Inno Setup 6\iscc.exe",
    (Get-Command iscc.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
)
$innoExe = $innoCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if ($innoExe) {
    Write-Host "Inno Setup Compiler found: $innoExe" -ForegroundColor Green
    Write-Host "Compiling professional installer Chifa_Setup_v1.0.0.exe..." -ForegroundColor Green
    & "$innoExe" "$projectRoot\scripts\chifa_installer.iss"
} else {
    Write-Host "Note: Inno Setup (iscc.exe) not detected. (Only ZIP package was created)." -ForegroundColor Yellow
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "SUCCESS! Chifa Windows app packaged cleanly." -ForegroundColor Green
Write-Host "Redistributable package location:" -ForegroundColor Yellow
Write-Host " -> $deploymentDir" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor Cyan

