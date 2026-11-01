@echo off
echo ===================================================
echo   CHIFA CLINIQUE - COMPILATION DU FRONT-END WEB
echo ===================================================
echo.

cd /d "%~dp0\.."

echo [1/3] Analyse du code Flutter...
call flutter analyze --no-pub lib/main.dart lib/services/db/database.dart lib/services/db/http_api_service.dart
if %ERRORLEVEL% NEQ 0 (
    echo [ERREUR] Erreurs detectees dans le code Dart.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [2/3] Compilation Flutter Web Release (Base URL: /chifa/app/)...
call flutter build web --release --base-href "/chifa/app/"
if %ERRORLEVEL% NEQ 0 (
    echo [ERREUR] Echec de la compilation Web.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [3/3] Copie du bundle Web dans backend/public/app...
if not exist "backend\public\app" mkdir "backend\public\app"
xcopy /E /Y /I "build\web\*" "backend\public\app\"

echo.
echo ===================================================
echo   SUCCES : APPLICATION WEB PRETE POUR OCTENIUM !
echo ===================================================
echo Les fichiers sont disponibles dans :
echo   - build\web\
echo   - backend\public\app\
echo.
pause

