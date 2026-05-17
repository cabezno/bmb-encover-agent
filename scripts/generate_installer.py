#!/usr/bin/env python3
"""
BMB Encover - Instalador mínimo para GitHub Releases
Genera un script .bat auto-contenido que instala todo.
"""
import os, sys, base64, json
from pathlib import Path

# Contenido del instalador BAT embebido
BAT_CONTENT = r"""@echo off
title BMB Encover - Instalador
cd /d "%~dp0"
echo ==========================================
echo   BMB ENCOVER AGENT - INSTALADOR RAPIDO
echo ==========================================
echo.
echo 1. Verificando Python...
python --version >nul 2>&1 || (
    echo ❌ Python no instalado.
    echo Descarga desde: https://www.python.org/downloads/
    pause
    exit /b
)
echo.
echo 2. Configurando...
if not exist "%%USERPROFILE%%\.bmb" mkdir "%%USERPROFILE%%\.bmb"
echo DEEPSEEK_API_KEY=sk-bce5166e987d41a4b22d8f4180642f35 > "%%USERPROFILE%%\.bmb\.env"
echo BMB_ACCESS_TOKEN=bmb2026 >> "%%USERPROFILE%%\.bmb\.env"
echo    API Key configurada
echo.
echo 3. Iniciando servidor...
taskkill /f /im python.exe >nul 2>&1
timeout /t 2 /nobreak >nul
python app_server.py --port 8643 --verbose
echo.
echo Servidor detenido.
pause
"""

# Escribir el instalador
installer_path = "/mnt/c/Users/Pc Nasa/Desktop/BMB/instalar_rapido.bat"
Path(installer_path).write_text(BAT_CONTENT)
print(f"✅ instalar_rapido.bat creado")
print(f"   Tamaño: {len(BAT_CONTENT)} bytes")
print(f"   Pasos: Python → Config → Iniciar server")

# También crear version simplificada del .env
env_path = "/mnt/c/Users/Pc Nasa/.bmb/.env"
Path(env_path).parent.mkdir(parents=True, exist_ok=True)
env_content = "DEEPSEEK_API_KEY=sk-bce5166e987d41a4b22d8f4180642f35\nBMB_ACCESS_TOKEN=bmb2026\n"
Path(env_path).write_text(env_content)
print(f"✅ .env actualizado en {env_path}")
