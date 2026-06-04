@echo off
setlocal EnableExtensions
cd /d "%~dp0"

if not exist "venv\Scripts\python.exe" (
    echo [ERROR] No existe venv local.
    echo Ejecuta primero setup_windows_portable.bat
    exit /b 1
)

if not exist "app_server.py" (
    echo [ERROR] app_server.py no encontrado en esta carpeta.
    exit /b 1
)

echo Iniciando BAG App Server en http://localhost:8643 ...
call "venv\Scripts\python.exe" app_server.py --port 8643 --verbose

