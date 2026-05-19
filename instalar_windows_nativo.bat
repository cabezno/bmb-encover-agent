@echo off
title BMB ENCOVER - INSTALADOR NATIVO WINDOWS
cd /d "%~dp0"
color 0D

echo =========================================
echo   BMB ENCOVER AGENT v0.5.0
echo   Instalador Nativo Windows
echo =========================================
echo.
echo Esto instala TODO en tu PC Windows:
echo   - Python (si falta)
echo   - Servidor BMB
echo   - Whisper STT (transcripcion de voz)
echo   - Edge TTS (voz Elena Argentina)
echo   - Cloudflare Tunnel (acceso remoto)
echo   - QR para app Android
echo   - Dependencias completas
echo.
echo Cerra el watchdog si lo tenes abierto.
echo.
pause

REM === 1. VERIFICAR CARPETA ===
if not exist "%~dp0app_server.py" (
    echo ERROR: Este .bat debe estar en la misma carpeta que app_server.py
    pause
    exit /b 1
)
set BMB_DIR=%~dp0

REM === 2. PYTHON ===
echo.
echo [1/6] Verificando Python...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo    Descargando Python 3.11...
    curl.exe -sL -o python-installer.exe https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe
    start /wait python-installer.exe /quiet InstallAllUsers=1 PrependPath=1
    del python-installer.exe
    echo    ✅ Python instalado
) else (
    for /f "tokens=*" %%v in ('python --version') do echo    %%v
)

REM === 3. PIP ===
echo.
echo [2/6] Instalando dependencias...
python -m pip install --upgrade pip -q
python -m pip install aiohttp edge-tts faster-whisper soundfile numpy qrcode[pil] -q
if %errorlevel% equ 0 (
    echo    ✅ Dependencias instaladas
) else (
    echo    ⚠️  Error instalando dependencias
    pause
)

REM === 4. CONFIG ===
echo.
echo [3/6] Configurando...
if not exist "%USERPROFILE%\.bmb" mkdir "%USERPROFILE%\.bmb"
(
echo # BMB Encover - Configuracion
echo DEEPSEEK_API_KEY=sk-bce5166e987d41a4b22d8f4180642f35
echo BMB_ACCESS_TOKEN=bmb2026
echo BMB_TTS_VOICE=es-AR-ElenaNeural
echo BMB_WHISPER_MODEL=tiny
) > "%USERPROFILE%\.bmb\.env"
echo    ✅ Config creada en %%USERPROFILE%%\.bmb\.env

REM === 5. CLOUDFLARE ===
echo.
echo [4/6] Cloudflare Tunnel...
if not exist cloudflared.exe (
    echo    Descargando cloudflared...
    curl.exe -sL -o cloudflared.exe "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
)
if exist cloudflared.exe (
    echo    ✅ cloudflared.exe listo
) else (
    echo    ⚠️  No se pudo descargar cloudflared
)

REM === 6. INICIAR SERVER ===
echo.
echo [5/6] Iniciando servidor BMB...
taskkill /f /im python.exe >nul 2>&1
timeout /t 2 /nobreak >nul

echo    Iniciando servidor en localhost:8643...
start "BMB Server" cmd /c "cd /d %BMB_DIR% && python app_server.py --port 8643 --verbose"
timeout /t 5 /nobreak >nul

REM === 7. TUNNEL ===
echo.
echo [6/6] Conectando Cloudflare Tunnel...
if exist cloudflared.exe (
    start "BMB Tunnel" cmd /c "cd /d %BMB_DIR% && cloudflared.exe tunnel --url http://localhost:8643 --log-level info"
    echo    Tunnel iniciado
    echo.
    echo    Busca la URL https://xxxx.trycloudflare.com en la ventana BMB Tunnel
    echo    Esa URL la usas en la app Android como servidor
)

REM === QR TOKEN ===
echo.
echo =========================================
echo   INSTALACION COMPLETADA!
echo =========================================
echo.
echo   LOCAL:  http://localhost:8643
echo   TOKEN:  bmb2026
echo.
echo   ENDPOINTS:
echo     Chat:   POST /api/chat
echo     Imagen: POST /api/image  (Android envia foto)
echo     Audio:  POST /api/audio  (Android graba voz)
echo     TTS:    GET  /api/tts?text=...  (texto a voz)
echo     Llamada:POST /api/call/start
echo              POST /api/call/audio
echo     QR:     GET  /api/pair/token?format=png
echo.
echo   Para Android, usa la URL del tunnel + token bmb2026
echo.
echo   Presiona cualquier tecla para generar QR...
pause >nul

REM === GENERAR QR ===
echo.
echo Generando QR de emparejamiento...
curl.exe -s "http://localhost:8643/api/pair/token?format=png" -o qr_emparejar.png
if exist qr_emparejar.png (
    echo    ✅ QR guardado en: %BMB_DIR%qr_emparejar.png
    start qr_emparejar.png
) else (
    echo    ⚠️  No se pudo generar QR. El servidor no responde?
)

echo.
echo LISTO. Todo funcionando nativo en Windows.
echo Cerra esta ventana solo si queres apagar todo.
pause
