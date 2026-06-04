@echo off
REM ==========================================
REM BAG â€” Script de inicio rÃ¡pido
REM Para Windows (PowerShell recomendado)
REM ==========================================
setlocal EnableExtensions
for %%I in ("%~dp0..") do set "BMB_DIR=%%~fI"
set "APP_DIR=%~dp0"

set "PYTHON_EXE=%BMB_DIR%\venv\Scripts\python.exe"
if not exist "%PYTHON_EXE%" set "PYTHON_EXE=python"

echo.
echo === BAG Agent â€” Inicio rapido ===
echo [INFO] Repo: %BMB_DIR%
echo.

:menu
echo.
echo 1. Iniciar servidor BAG + App Server
echo 2. Iniciar solo App Server (si BAG ya esta corriendo)
echo 3. Compilar app Flutter
echo 4. Ver estado
echo 5. Salir
echo.
set /p opcion="Seleccione (1-5): "

if "%opcion%"=="1" goto full
if "%opcion%"=="2" goto server
if "%opcion%"=="3" goto flutter
if "%opcion%"=="4" goto status
if "%opcion%"=="5" exit /b
goto menu

:full
echo.
echo [INFO] Iniciando servidor BAG + App Server...
echo.
start "BAG App Server" cmd /c "cd /d %BMB_DIR% && \"%PYTHON_EXE%\" app_server.py --port 8643"
echo [OK] App Server corriendo en http://localhost:8643
echo.
echo Dispositivos vinculados:
curl -s http://localhost:8643/api/sessions
echo.
echo Para generar QR de pairing, ejecute:
echo   python -c "from app_server import AppServer; import json; print(json.dumps(AppServer.generate_pairing_token()))"
echo.
pause
goto menu

:server
echo.
echo [INFO] Iniciando solo App Server...
start "BAG App Server" cmd /c "cd /d %BMB_DIR% && \"%PYTHON_EXE%\" app_server.py --port 8643"
echo [OK] App Server en http://localhost:8643
pause
goto menu

:flutter
echo.
echo [INFO] Compilando app Flutter...
echo.
cd /d "%APP_DIR%"
call flutter pub get
if %errorlevel% neq 0 (
    echo [ERROR] flutter pub get fallo. Tiene Flutter instalado?
    pause
    goto menu
)
echo.
echo Elegi plataforma:
echo 1. Windows (escritorio)
echo 2. Android (APK)
echo 3. iOS (solo Mac)
echo.
set /p plat="Plataforma (1-3): "

if "%plat%"=="1" (
    flutter build windows
    echo [OK] Ejecutable en: build\windows\runner\Release\bmb_app.exe
)
if "%plat%"=="2" (
    flutter build apk
    echo [OK] APK en: build\app\outputs\flutter-apk\app-release.apk
)
if "%plat%"=="3" (
    flutter build ios
    echo [OK] Archivo IPA generado
)
pause
goto menu

:status
echo.
echo === Estado del servidor ===
curl -s http://localhost:8643/health 2>nul
if %errorlevel% neq 0 (
    echo [OFFLINE] App Server no responde en puerto 8643
)
echo.
pause
goto menu

