@echo off
REM ==========================================
REM BMB Encover Agent — Build para Windows
REM ==========================================
echo.
echo === BMB Encover Agent — Windows Build ===
echo.

REM Verificar Python
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python no encontrado. Instale Python 3.11+ desde python.org
    pause
    exit /b 1
)

REM Verificar PyInstaller
pip show pyinstaller >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Instalando PyInstaller...
    pip install pyinstaller
)

REM Instalar dependencias
echo [INFO] Instalando dependencias...
pip install -e . --no-deps
pip install -e .[pty,cli,mcp,cron,acp]

REM Build
echo [INFO] Compilando BMB Encover Agent...
pyinstaller --clean bmb-encover.spec

if %errorlevel% equ 0 (
    echo.
    echo ==========================================
    echo ✅ BUILD EXITOSO!
    echo.
    echo El ejecutable esta en: dist\bmb.exe
    echo.
    echo Para usarlo:
    echo   1. Agregue dist\ al PATH de Windows
    echo   2. O copie bmb.exe a C:\Windows\System32\
    echo   3. Ejecute: bmb --version
    echo ==========================================
) else (
    echo.
    echo [ERROR] El build fallo. Revise los errores arriba.
)

pause
