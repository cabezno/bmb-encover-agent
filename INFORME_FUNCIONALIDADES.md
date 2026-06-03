# BMB Encover Agent — Informe Completo de Funcionalidades

> Generado el 18/05/2026
> Último build: #52

---

## 1. Resumen de la Conversación

### Qué es BMB Encover Agent
Un **agente de IA personal** que corre en la PC del usuario (con GPU) y al que se conectan **apps mobile/desktop** de forma **remota y segura**. Es un fork de BMB Undercover Agent, renombrado y limpio.

### Stack tecnológico
| Componente | Tecnología |
|------------|------------|
| Backend (PC) | BMB Encover Agent (fork de BMB) |
| API Server | Python + aiohttp (`app_server.py` v0.4.0) |
| Modelo IA | DeepSeek-V4-Pro (`deepseek-v4-pro`) |
| STT | Whisper large-v3 (GPU del usuario) — **pendiente instalar** |
| TTS | Edge-TTS / Kokoro / Piper — **pendiente instalar** |
| App Mobile/Desktop | Flutter (una base, 4 plataformas) |
| Conexión remota | Tailscale (WireGuard) o Cloudflare Tunnel |
| CI/CD | GitHub Actions (6 artifacts) |
| Seguridad | Access Token (`BMB_ACCESS_TOKEN`) + QR Pairing |

---

## 2. Requisitos Originales vs. Estado Actual

### 2.1 App Multiplataforma (Android / iPhone / Windows / Mac)

| Requisito | Estado | Notas |
|-----------|--------|-------|
| App Android | ✅ **Funcional** | APK compilado en Actions. Build #48+ |
| App iPhone | ❌ **No implementado** | Requiere Mac + certificado Apple para compilar |
| App Windows (Flutter) | ✅ **Funcional** | `.exe` compilado en Actions. Build #48+ |
| App Mac | ❌ **No implementado** | Requiere Mac para compilar |
| CLI (bmb.exe) | ✅ **Funcional** | Build #48+, pero sin --version funcional |

### 2.2 Modos de la App

| Requisito | Estado | Notas |
|-----------|--------|-------|
| **Modo Chat** | ✅ **Funcional** | WebSocket conecta, mensajes se ven, respuestas del agente llegan |
| **Live Mode (voz)** | ❌ **Pendiente** | Endpoints WS de voz existen en server, app no los consume |
| **Consola oculta** | ✅ **Funcional** | Botón flotante ⚙️ en HomeScreen muestra logs del agente |
| **Pestañas multi-instancia** | ✅ **Funcional** | TabBar con múltiples tabs, cada una con su contexto |

### 2.3 Chat

| Requisito | Estado | Notas |
|-----------|--------|-------|
| Enviar mensaje desde app | ✅ **Funcional** | Se muestra inmediatamente en la burbuja |
| Recibir respuesta del agente | ✅ **Funcional** | Llega por WebSocket y se muestra |
| Streaming de respuesta | ❌ **No implementado** | El server soporta `stream_chunk` pero la app no lo usa |
| Indicador de typing | ⚠️ **Parcial** | El server envía typing, la app lo muestra |

### 2.4 QR Pairing

| Requisito | Estado | Notas |
|-----------|--------|-------|
| Server genera QR | ✅ **Funcional** | `GET /api/pair/token` devuelve `qr_data: "bmb://..."` |
| Comando `bmb pair` | ✅ **Funcional** | Muestra QR en terminal |
| App escanea QR con cámara | ❌ **Pendiente** | El paquete `mobile_scanner` rompe builds en Actions |
| App parsea QR manualmente | ✅ **Funcional** | Campo de texto para pegar URL `bmb://...` |
| QR contiene token + IP + puerto | ✅ **Funcional** | Formato: `bmb://ip:port/pair?token=xxx&access=yyy` |

### 2.5 Seguridad

| Requisito | Estado | Notas |
|-----------|--------|-------|
| Access Token (password) | ✅ **Funcional** | `BMB_ACCESS_TOKEN=bmb2026` en `.env` |
| Auth endpoint | ✅ **Funcional** | `POST /api/auth` valida token y devuelve api_key |
| WS requiere token | ✅ **Funcional** | `ws://.../ws?token=...` |
| REST requiere token | ✅ **Funcional** | Header `Authorization: Bearer ...` |
| QR expira en 5 min | ✅ **Funcional** | En `_pairing_tokens` |
| Dispositivos revocables | ✅ **Funcional** | `POST /api/pair/revoke` |

### 2.6 Conexión Remota

| Requisito | Estado | Notas |
|-----------|--------|-------|
| **Tailscale** | ❌ **No implementado** | No se instaló ni configuró |
| **Cloudflare Tunnel** | ⚠️ **Script creado** | `iniciar.bat` lo descarga e inicia |
| IP Pública + Router | ❌ **No implementado** | Requiere configurar NAT en router |
| App Android se conecta remoto | ❌ **Pendiente** | Sin Tailscale o Tunnel, solo funciona en LAN |
| App Windows se conecta remoto | ❌ **Pendiente** | Solo localhost por ahora |

### 2.7 Configuración

| Requisito | Estado | Notas |
|-----------|--------|-------|
| Campo API Key en Settings | ✅ **Funcional** | En `settings_screen.dart` |
| Acceso a API Key en app | ✅ **Funcional** | Se guarda en SharedPreferences |
| Probar conexión DeepSeek | ✅ **Funcional** | Botón en Settings |
| Access Token configurable | ✅ **Funcional** | En `.env` y Settings |

### 2.8 Server (app_server.py)

| Requisito | Estado | Notas |
|-----------|--------|-------|
| Modelo DeepSeek-V4-Pro | ✅ **Funcional** | Cambiado en build #52 |
| System prompt para BMB | ❌ **Falló** | `AIAgent` no acepta `initial_prompt`. Quitado |
| STT (Whisper) | ❌ **No instalado** | `faster-whisper` no está en Windows |
| TTS (Edge-TTS) | ❌ **No instalado** | `edge-tts` no está en Windows |
| `--verbose` logging | ✅ **Funcional** | Muestra cada request |
| `GET /api/debug` | ✅ **Funcional** | Estado detallado del servidor |
| `GET /api/pair/token` | ✅ **Funcional** | Genera QR pairing |
| `POST /api/auth` | ✅ **Funcional** | Valida access token |
| Manejo de errores | ✅ **Funcional** | Errores claros en health |
| Auto-reconexión WS | ✅ **Funcional** | Backoff exponencial |

### 2.9 Instalación

| Requisito | Estado | Notas |
|-----------|--------|-------|
| `run.bat` (inicio rápido) | ✅ **Funcional** | Inicia server con doble clic |
| `iniciar.bat` (con Tunnel) | ⚠️ **Creado** | Descarga Cloudflare Tunnel |
| `instalar_todo.bat` | ⚠️ **Creado** | Instala Python+Flutter+server |
| `setup_windows.ps1` | ✅ **Creado** | Script PowerShell de setup |
| Watchdog bridge | ✅ **Funcional** | Linux→Windows via BMB_CMD/ |
| GitHub Actions CI/CD | ✅ **Funcional** | 6 artifacts por build |

---

## 3. Errores Conocidos y Bugs

### 3.1 Críticos
1. **`AIAgent.__init__()` no acepta `initial_prompt`** — no se puede forzar al agente a presentarse como "BMB". El agente se presenta como "BMB" o como DeepSeek.
2. **App Android no conecta remotamente** — falta Tailscale o Cloudflare Tunnel funcionando.
3. **STT/TTS no instalados en Windows** — `faster-whisper` y `edge-tts` no están en las dependencias.

### 3.2 Medios
4. **QR scanning con cámara no implementado** — `mobile_scanner` rompe builds en Actions.
5. **App iPhone no compila** — requiere Mac + certificado Apple.
6. **Live Mode (voz) no implementado en la app** — el server tiene endpoints pero la app no los consume.
7. **Streaming de respuestas no implementado en la app** — el server envía `stream_chunk` pero la app espera la respuesta completa.

### 3.3 Menores
8. **Puerto default en onboarding es 8765, no 8643** — si el usuario no escribe el puerto, conecta al puerto equivocado.
9. **`--version` no funciona en `bmb.exe`** — el spec de PyInstaller apunta a `run_agent.py` en vez de `bmb_cli.main`.
10. **El `.bat` no funciona desde PowerShell** — solo desde CMD o doble clic.
11. **Space en "Pc Nasa" rompe paths** — requiere comillas o `python.bat` en el path.

---

## 4. Builds y CI/CD

### Últimos builds
| # | Estado | Contenido |
|---|--------|-----------|
| 52 | 🔄 corriendo | Fix `initial_prompt`, modelo deepseek-v4-pro |
| 51 | ✅ success | Modelo deepseek-v4-pro |
| 50 | ✅ success | Fix `.flutter-plugins-dependencies` |
| 49 | ❌ failure | `.flutter-plugins-dependencies` corrompió Python |
| 48 | ✅ success | Chat funcional, ConnectionProvider sin ConnectionModel |
| 47 | ✅ success | Trigger build |
| 46 | ✅ success | (vacío) |
| 45 | ✅ success | (vacío) |
| 44 | ✅ success | (vacío) |
| 43 | ✅ success | System prompt BMB (luego revertido) |
| 42 | ✅ success | Fix `_onNewMessage` duplicado |
| 40 | ✅ success | Fix `chat_message` → `message` |

### Artifacts generados por build
| Artifact | Archivo | Estado |
|----------|---------|--------|
| `bmb-windows-x64` | `bmb.exe` (CLI) | ✅ |
| `bmb-app-server-windows-x64` | `bmb-app-server.exe` | ✅ |
| `bmb-flutter-windows-x64` | `bmb_app.exe` + DLLs | ✅ |
| `bmb-flutter-android` | `app-release.apk` | ✅ |
| `bmb-linux-x64` | `bmb` binary | ✅ |
| `bmb-macos-x64` | `bmb` binary | ✅ |

---

## 5. Próximos Pasos Recomendados

### Prioridad Alta
1. **Instalar Tailscale en PC y celu** — conexión remota inmediata
2. **QR scanning con cámara** — para no depender de entrada manual
3. **Instalar STT/TTS en Windows** — `pip install faster-whisper edge-tts`
4. **Hacer que el agente se presente como BMB** — buscar cómo pasar system prompt en `AIAgent`

### Prioridad Media
5. **Streaming de respuestas en la app** — para feedback en tiempo real
6. **Live Mode (voz) en la app** — consumir `/ws/voice`
7. **Compilar app iPhone** — requiere Mac
8. **Release oficial v0.1.0** con todos los artifacts

### Prioridad Baja
9. **Corregir puerto default 8765 → 8643** en onboarding
10. **Subsanar bug `--version` en `bmb.exe`**
11. **Hacer `.bat` compatibles con PowerShell**

---

## 6. Archivos Clave

| Archivo | Ruta | Descripción |
|---------|------|-------------|
| Server | `/opt/bmb-encover/app_server.py` | API Server v0.4.0 |
| App Flutter | `/opt/bmb-encover/bmb_app/` | App multiplataforma |
| CLI | `/opt/bmb-encover/bmb_cli/main.py` | CLI de BMB |
| Builds | `.github/workflows/build.yml` | CI/CD en Actions |
| Watchdog | `scripts/windows-bridge/bmb_cmd.py` | Puente Linux→Windows |
| Skills Hub | `scripts/skills_index.py` | Index de skills BMB |

---

*Fin del informe.*
