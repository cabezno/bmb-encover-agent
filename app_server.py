"""
BMB Encover — App API Server v0.4.0

Server WebSocket + REST para apps mobile/desktop de BMB.
Corre en Linux (WSL) y Windows nativo.

Endpoints:
- GET  /health              — health check con estado detallado
- GET  /api/debug           — debug completo del servidor
- POST /api/pair            — QR pairing (recibe token, devuelve api_key)
- POST /api/auth            — validar token de acceso
- POST /api/chat            — REST chat request-response
- GET  /api/sessions        — listar sesiones activas
- GET  /api/pair/token      — generar token de pairing (para CLI)
- GET  /api/pair/devices    — listar dispositivos vinculados
- POST /api/pair/revoke     — revocar un dispositivo
- WS   /ws                  — WebSocket chat multi-tab
- WS   /ws/voice            — WebSocket live mode (voz)

Seguridad:
- Access token (password) configurable via env BMB_ACCESS_TOKEN
- Si está configurado, WS y REST lo requieren como query param ?token= o header
- Pairing solo requiere token temporal de 5 minutos

Protocolo WebSocket (/ws):
  Cliente → Servidor:
    {"type": "message", "tab_id": "...", "text": "..."}
    {"type": "ping"}
  Servidor → Cliente:
    {"type": "connected", "session_id": "..."}
    {"type": "message", "tab_id": "...", "text": "..."}
    {"type": "status", "tab_id": "...", "status": "processing|idle|error"}
    {"type": "error", "tab_id": "...", "text": "..."}
    {"type": "pong"}
"""

import asyncio
import json
import logging
import os
import sys
import uuid
import time
import traceback
import secrets
import base64
import io
import struct
from pathlib import Path
from typing import Optional

# ─── Configurar path para que funcione en Windows ────────────────
_BMB_DIR = Path(__file__).parent.resolve()
if str(_BMB_DIR) not in sys.path:
    sys.path.insert(0, str(_BMB_DIR))

try:
    from aiohttp import web, WSMsgType
except ImportError:
    print("[ERROR] aiohttp no instalado. Ejecute: pip install aiohttp")
    sys.exit(1)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("bmb-app-server")

DEFAULT_HOST = "0.0.0.0"
DEFAULT_PORT = 8643
AUTH_FILE = Path(os.path.expanduser("~/.bmb/app_auth.json"))
ENV_FILE = Path(os.path.expanduser("~/.bmb/.env"))
CONFIG_FILE = Path(os.path.expanduser("~/.bmb/config.yaml"))

# ─── Config ─────────────────────────────────────────────────────

def _load_env():
    """Cargar .env si existe."""
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            line = line.strip()
            if "=" in line and not line.startswith("#"):
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())


def _get_env(key: str, default: str = "") -> str:
    return os.environ.get(key, default)


# ─── Server ─────────────────────────────────────────────────────

class AppServer:
    def __init__(self, host: str = DEFAULT_HOST, port: int = DEFAULT_PORT, verbose: bool = False):
        self.host = host
        self.port = port
        self.verbose = verbose
        self.app = web.Application()
        self.clients: dict[str, web.WebSocketResponse] = {}
        self.sessions: dict[str, dict] = {}
        self.tabs: dict[str, dict] = {}
        self.devices: dict[str, dict] = {}
        self.bmb_agent = None
        self._agent_error: Optional[str] = None
        self._pairing_tokens: dict[str, float] = {}
        self._access_token: str = _get_env("BMB_ACCESS_TOKEN", "")
        self.tunnel_url: str = ""
        self._tunnel_check_task = None
        self._tunnel_log_file = _BMB_DIR / "tunnel_url.txt"
        self._qr_data: str = ""

        _load_env()
        self.setup_routes()
        self._load_devices()
        self._init_stt()
        self._init_tts()
        self._init_agent()

        if self._access_token:
            logger.info(f"🔒 Access token configurado")

    # ─── Logging ────────────────────────────────────────────────

    def _log(self, msg: str, level: str = "info"):
        if self.verbose or level == "error":
            getattr(logger, level, logger.info)(msg)

    # ─── Rutas ──────────────────────────────────────────────────

    def setup_routes(self):
        self.app.router.add_get("/health", self.handle_health)
        self.app.router.add_get("/api/debug", self.handle_debug)
        self.app.router.add_post("/api/pair", self.handle_pair)
        self.app.router.add_post("/api/auth", self.handle_auth)
        self.app.router.add_post("/api/chat", self.handle_chat_rest)
        self.app.router.add_get("/api/sessions", self.handle_list_sessions)
        self.app.router.add_get("/api/pair/token", self.handle_pair_token)
        self.app.router.add_get("/api/pair/devices", self.handle_pair_devices)
        self.app.router.add_post("/api/pair/revoke", self.handle_pair_revoke)
        self.app.router.add_get("/ws", self.handle_websocket_chat)
        self.app.router.add_get("/ws/voice", self.handle_websocket_voice)
        # ─── Android endpoints ───────────────────
        self.app.router.add_post("/api/image", self.handle_image)
        self.app.router.add_post("/api/audio", self.handle_audio)
        self.app.router.add_get("/api/tts", self.handle_tts_get)
        self.app.router.add_post("/api/call/start", self.handle_call_start)
        self.app.router.add_post("/api/call/audio", self.handle_call_audio)
        # ─── File transfer endpoints ──────────────
        self.app.router.add_post("/api/upload", self.handle_upload)
        self.app.router.add_get("/api/files", self.handle_list_files)
        self.app.router.add_get("/api/files/{filename}", self.handle_get_file)
        self.app.router.add_delete("/api/files/{filename}", self.handle_delete_file)
        self.app.router.add_post("/api/forward", self.handle_forward_file)
        self.app.router.add_get("/pair", self.handle_pair_page)
        self.app.router.add_get("/api/tunnel/refresh", self.handle_tunnel_refresh)
        self.app.router.add_static("/uploads", path=str(_BMB_DIR / "uploads"), name="uploads")
        self.app.router.add_get("/", self.handle_index)
        self.app.router.add_get("/qr", self.handle_qr_page)

    # ─── Auth ───────────────────────────────────────────────────

    def _check_access(self, request) -> bool:
        """Verificar access token si está configurado."""
        if not self._access_token:
            return True
        token = request.query.get("token", "") or request.headers.get("Authorization", "").replace("Bearer ", "")
        return token == self._access_token

    def _load_devices(self):
        if AUTH_FILE.exists():
            try:
                data = json.loads(AUTH_FILE.read_text())
                self.devices = data.get("devices", {})
                logger.info(f"📱 {len(self.devices)} dispositivos cargados")
            except Exception:
                self.devices = {}

    def _save_devices(self):
        AUTH_FILE.parent.mkdir(parents=True, exist_ok=True)
        AUTH_FILE.write_text(json.dumps({"devices": self.devices}, indent=2))

    def _generate_api_key(self) -> str:
        return f"bmb_{secrets.token_hex(32)}"

    def _verify_device(self, request) -> Optional[str]:
        api_key = request.query.get("api_key", "") or request.headers.get("X-API-Key", "")
        for dev_id, dev_info in self.devices.items():
            if dev_info.get("api_key") == api_key:
                return dev_id
        return None

    # ─── Agente BMB ─────────────────────────────────────────────

    def _init_agent(self):
        """Inicializar el agente BMB al arrancar."""
        logger.info("🔄 Inicializando agente BMB...")
        api_key = _get_env("DEEPSEEK_API_KEY", "")
        if not api_key:
            self._agent_error = "DEEPSEEK_API_KEY no configurada. Pone tu API key en Settings."
            logger.warning(f"⚠️  {self._agent_error}")
            return

        try:
            from bmb_cli.config import load_config
            from bmb_cli.env_loader import load_bmb_dotenv

            load_bmb_dotenv()
            config = load_config()
            provider_cfg = config.get("provider", {})
            base_url = provider_cfg.get("base_url", _get_env("DEEPSEEK_API_URL", "https://api.deepseek.com/v1"))
            model = provider_cfg.get("model", "deepseek-v4-pro")

            from run_agent import AIAgent
            self.bmb_agent = AIAgent(
                base_url=base_url,
                api_key=api_key,
                provider="custom",
                model=model,
                max_iterations=30,
                enabled_toolsets=["web", "terminal", "file", "search"],
                quiet_mode=True,
                save_trajectories=False,
                skip_memory=False,
                platform="app",
                ephemeral_system_prompt="Eres BMB Undercover Agent, un asistente de IA personal. Tu nombre es BMB. Nunca te presentes como Hermes ni menciones Nous Research. Respondes en español de forma natural y conversacional.",
            )
            self._agent_error = None
            logger.info(f"✅ Agente BMB: model={model}")
        except ImportError as e:
            self._agent_error = f"Error importando BMB: {e}. Asegurate de estar en la carpeta de BMB o tenerlo instalado."
            logger.error(f"❌ {self._agent_error}")
        except Exception as e:
            self._agent_error = f"Error inicializando agente: {e}"
            logger.error(f"❌ {self._agent_error}")
            logger.error(traceback.format_exc())

    def _get_agent(self):
        if self.bmb_agent is None:
            return None
        return self.bmb_agent

    # ─── STT / TTS ──────────────────────────────────────────────

    def _init_stt(self):
        self.whisper_model = None
        self.whisper_available = False
        try:
            from faster_whisper import WhisperModel
            model_size = _get_env("BMB_WHISPER_MODEL", "tiny")
            # Descargar modelo si no existe
            logger.info(f"🎤 Cargando Whisper model={model_size}...")
            self.whisper_model = WhisperModel(model_size, device="cpu", compute_type="int8", download_root=None)
            self.whisper_available = True
            logger.info("✅ Whisper STT listo")
        except ImportError:
            logger.warning("⚠️  Whisper STT no disponible: faster-whisper no instalado")
            logger.info("   Para instalarlo: pip install faster-whisper")
        except Exception as e:
            logger.warning(f"⚠️  Whisper STT error: {e}")

    def _init_tts(self):
        self.tts_available = False
        self.tts_voice = _get_env("BMB_TTS_VOICE", "es-AR-ElenaNeural")
        try:
            import edge_tts
            self.tts_available = True
            logger.info(f"✅ Edge-TTS listo: voice={self.tts_voice}")
        except ImportError:
            logger.warning("⚠️  TTS no disponible: edge-tts no instalado")
            logger.info("   Para instalarlo: pip install edge-tts")

    # ─── Handlers ───────────────────────────────────────────────

    async def handle_health(self, request):
        agent_status = "ok" if self.bmb_agent is not None else "no_disponible"
        if self._agent_error:
            agent_status = f"error: {self._agent_error[:100]}"

        return web.json_response({
            "status": "ok",
            "version": "0.5.0",
            "name": "BMB Encover App Server",
            "agent": agent_status,
            "stt": self.whisper_available,
            "tts": self.tts_available,
            "tts_voice": self.tts_voice,
            "clients": len(self.clients),
            "sessions": len(self.sessions),
            "tabs": len(self.tabs),
            "devices": len(self.devices),
            "auth": bool(self._access_token),
        })

    async def handle_debug(self, request):
        return web.json_response({
            "version": "0.4.0",
            "python": sys.version,
            "cwd": str(_BMB_DIR),
            "sys_path": sys.path[:5],
            "env_keys": [k for k in os.environ if "DEEP" in k or "BMB" in k or "ACCESS" in k],
            "agent": {
                "loaded": self.bmb_agent is not None,
                "error": self._agent_error,
            },
            "stt": self.whisper_available,
            "tts": self.tts_available,
            "auth": bool(self._access_token),
            "devices": len(self.devices),
            "sessions": len(self.sessions),
            "tabs": list(self.tabs.keys())[:20],
        })

    async def handle_auth(self, request):
        """POST /api/auth — validar access token."""
        try:
            raw = await request.text()
            body = json.loads(raw) if raw.strip() else {}
        except Exception:
            return web.json_response({"error": "JSON inválido"}, status=400)

        token = body.get("token", "")
        if self._access_token and token != self._access_token:
            return web.json_response({"error": "Token inválido"}, status=401)

        # Generar api_key de sesión si no existe
        dev_id = self._verify_device(request)
        if not dev_id:
            dev_id = f"session_{secrets.token_hex(8)}"
            api_key = self._generate_api_key()
            self.devices[dev_id] = {
                "api_key": api_key,
                "name": body.get("device_name", "App móvil"),
                "type": body.get("device_type", "unknown"),
                "paired_at": time.time(),
            }
            self._save_devices()
        else:
            api_key = self.devices[dev_id]["api_key"]

        return web.json_response({
            "status": "authenticated",
            "device_id": dev_id,
            "api_key": api_key,
        })

    async def handle_pair(self, request):
        """POST /api/pair — QR pairing handshake."""
        try:
            raw = await request.text()
            body = json.loads(raw) if raw.strip() else {}
        except Exception:
            return web.json_response({"error": "JSON inválido"}, status=400)

        if not isinstance(body, dict):
            return web.json_response({"error": "JSON inválido"}, status=400)

        token = body.get("token", "")
        device_name = body.get("device_name", "Unknown")
        device_type = body.get("device_type", "unknown")

        if token not in self._pairing_tokens:
            return web.json_response({"error": "Token inválido o expirado"}, status=401)

        if time.time() > self._pairing_tokens[token]:
            del self._pairing_tokens[token]
            return web.json_response({"error": "Token expirado"}, status=401)

        # Token válido → generar api_key permanente
        del self._pairing_tokens[token]
        dev_id = f"dev_{secrets.token_hex(8)}"
        api_key = self._generate_api_key()
        self.devices[dev_id] = {
            "api_key": api_key,
            "name": device_name,
            "type": device_type,
            "paired_at": time.time(),
        }
        self._save_devices()
        logger.info(f"📱 Nuevo dispositivo: {device_name} ({device_type})")

        return web.json_response({
            "status": "paired",
            "device_id": dev_id,
            "api_key": api_key,
            "agent_name": "BMB Encover",
        })

    async def handle_chat_rest(self, request):
        if not self._check_access(request):
            return web.json_response({"error": "Token de acceso requerido"}, status=401)

        try:
            raw = await request.text()
            body = json.loads(raw) if raw.strip() else {}
        except Exception as e:
            return web.json_response({"error": f"JSON inválido: {e}"}, status=400)

        if not isinstance(body, dict):
            return web.json_response({"error": "JSON inválido"}, status=400)

        message = body.get("message", "").strip()
        session_id = body.get("session_id", str(uuid.uuid4()))
        tab_id = body.get("tab_id", "default")

        if not message:
            return web.json_response({"error": "Mensaje vacío"}, status=400)

        logger.info(f"📩 REST: tab={tab_id[:8]} msg='{message[:50]}...'")

        if self._agent_error:
            return web.json_response({
                "error": f"Agente no disponible: {self._agent_error[:200]}"
            }, status=503)

        agent = self._get_agent()
        if agent is None:
            msg = self._agent_error or "Agente no disponible. Revisa API key en Settings."
            return web.json_response({"error": msg}, status=503)

        try:
            response = await asyncio.to_thread(agent.chat, message)

            if session_id not in self.sessions:
                self.sessions[session_id] = {"created": time.time(), "tabs": {}}
            self.sessions[session_id]["tabs"][tab_id] = {
                "last_message": message[:100],
                "last_response": response[:100],
                "message_count": self.sessions[session_id]["tabs"].get(tab_id, {}).get("message_count", 0) + 1,
            }

            return web.json_response({
                "session_id": session_id,
                "tab_id": tab_id,
                "response": response,
                "model": "deepseek-chat",
            })
        except Exception as e:
            logger.error(f"❌ Chat error: {e}")
            return web.json_response({"error": f"Error: {e}"}, status=500)

    # ─── Pairing endpoints ──────────────────────────────────────

    def generate_pairing_token(self) -> str:
        token = secrets.token_hex(16)
        self._pairing_tokens[token] = time.time() + 300  # 5 min
        return token

    async def handle_pair_token(self, request):
        token = self.generate_pairing_token()
        base_url = self.tunnel_url or f"http://{_get_env('BMB_ADVERTISE_IP', '192.168.1.22')}:{self.port}"
        access_token = self._access_token

        # QR data en formato JSON que espera la app Android
        import json as jsonlib
        local_ip = _get_env('BMB_ADVERTISE_IP', '192.168.1.22')
        qr_data = jsonlib.dumps({
            "type": "pairing_request",
            "ip": self.tunnel_url or local_ip,
            "port": self.port,
            "deviceId": token[:8],
            "tunnel_url": self.tunnel_url or "",
            "local_ip": local_ip,
        })

        # Si pide .png, devolver imagen QR
        if request.query.get("format", "") == "png":
            return await self._serve_qr_png(qr_data)

        return web.json_response({
            "token": token,
            "expires_at": self._pairing_tokens[token],
            "tunnel_url": self.tunnel_url or "no_tunnel",
            "ip": base_url,
            "port": self.port,
            "access_token": bool(access_token),
            "qr_data": qr_data,
        })

    async def _serve_qr_png(self, data: str):
        """Generar y servir imagen QR PNG."""
        try:
            import qrcode
            from io import BytesIO
            img = qrcode.make(data, box_size=8, border=2)
            buf = BytesIO()
            img.save(buf, format="PNG")
            buf.seek(0)
            return web.Response(body=buf.read(), content_type="image/png")
        except ImportError:
            return web.json_response({"error": "qrcode no instalado. pip install qrcode[pil]"}, status=500)

    async def handle_pair_devices(self, request):
        devices_list = []
        for dev_id, dev_info in self.devices.items():
            devices_list.append({
                "id": dev_id,
                "name": dev_info.get("name", "Unknown"),
                "type": dev_info.get("type", "unknown"),
                "paired_at": dev_info.get("paired_at", 0),
            })
        return web.json_response({"devices": devices_list})

    async def handle_pair_revoke(self, request):
        try:
            raw = await request.text()
            body = json.loads(raw) if raw.strip() else {}
        except Exception:
            return web.json_response({"error": "JSON inválido"}, status=400)

        device_id = body.get("device_id", "")
        if device_id in self.devices:
            del self.devices[device_id]
            self._save_devices()
            logger.info(f"📱 Dispositivo revocado: {device_id[:16]}")
            return web.json_response({"status": "revoked"})
        return web.json_response({"error": "Dispositivo no encontrado"}, status=404)

    async def handle_list_sessions(self, request):
        sessions_list = []
        for sid, sinfo in self.sessions.items():
            sessions_list.append({
                "id": sid[:16],
                "created": sinfo.get("created", 0),
                "tabs": list(sinfo.get("tabs", {}).keys())[:10],
            })
        return web.json_response({"sessions": sessions_list})

    # ─── WebSocket Chat ─────────────────────────────────────────

    async def handle_websocket_chat(self, request):
        if not self._check_access(request):
            return web.json_response({"error": "Token de acceso requerido"}, status=401)

        ws = web.WebSocketResponse()
        await ws.prepare(request)
        session_id = str(uuid.uuid4())
        self.clients[session_id] = ws
        logger.info(f"🔗 WS conectado: {session_id[:8]}")

        await ws.send_json({"type": "connected", "session_id": session_id})

        try:
            async for msg in ws:
                if msg.type == WSMsgType.TEXT:
                    data = json.loads(msg.data)
                    msg_type = data.get("type", "")

                    if msg_type == "ping":
                        await ws.send_json({"type": "pong"})

                    elif msg_type == "message":
                        tab_id = data.get("tab_id", "default")
                        text = data.get("text", "").strip()
                        if not text:
                            continue

                        logger.info(f"💬 WS msg: tab={tab_id[:8]} '{text[:50]}...'")

                        if self._agent_error:
                            await ws.send_json({
                                "type": "error",
                                "tab_id": tab_id,
                                "text": f"Agente no disponible: {self._agent_error[:200]}",
                            })
                            continue

                        agent = self._get_agent()
                        if agent is None:
                            msg = self._agent_error or "Agente no disponible"
                            await ws.send_json({"type": "error", "tab_id": tab_id, "text": msg})
                            continue

                        try:
                            response = await asyncio.to_thread(agent.chat, text)
                            await ws.send_json({
                                "type": "message",
                                "tab_id": tab_id,
                                "text": response,
                                "session_id": session_id,
                            })
                        except Exception as e:
                            await ws.send_json({
                                "type": "error",
                                "tab_id": tab_id,
                                "text": f"Error: {e}",
                            })

                elif msg.type == WSMsgType.ERROR:
                    logger.error(f"❌ WS error: {msg.data}")
                    break

        except Exception as e:
            logger.error(f"❌ WS exception: {e}")
        finally:
            self.clients.pop(session_id, None)
            logger.info(f"🔌 WS desconectado: {session_id[:8]}")

        return ws

    # ─── WebSocket Voice ────────────────────────────────────────

    async def handle_websocket_voice(self, request):
        if not self._check_access(request):
            return web.json_response({"error": "Token de acceso requerido"}, status=401)

        ws = web.WebSocketResponse()
        await ws.prepare(request)
        session_id = str(uuid.uuid4())
        self.clients[session_id] = ws
        logger.info(f"🎤 WS Voice conectado: {session_id[:8]}")

        await ws.send_json({"type": "connected", "session_id": session_id, "voice_mode": True})

        audio_buffers: dict[str, list[dict]] = {}

        try:
            async for msg in ws:
                if msg.type == WSMsgType.TEXT:
                    data = json.loads(msg.data)
                    msg_type = data.get("type", "")
                    tab_id = data.get("tab_id", "default")

                    if msg_type == "ping":
                        await ws.send_json({"type": "pong"})

                    elif msg_type == "audio_chunk":
                        if tab_id not in audio_buffers:
                            audio_buffers[tab_id] = []
                        audio_buffers[tab_id].append({
                            "data": data.get("data", ""),
                            "seq": data.get("seq", 0),
                        })

                    elif msg_type == "speech_end":
                        duration = data.get("duration_ms", 0)
                        logger.info(f"🎤 Speech end: tab={tab_id[:8]} duration={duration}ms")

                        # 1) STT: transcribir chunks de audio
                        chunks = audio_buffers.pop(tab_id, [])
                        stt_text = await self._transcribe(chunks)

                        # Enviar transcripción al cliente
                        await ws.send_json({"type": "stt_final", "tab_id": tab_id, "text": stt_text})

                        if stt_text and self.bmb_agent:
                            await ws.send_json({"type": "agent_status", "tab_id": tab_id, "status": "thinking"})
                            try:
                                # 2) Enviar texto al agente BMB
                                response = await asyncio.to_thread(self.bmb_agent.chat, stt_text)

                                # Enviar respuesta como texto
                                await ws.send_json({
                                    "type": "message",
                                    "tab_id": tab_id,
                                    "text": response,
                                    "session_id": session_id,
                                })

                                # 3) Convertir respuesta a audio con Edge TTS
                                if response and self.tts_available:
                                    try:
                                        import edge_tts
                                        communicate = edge_tts.Communicate(response, self.tts_voice)
                                        # edge-tts save() necesita una ruta de archivo, usamos un tempfile
                                        import tempfile
                                        with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
                                            tmp_path = tmp.name
                                        try:
                                            await communicate.save(tmp_path)
                                            with open(tmp_path, "rb") as f:
                                                audio_bytes = f.read()
                                        finally:
                                            if os.path.exists(tmp_path):
                                                os.unlink(tmp_path)

                                        audio_b64 = base64.b64encode(audio_bytes).decode("utf-8")
                                        # 4) Enviar audio al WS
                                        await ws.send_json({
                                            "type": "audio_response",
                                            "tab_id": tab_id,
                                            "audio": audio_b64,
                                            "session_id": session_id,
                                        })
                                    except Exception as tts_e:
                                        logger.error(f"❌ TTS error: {tts_e}")
                                        await ws.send_json({
                                            "type": "error",
                                            "tab_id": tab_id,
                                            "text": f"Error generando audio: {tts_e}",
                                        })
                            except Exception as e:
                                await ws.send_json({"type": "error", "tab_id": tab_id, "text": str(e)})

                        await ws.send_json({"type": "agent_status", "tab_id": tab_id, "status": "listening"})

                elif msg.type == WSMsgType.ERROR:
                    break

        except Exception as e:
            logger.error(f"❌ Voice WS error: {e}")
        finally:
            self.clients.pop(session_id, None)
            logger.info(f"🔌 Voice WS desconectado: {session_id[:8]}")

        return ws

    async def _transcribe(self, chunks: list) -> str:
        """Transcribir chunks de audio con Whisper."""
        if not self.whisper_available or self.whisper_model is None:
            return ""
        try:
            pcm_data = bytearray()
            for chunk in sorted(chunks, key=lambda c: c.get("seq", 0)):
                try:
                    pcm_data.extend(base64.b64decode(chunk.get("data", "")))
                except Exception:
                    continue

            if not pcm_data:
                return ""

            import soundfile as sf
            wav_io = io.BytesIO()
            import numpy as np
            samples = np.frombuffer(pcm_data, dtype=np.int16).astype(np.float32) / 32768.0
            sf.write(wav_io, samples, 16000, format="WAV")
            wav_io.seek(0)

            segments, _ = self.whisper_model.transcribe(wav_io, language="es", beam_size=3, vad_filter=True)
            return " ".join(seg.text for seg in segments)
        except Exception as e:
            logger.error(f"❌ Whisper error: {e}")
            return ""

    # ─── Android: Imagen ─────────────────────────────────────

    async def handle_image(self, request):
        if not self._check_access(request):
            return web.json_response({"error": "Token requerido"}, status=401)
        try:
            reader = await request.multipart()
            field = await reader.next()
            if not field:
                return web.json_response({"error": "No se recibió archivo"}, status=400)
            filename = field.filename or "image.jpg"
            img_data = await field.read()
            img_path = _BMB_DIR / "uploads" / f"img_{int(time.time())}_{filename}"
            img_path.parent.mkdir(parents=True, exist_ok=True)
            img_path.write_bytes(img_data)
            logger.info(f"📷 Imagen recibida: {img_path.name} ({len(img_data)} bytes)")
            # Describir imagen con BMB
            agent = self._get_agent()
            if agent:
                desc = await asyncio.to_thread(agent.chat, f"Describí esta imagen en español: {img_path}")
            else:
                desc = f"Imagen recibida: {filename}"
            return web.json_response({"status": "ok", "filename": filename, "description": desc})
        except Exception as e:
            logger.error(f"❌ Image error: {e}")
            return web.json_response({"error": str(e)}, status=500)

    # ─── Android: Audio grabado ──────────────────────────────

    async def handle_audio(self, request):
        if not self._check_access(request):
            return web.json_response({"error": "Token requerido"}, status=401)
        try:
            reader = await request.multipart()
            field = await reader.next()
            if not field:
                return web.json_response({"error": "No se recibió audio"}, status=400)
            audio_data = await field.read()
            audio_path = _BMB_DIR / "uploads" / f"audio_{int(time.time())}.wav"
            audio_path.parent.mkdir(parents=True, exist_ok=True)
            audio_path.write_bytes(audio_data)
            logger.info(f"🎤 Audio recibido: {audio_path.name} ({len(audio_data)} bytes)")
            # STT
            texto = ""
            if self.whisper_available:
                import soundfile as sf
                import numpy as np
                wav_io = io.BytesIO(audio_data)
                segments, _ = self.whisper_model.transcribe(wav_io, language="es", beam_size=3, vad_filter=True)
                texto = " ".join(seg.text for seg in segments)
            else:
                texto = "(STT no disponible)"
            logger.info(f"📝 Transcripción: {texto[:100]}")
            # BMB response
            respuesta = ""
            agent = self._get_agent()
            if agent and texto:
                respuesta = await asyncio.to_thread(agent.chat, texto)
            # TTS
            audio_respuesta = ""
            if respuesta and self.tts_available:
                import edge_tts
                tts_path = _BMB_DIR / "uploads" / f"tts_{int(time.time())}.mp3"
                communicate = edge_tts.Communicate(respuesta, self.tts_voice)
                await communicate.save(str(tts_path))
                audio_respuesta = tts_path.name
            return web.json_response({
                "status": "ok",
                "transcripcion": texto,
                "respuesta": respuesta,
                "audio_respuesta": audio_respuesta,
            })
        except Exception as e:
            logger.error(f"❌ Audio error: {e}")
            return web.json_response({"error": str(e)}, status=500)

    # ─── TTS directo GET ─────────────────────────────────────

    async def handle_tts_get(self, request):
        if not self._check_access(request):
            return web.json_response({"error": "Token requerido"}, status=401)
        texto = request.query.get("text", "").strip()
        if not texto:
            return web.json_response({"error": "Parámetro 'text' requerido"}, status=400)
        if not self.tts_available:
            return web.json_response({"error": "TTS no disponible"}, status=503)
        try:
            import edge_tts
            tts_path = _BMB_DIR / "uploads" / f"tts_{int(time.time())}.mp3"
            tts_path.parent.mkdir(parents=True, exist_ok=True)
            communicate = edge_tts.Communicate(texto, self.tts_voice)
            await communicate.save(str(tts_path))
            return web.FileResponse(tts_path)
        except Exception as e:
            return web.json_response({"error": str(e)}, status=500)

    # ─── Llamada: inicio ─────────────────────────────────────

    async def handle_call_start(self, request):
        if not self._check_access(request):
            return web.json_response({"error": "Token requerido"}, status=401)
        try:
            body = await request.json()
            numero = body.get("numero", "")
            logger.info(f"📞 Llamada iniciada desde: {numero}")
            return web.json_response({
                "status": "connected",
                "mensaje": "Llamada conectada. Enviá audio por /api/call/audio",
                "session_id": str(uuid.uuid4()),
            })
        except Exception as e:
            return web.json_response({"error": str(e)}, status=500)

    # ─── Llamada: audio ──────────────────────────────────────

    async def handle_call_audio(self, request):
        if not self._check_access(request):
            return web.json_response({"error": "Token requerido"}, status=401)
        try:
            reader = await request.multipart()
            field = await reader.next()
            if not field:
                return web.json_response({"error": "No se recibió audio"}, status=400)
            audio_data = await field.read()
            audio_path = _BMB_DIR / "uploads" / f"call_{int(time.time())}.wav"
            audio_path.parent.mkdir(parents=True, exist_ok=True)
            audio_path.write_bytes(audio_data)
            # STT
            texto = ""
            if self.whisper_available:
                import soundfile as sf
                import numpy as np
                wav_io = io.BytesIO(audio_data)
                segments, _ = self.whisper_model.transcribe(wav_io, language="es", beam_size=3, vad_filter=True)
                texto = " ".join(seg.text for seg in segments)
            # BMB response
            respuesta = ""
            agent = self._get_agent()
            if agent and texto:
                respuesta = await asyncio.to_thread(agent.chat, texto)
            # TTS
            audio_respuesta = ""
            if respuesta and self.tts_available:
                import edge_tts
                tts_path = _BMB_DIR / "uploads" / f"call_tts_{int(time.time())}.mp3"
                communicate = edge_tts.Communicate(respuesta, self.tts_voice)
                await communicate.save(str(tts_path))
                audio_respuesta = tts_path.name
            return web.json_response({
                "status": "ok",
                "transcripcion": texto,
                "respuesta": respuesta,
                "audio_respuesta": audio_respuesta,
                "upload_url": f"http://localhost:8643/uploads/{audio_respuesta}" if audio_respuesta else "",
            })
        except Exception as e:
            logger.error(f"❌ Call error: {e}")
            return web.json_response({"error": str(e)}, status=500)

    # ─── File transfer: upload ───────────────────────────

    async def handle_upload(self, request):
        if not self._check_access(request):
            return web.json_response({"error": "Token requerido"}, status=401)
        try:
            reader = await request.multipart()
            field = await reader.next()
            if not field:
                return web.json_response({"error": "No se recibió archivo"}, status=400)
            filename = field.filename or f"file_{int(time.time())}"
            filedata = await field.read()
            safe_name = f"{int(time.time())}_{filename.replace(' ', '_')}"
            filepath = _BMB_DIR / "uploads" / safe_name
            filepath.parent.mkdir(parents=True, exist_ok=True)
            filepath.write_bytes(filedata)
            logger.info(f"📁 Archivo recibido: {safe_name} ({len(filedata)} bytes) type={field.content_type}")
            return web.json_response({
                "status": "ok",
                "filename": safe_name,
                "original_name": filename,
                "size": len(filedata),
                "type": field.content_type or "unknown",
                "url": f"/uploads/{safe_name}",
            })
        except Exception as e:
            logger.error(f"❌ Upload error: {e}")
            return web.json_response({"error": str(e)}, status=500)

    # ─── File transfer: list files ───────────────────────

    async def handle_list_files(self, request):
        from pathlib import Path
        uploads_dir = _BMB_DIR / "uploads"
        if not uploads_dir.exists():
            return web.json_response({"files": []})
        files = []
        for f in sorted(uploads_dir.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True):
            if f.is_file():
                files.append({
                    "name": f.name,
                    "size": f.stat().st_size,
                    "modified": f.stat().st_mtime,
                    "url": f"/uploads/{f.name}",
                })
        return web.json_response({"files": files})

    # ─── File transfer: get file ─────────────────────────

    async def handle_get_file(self, request):
        filename = request.match_info.get("filename", "")
        filepath = _BMB_DIR / "uploads" / filename
        if not filepath.exists() or not filepath.is_file():
            return web.json_response({"error": "Archivo no encontrado"}, status=404)
        return web.FileResponse(filepath)

    # ─── File transfer: delete file ──────────────────────

    async def handle_delete_file(self, request):
        if not self._check_access(request):
            return web.json_response({"error": "Token requerido"}, status=401)
        filename = request.match_info.get("filename", "")
        filepath = _BMB_DIR / "uploads" / filename
        if not filepath.exists():
            return web.json_response({"error": "Archivo no encontrado"}, status=404)
        filepath.unlink()
        logger.info(f"🗑️ Archivo eliminado: {filename}")
        return web.json_response({"status": "deleted", "filename": filename})

    # ─── File transfer: forward a file to another client ──

    async def handle_forward_file(self, request):
        if not self._check_access(request):
            return web.json_response({"error": "Token requerido"}, status=401)
        try:
            body = await request.json()
            filename = body.get("filename", "")
            target = body.get("target", "")  # "android", "windows", o session_id
            filepath = _BMB_DIR / "uploads" / filename
            if not filepath.exists():
                return web.json_response({"error": "Archivo no encontrado"}, status=404)
            # Notificar a todos los WS conectados
            notification = json.dumps({
                "type": "file_received",
                "filename": filename,
                "size": filepath.stat().st_size,
                "url": f"/uploads/{filename}",
                "from": target,
            })
            for cid, ws in list(self.clients.items()):
                try:
                    await ws.send_str(notification)
                except Exception:
                    pass
            return web.json_response({
                "status": "forwarded",
                "filename": filename,
                "clients_notified": len(self.clients),
            })
        except Exception as e:
            return web.json_response({"error": str(e)}, status=500)

    # ─── Tunnel URL detection ──────────────────────────────

    async def _check_tunnel_url(self):
        """Leer tunnel_url.txt si existe (cloudflared escribe ahi)"""
        while True:
            await asyncio.sleep(5)
            if self._tunnel_log_file.exists():
                url = self._tunnel_log_file.read_text().strip()
                if url and url != self.tunnel_url:
                    self.tunnel_url = url
                    self._update_qr()
                    logger.info(f"🌐 Tunnel URL actualizada: {url}")
            # Tambien buscar en variables de entorno
            env_url = _get_env("BMB_TUNNEL_URL", "")
            if env_url and env_url != self.tunnel_url:
                self.tunnel_url = env_url
                self._update_qr()
                logger.info(f"🌐 Tunnel URL desde env: {env_url}")

    def _update_qr(self):
        """Generar QR data con formato JSON que espera la app Android"""
        import json as jsonlib
        local_ip = _get_env('BMB_ADVERTISE_IP', '192.168.1.22')
        self._qr_data = jsonlib.dumps({
            "type": "pairing_request",
            "ip": self.tunnel_url or local_ip,
            "port": self.port,
            "deviceId": "",
            "tunnel_url": self.tunnel_url or "",
            "local_ip": local_ip,
        })
        # Guardar en archivo para depuracion
        qr_file = _BMB_DIR / "qr_data.txt"
        qr_file.write_text(self._qr_data)
        logger.info(f"📱 QR actualizado (JSON): {self._qr_data[:80]}...")

    async def handle_tunnel_refresh(self, request):
        """Devuelve la URL actual del tunnel. La app Android consulta esto cuando pierde conexion."""
        return web.json_response({
            "tunnel_url": self.tunnel_url or "",
            "local_url": f"http://{_get_env('BMB_ADVERTISE_IP', '192.168.1.22')}:{self.port}",
            "port": self.port,
            "token": self._access_token or "",
        })

    # ─── Pagina de emparejamiento (para app Android) ──────

    async def handle_pair_page(self, request):
        return web.Response(
            content_type="text/html",
            text="""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>BMB Emparejado</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body { font-family: system-ui; max-width: 400px; margin: 40px auto; padding: 20px; text-align: center;
       background: #0f0f0f; color: white; }
.card { background: #1a1a2e; border-radius: 16px; padding: 24px; }
.success { color: #22c55e; }
</style></head><body>
<div class="card">
<h1>🕵️ BMB Encover</h1>
<p class="success">✅ Emparejado</p>
<p>App conectada al servidor</p>
</div>
</body></html>"""
        )

    # ─── Pagina principal ───────────────────────────────────

    async def handle_index(self, request):
        return web.Response(
            content_type="text/html",
            text=f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>BMB Encover Server</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body {{ font-family: system-ui; max-width: 600px; margin: 40px auto; padding: 20px; text-align: center; }}
.card {{ background: #f5f5f5; border-radius: 16px; padding: 24px; margin: 16px 0; }}
.btn {{ display: inline-block; background: #5865F2; color: white; padding: 14px 28px; border-radius: 12px;
        text-decoration: none; font-size: 18px; margin: 8px; }}
.qr-img {{ width: 280px; height: 280px; border-radius: 12px; }}
.status {{ color: #22c55e; font-weight: bold; }}
</style></head><body>
<h1>🕵️ BMB Encover</h1>
<p>Servidor v0.5.0 funcionando</p>
<div class="card">
<p class="status">✅ Server activo</p>
<p>🌐 Tunnel: {'<b>' + self.tunnel_url + '</b>' if self.tunnel_url else '⏳ Esperando tunnel...'}</p>
<p>📱 Dispositivos: {len(self.devices)}</p>
</div>
<a class="btn" href="/qr" target="_blank">📱 Escanear QR</a>
<a class="btn" href="/api/pair/token?format=png" target="_blank">🔲 QR PNG</a>
<a class="btn" href="/health" target="_blank">💚 Health</a>
</body></html>"""
        )

    async def handle_qr_page(self, request):
        self._update_qr()
        qr_api_url = f"/api/pair/token?format=png&t={int(time.time())}"
        return web.Response(
            content_type="text/html",
            text=f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>BMB QR - Escanear</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body {{ font-family: system-ui; max-width: 500px; margin: 40px auto; padding: 20px; text-align: center;
       background: #0f0f0f; color: white; }}
h1 {{ color: #5865F2; }}
.qr-box {{ background: white; padding: 20px; border-radius: 20px; display: inline-block; margin: 20px 0; }}
.qr-img {{ width: 300px; height: 300px; }}
.info {{ background: #1a1a2e; padding: 16px; border-radius: 12px; margin: 16px 0; word-break: break-all; }}
.token {{ color: #22c55e; font-size: 14px; }}
.refresh {{ color: #888; font-size: 13px; margin-top: 20px; }}
</style></head><body>
<h1>📱 Escanea con BMB</h1>
<div class="qr-box">
<img class="qr-img" src="{qr_api_url}" alt="QR">
</div>
<div class="info">
<p>🌐 <b id="tunnelUrl">{self.tunnel_url or 'Cargando...'}</b></p>
<p class="token">🔑 Token: bmb2026</p>
<p id="qrData" style="font-size:12px;color:#666;">{self._qr_data[:80]}...</p>
</div>
<p>Abrí la app BMB Android y escaneá este código</p>
<p class="refresh">🔄 La página se actualiza cada 10 segundos</p>
<script>
setInterval(function() {{
    fetch('/api/pair/token').then(r=>r.json()).then(d => {{
        document.getElementById('tunnelUrl').textContent = d.tunnel_url || 'Cargando...';
        document.getElementById('qrData').textContent = d.qr_data || '';
        document.querySelector('.qr-img').src = '/api/pair/token?format=png&t=' + Date.now();
    }});
}}, 10000);
</script>
</body></html>"""
        )

    # ─── Arranque con tunnel check ─────────────────────────

    def run(self):
        logger.info("╔══════════════════════════════════════════════╗")
        logger.info("║     BMB Encover — App API Server v0.5.0     ║")
        logger.info("╠══════════════════════════════════════════════╣")
        logger.info(f"║  REST: http://{self.host}:{self.port}/api/chat     ║")
        logger.info(f"║  WS:   ws://{self.host}:{self.port}/ws            ║")
        logger.info(f"║  Voice:ws://{self.host}:{self.port}/ws/voice      ║")
        logger.info(f"║  📷 Img: http://{self.host}:{self.port}/api/image ║")
        logger.info(f"║  🎤 Aud: http://{self.host}:{self.port}/api/audio ║")
        logger.info(f"║  🔊 TTS: http://{self.host}:{self.port}/api/tts   ║")
        logger.info(f"║  📞 Call:http://{self.host}:{self.port}/api/call  ║")
        logger.info(f"║  📁 Upld:http://{self.host}:{self.port}/api/upload║")
        logger.info(f"║  📂 Files:http://{self.host}:{self.port}/api/files║")
        logger.info(f"║  Pair: http://{self.host}:{self.port}/api/pair    ║")
        logger.info(f"║  QR:   http://{self.host}:{self.port}/qr          ║")
        logger.info(f"║  Auth: {'ON' if self._access_token else 'OFF'} ({len(self.devices)} devices)     ║")
        logger.info(f"║  Agent: {'✅' if self.bmb_agent else '❌'} STT:{'✅' if self.whisper_available else '❌'} TTS:{'✅' if self.tts_available else '❌'} ║")
        logger.info("╚══════════════════════════════════════════════╝")
        self._tunnel_check_task = asyncio.get_event_loop().create_task(self._check_tunnel_url())
        self._update_qr()
        if self._agent_error:
            logger.warning(f"⚠️  {self._agent_error}")
        web.run_app(self.app, host=self.host, port=self.port, print=lambda *a: None)


def main():
    import argparse
    parser = argparse.ArgumentParser(description="BMB Encover App Server v0.4.0")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--verbose", "-v", action="store_true", help="Logs detallados")
    args = parser.parse_args()

    server = AppServer(host=args.host, port=args.port, verbose=args.verbose)
    server.run()


if __name__ == "__main__":
    main()
