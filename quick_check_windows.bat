@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "PASS=0"
set "FAIL=0"

echo =========================================
echo   BAG - Quick Check (Windows)
echo =========================================
echo.

if not exist "venv\Scripts\python.exe" (
    echo [FAIL] venv local no encontrado. Ejecuta setup_windows_portable.bat
    set /a FAIL+=1
    goto :check_health
) else (
    echo [OK] venv local encontrado
    set /a PASS+=1
)

if not exist "%USERPROFILE%\.bmb\.env" (
    echo [FAIL] No existe %%USERPROFILE%%\.bmb\.env
    set /a FAIL+=1
) else (
    findstr /r /c:"^DEEPSEEK_API_KEY=.+" "%USERPROFILE%\.bmb\.env" >nul 2>&1
    if %errorlevel% neq 0 (
        echo [WARN] DEEPSEEK_API_KEY vacia o no definida en .env
    ) else (
        echo [OK] DEEPSEEK_API_KEY definida en .env
        set /a PASS+=1
    )
)

echo.
echo [INFO] Verificando imports Python...
call "venv\Scripts\python.exe" -c "import importlib.util as u;mods=['aiohttp','qrcode','PIL','edge_tts'];missing=[m for m in mods if u.find_spec(m) is None];print('MISSING:'+(','.join(missing) if missing else 'NONE'))" > "%TEMP%\bmb_imports_check.txt"
for /f "tokens=1,* delims=:" %%A in (%TEMP%\bmb_imports_check.txt) do (
    if /i "%%A"=="MISSING" (
        if /i "%%B"=="NONE" (
            echo [OK] Dependencias clave presentes
            set /a PASS+=1
        ) else (
            echo [FAIL] Faltan modulos: %%B
            set /a FAIL+=1
        )
    )
)

:check_health
echo.
echo [INFO] Verificando servidor en http://localhost:8643/health ...
curl.exe -s http://localhost:8643/health > "%TEMP%\bmb_health.json"
if %errorlevel% neq 0 (
    echo [FAIL] App Server no responde en localhost:8643
    echo        Inicia con start_windows_portable.bat
    set /a FAIL+=1
    goto :summary
)

findstr /i "\"status\"" "%TEMP%\bmb_health.json" >nul 2>&1
if %errorlevel% neq 0 (
    echo [FAIL] Respuesta health invalida
    set /a FAIL+=1
) else (
    echo [OK] Health endpoint responde
    set /a PASS+=1
)

echo.
echo [INFO] Probando endpoint QR (pair token PNG)...
curl.exe -s "http://localhost:8643/api/pair/token?format=png" -o "%TEMP%\bmb_qr_test.png"
if %errorlevel% neq 0 (
    echo [FAIL] Error consultando endpoint QR
    set /a FAIL+=1
    goto :summary
)

if not exist "%TEMP%\bmb_qr_test.png" (
    echo [FAIL] No se genero archivo PNG de QR
    set /a FAIL+=1
) else (
    for %%F in ("%TEMP%\bmb_qr_test.png") do set "QR_SIZE=%%~zF"
    if "%QR_SIZE%"=="0" (
        echo [FAIL] QR generado vacio
        set /a FAIL+=1
    ) else (
        echo [OK] QR endpoint funciona
        set /a PASS+=1
    )
)

:summary
echo.
echo =========================================
echo RESULTADO: PASS=%PASS%  FAIL=%FAIL%
echo =========================================

if %FAIL% gtr 0 (
    echo Quick check terminado con errores.
    exit /b 1
)

echo Quick check completado sin errores.
exit /b 0

