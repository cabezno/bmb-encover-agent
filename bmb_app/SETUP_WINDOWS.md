# BAG Agent â€” Setup Windows

## Flujo recomendado (portable)

Desde la carpeta raiz del repo clonado (la que contiene `app_server.py`):

```powershell
.\setup_windows_portable.bat
.\start_windows_portable.bat
```

Este flujo evita rutas hardcodeadas y usa un `venv` local dentro del repo.

## Requisitos

1. **Python 3.11+** â€” [Descargar](https://www.python.org/downloads/)
   - Marcar "Add Python to PATH" durante la instalaciÃ³n

2. **Flutter 3.x+** â€” [Descargar](https://docs.flutter.dev/get-started/install/windows)
   - Seguir la guÃ­a de instalaciÃ³n
   - Verificar con `flutter doctor`

3. **Git** (opcional) â€” [Descargar](https://git-scm.com/download/win)

4. **Tailscale** (opcional, para conexiÃ³n remota) â€” [Descargar](https://tailscale.com/download)

---

## InstalaciÃ³n

### 1. Copiar BAG a Windows

```powershell
# Desde esta PC (Linux):
scp -r santi-audio:/opt/bmb-encover C:\bmb-encover

# O desde USB / compartir carpeta
```

### 2. Crear virtualenv e instalar

```powershell
cd C:\bmb-encover
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -e .[pty,cli,mcp,cron,acp]
```

### 3. Iniciar el server

```powershell
# Opcion A: Menu interactivo
.\bmb_app\run_windows.bat

# Opcion B: Directo
.\venv\Scripts\python app_server.py --port 8643

# Opcion C: Script portable recomendado
.\start_windows_portable.bat
```

### 4. Probar conexion

```powershell
# Health check
curl http://localhost:8643/health

# Chat REST
curl -X POST http://localhost:8643/api/chat -H "Content-Type: application/json" -d "{\"message\":\"Hola\"}"
```

---

## App Flutter

### Compilar para Windows

```powershell
cd C:\bmb-encover\bmb_app
flutter pub get
flutter build windows
```

El ejecutable queda en:
```
C:\bmb-encover\bmb_app\build\windows\runner\Release\bmb_app.exe
```

### Compilar para Android

```powershell
cd C:\bmb-encover\bmb_app
flutter pub get
flutter build apk
```

APK en:
```
C:\bmb-encover\bmb_app\build\app\outputs\flutter-apk\app-release.apk
```

---

## Conexion Remota (Tailscale)

1. Instalar Tailscale en PC y mÃ³vil
2. Iniciar sesiÃ³n con la misma cuenta en ambos
3. La PC tiene IP tipo `100.x.x.x`
4. En la app, conectar a `ws://100.x.x.x:8643/ws`

---

## QR Pairing

Para vincular un dispositivo:

```powershell
cd C:\bmb-encover
.\venv\Scripts\python -c "
from app_server import AppServer
import json
print(json.dumps(AppServer.generate_pairing_token(), indent=2))
"
```

El token expira en 5 minutos. Usar desde la app con "Escanear QR".

---

## Estructura de Archivos

```
C:\bmb-encover\
â”œâ”€â”€ app_server.py          â† Servidor para apps
â”œâ”€â”€ run_agent.py           â† Core BMB
â”œâ”€â”€ bmb_cli/               â† CLI
â”œâ”€â”€ bmb_app/               â† App Flutter
â”‚   â”œâ”€â”€ lib/               â† CÃ³digo Dart
â”‚   â”œâ”€â”€ build/             â† Compilados
â”‚   â””â”€â”€ run_windows.bat    â† Menu de inicio
â”œâ”€â”€ skills/                â† Skills
â”œâ”€â”€ tools/                 â† Tools BMB
â”œâ”€â”€ gateway/               â† Gateway
â””â”€â”€ venv/                  â† Python virtualenv
```

---

## Comandos Rapidos

```powershell
# Iniciar server
cd C:\bmb-encover && .\venv\Scripts\python app_server.py --port 8643

# Iniciar BAG CLI
cd C:\bmb-encover && .\venv\Scripts\bmb

# Compilar app
cd C:\bmb-encover\bmb_app && flutter build windows
```

