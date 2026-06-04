# BAG - Instalacion Windows Portable

Este documento explica una instalacion simple para correr el App Server en Windows sin rutas hardcodeadas.

## Alcance

- Instala un entorno virtual local dentro del repo.
- Instala dependencias necesarias para App Server (chat, health, QR, TTS basico).
- Permite iniciar el server con un solo script.

Nota: El upstream oficial sigue recomendando WSL2 para uso completo de BMB.

## Requisitos

1. Windows 10/11
2. Python 3.11 o superior en PATH
3. Git (opcional, para clonar)
4. Conexion a internet (para instalar paquetes)

## Pasos de instalacion

1. Clonar el repositorio:

```powershell
git clone https://github.com/cabezno/bmb-encover-agent.git
cd bmb-encover-agent
```

2. Ejecutar setup portable:

```powershell
.\setup_windows_portable.bat
```

3. Completar configuracion en:

- %USERPROFILE%\\.bmb\\.env

Variables minimas recomendadas:

```env
DEEPSEEK_API_KEY=tu_api_key
BAG_ACCESS_TOKEN=tu_token_opcional
BAG_TTS_VOICE=es-AR-ElenaNeural
BAG_WHISPER_MODEL=tiny
```

4. Iniciar el servidor:

```powershell
.\start_windows_portable.bat
```

5. Verificar estado:

```powershell
curl http://localhost:8643/health
```

## Scripts incluidos

- setup_windows_portable.bat: crea venv, instala dependencias y prepara .env
- start_windows_portable.bat: inicia app_server.py con el python del venv local
- quick_check_windows.bat: chequeo rapido de entorno, health y QR
- bmb_app/run_windows.bat: menu interactivo actualizado con rutas relativas

## Solucion de problemas

1. Python no encontrado:
- Reinstalar Python 3.11+ marcando Add Python to PATH.

2. Error en QR (500 qrcode no instalado):
- Ejecutar: .\venv\Scripts\python -m pip install "qrcode[pil]" pillow

3. Puerto 8643 en uso:
- Cerrar procesos python previos o cambiar puerto al iniciar.

4. Falla de clave API:
- Revisar DEEPSEEK_API_KEY en %USERPROFILE%\\.bmb\\.env

## Actualizar dependencias

```powershell
.\venv\Scripts\python -m pip install --upgrade pip
.\venv\Scripts\python -m pip install -e .[pty,cli,mcp,cron,acp]
```

