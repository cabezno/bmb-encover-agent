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
            "version": "0.4.0",
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
        ip = _get_env("BMB_ADVERTISE_IP", self.host)
        port = self.port
        access_token = self._access_token

        qr_data = f"bmb://{ip}:{port}/pair?token={token}"
        if access_token:
            qr_data += f"&access={access_token}"

        # Si pide .png, devolver imagen QR
        if request.query.get("format", "") == "png":
            return await self._serve_qr_png(qr_data)

        return web.json_response({
            "token": token,
            "expires_at": self._pairing_tokens[token],
            "ip": ip,
            "port": port,
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

                        chunks = audio_buffers.pop(tab_id, [])
                        stt_text = self._simulate_stt(chunks) if not self.whisper_available else await self._transcribe(chunks)

                        await ws.send_json({"type": "stt_final", "tab_id": tab_id, "text": stt_text})

                        if stt_text and self.bmb_agent:
                            await ws.send_json({"type": "agent_status", "tab_id": tab_id, "status": "thinking"})
                            try:
                                response = await asyncio.to_thread(self.bmb_agent.chat, stt_text)
                                await ws.send_json({
                                    "type": "message",
                                    "tab_id": tab_id,
                                    "text": response,
                                    "session_id": session_id,
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

    def _simulate_stt(self, chunks: list) -> str:
        return ""

    async def _transcribe(self, chunks: list) -> str:
        """Transcribir chunks de audio con Whisper."""
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

    # ─── Arranque ───────────────────────────────────────────────

    def run(self):
        logger.info("╔══════════════════════════════════════════════╗")
        logger.info("║     BMB Encover — App API Server v0.4.0     ║")
        logger.info("╠══════════════════════════════════════════════╣")
        logger.info(f"║  REST: http://{self.host}:{self.port}/api/chat     ║")
        logger.info(f"║  WS:   ws://{self.host}:{self.port}/ws            ║")
        logger.info(f"║  Voice:ws://{self.host}:{self.port}/ws/voice      ║")
        logger.info(f"║  Pair: http://{self.host}:{self.port}/api/pair    ║")
        logger.info(f"║  Auth: {'ON' if self._access_token else 'OFF'} ({len(self.devices)} devices)     ║")
        logger.info(f"║  Agent: {'✅' if self.bmb_agent else '❌'} STT:{'✅' if self.whisper_available else '❌'} TTS:{'✅' if self.tts_available else '❌'} ║")
        logger.info("╚══════════════════════════════════════════════╝")
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
