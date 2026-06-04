@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo =========================================
echo   BMB Encover - Setup Windows Portable
echo =========================================
echo.

where python >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python no encontrado en PATH.
    echo Instala Python 3.11+ y marca "Add Python to PATH".
    exit /b 1
)

if not exist "venv\Scripts\python.exe" (
    echo [1/5] Creando entorno virtual...
    python -m venv venv
    if %errorlevel% neq 0 (
        echo [ERROR] No se pudo crear el venv.
        exit /b 1
    )
) else (
    echo [1/5] venv ya existe.
)

echo [2/5] Actualizando pip...
call "venv\Scripts\python.exe" -m pip install --upgrade pip
if %errorlevel% neq 0 (
    echo [ERROR] Fallo actualizando pip.
    exit /b 1
)

echo [3/5] Instalando paquete base (editable)...
call "venv\Scripts\python.exe" -m pip install -e .[pty,cli,mcp,cron,acp]
if %errorlevel% neq 0 (
    echo [ERROR] Fallo instalando bmb-encover.
    exit /b 1
)

echo [4/5] Instalando extras para App Server (QR/TTS)...
call "venv\Scripts\python.exe" -m pip install "qrcode[pil]" pillow aiohttp edge-tts
if %errorlevel% neq 0 (
    echo [ERROR] Fallo instalando dependencias del App Server.
    exit /b 1
)

echo [5/5] Configuracion local...
if not exist "%USERPROFILE%\.bmb" mkdir "%USERPROFILE%\.bmb"
if not exist "%USERPROFILE%\.bmb\.env" (
    (
        echo # Completa con tu API key real
        echo DEEPSEEK_API_KEY=
        echo BMB_ACCESS_TOKEN=
        echo BMB_TTS_VOICE=es-AR-ElenaNeural
        echo BMB_WHISPER_MODEL=tiny
    ) > "%USERPROFILE%\.bmb\.env"
    echo [OK] Se creo %USERPROFILE%\.bmb\.env
) else (
    echo [OK] Ya existe %USERPROFILE%\.bmb\.env
)

echo.
echo Setup completado.
echo Siguiente paso: ejecutar start_windows_portable.bat
echo.
pause
