# BMB Encover Agent — Setup Windows

## Requisitos

1. **Python 3.11+** — [Descargar](https://www.python.org/downloads/)
   - Marcar "Add Python to PATH" durante la instalación

2. **Flutter 3.x+** — [Descargar](https://docs.flutter.dev/get-started/install/windows)
   - Seguir la guía de instalación
   - Verificar con `flutter doctor`

3. **Git** (opcional) — [Descargar](https://git-scm.com/download/win)

4. **Tailscale** (opcional, para conexión remota) — [Descargar](https://tailscale.com/download)

---

## Instalación

### 1. Copiar BMB a Windows

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

1. Instalar Tailscale en PC y móvil
2. Iniciar sesión con la misma cuenta en ambos
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
├── app_server.py          ← Servidor para apps
├── run_agent.py           ← Core BMB
├── bmb_cli/               ← CLI
├── bmb_app/               ← App Flutter
│   ├── lib/               ← Código Dart
│   ├── build/             ← Compilados
│   └── run_windows.bat    ← Menu de inicio
├── skills/                ← Skills
├── tools/                 ← Tools Hermes
├── gateway/               ← Gateway
└── venv/                  ← Python virtualenv
```

---

## Comandos Rapidos

```powershell
# Iniciar server
cd C:\bmb-encover && .\venv\Scripts\python app_server.py --port 8643

# Iniciar BMB CLI
cd C:\bmb-encover && .\venv\Scripts\bmb

# Compilar app
cd C:\bmb-encover\bmb_app && flutter build windows
```
