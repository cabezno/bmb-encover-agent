"""
BMB Encover — App API Server v0.3.0

Server WebSocket + REST para las apps mobile/desktop de BMB.
Protocolo alineado con la app Flutter (bmb_app/).

Endpoints:
- GET  /health              — health check
- POST /api/pair            — QR pairing (recibe token, devuelve api_key)
- POST /api/chat            — REST chat request-response
- GET  /api/sessions        — listar sesiones activas
- WS   /ws                  — WebSocket chat multi-tab
- WS   /ws/voice            — WebSocket live mode (voz)

Protocolo WebSocket (/ws):
  Cliente → Servidor:
    {"type": "message", "tab_id": "...", "text": "...", "session_id": "..."}
    {"type": "ping"}
    {"type": "set_model", "model": "..."}

  Servidor → Cliente:
    {"type": "connected", "session_id": "...", "message": "..."}
    {"type": "message", "tab_id": "...", "text": "...", "session_id": "..."}
    {"type": "status", "tab_id": "...", "status": "processing|idle|error"}
    {"type": "typing", "tab_id": "...", "is_typing": true}
    {"type": "stream_chunk", "tab_id": "...", "text": "..."}
    {"type": "stream_end", "tab_id": "...", "session_id": "..."}
    {"type": "error", "tab_id": "...", "text": "..."}
    {"type": "pong"}

Protocolo WebSocket (/ws/voice):
  (igual que /ws pero con soporte de chunks de audio)
  Cliente → Servidor:
    {"type": "message", "tab_id": "...", "text": "...", "session_id": "..."}
    {"type": "audio_chunk", "tab_id": "...", "data": "<opus_base64>", "seq": 1}
    {"type": "speech_end", "tab_id": "...", "duration_ms": 3200}
    {"type": "webrtc_offer", "sdp": "..."}
    {"type": "ice_candidate", "candidate": "..."}

  Servidor → Cliente:
    (los mismos que /ws +)
    {"type": "vad_state", "state": "speaking|idle", "duration_ms": ...}
    {"type": "stt_partial", "tab_id": "...", "text": "..."}
    {"type": "stt_final", "tab_id": "...", "text": "..."}
    {"type": "agent_status", "tab_id": "...", "status": "thinking|speaking|listening"}
    {"type": "audio_chunk", "tab_id": "...", "data": "<opus_base64>", "seq": 1}

Arrancar:
  python3 app_server.py --port 8643
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
from pathlib import Path
from typing import Optional

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


class AppServer:
    def __init__(self, host: str = DEFAULT_HOST, port: int = DEFAULT_PORT):
        self.host = host
        self.port = port
        self.app = web.Application()
        self.clients: dict[str, web.WebSocketResponse] = {}  # device_id -> ws
        self.sessions: dict[str, dict] = {}  # session_id -> metadata
        self.tabs: dict[str, dict] = {}  # tab_id -> {device_id, messages, session_id, status}
        self.devices: dict[str, dict] = {}  # device_id -> {api_key, name, type, paired_at}
        self.bmb_agent = None
        self._pairing_tokens: dict[str, float] = {}  # token -> expiry
        self.setup_routes()
        self._load_devices()

    def setup_routes(self):
        self.app.router.add_get("/health", self.handle_health)
        self.app.router.add_post("/api/pair", self.handle_pair)
        self.app.router.add_post("/api/chat", self.handle_chat_rest)
        self.app.router.add_get("/api/sessions", self.handle_list_sessions)
        self.app.router.add_get("/ws", self.handle_websocket_chat)
        self.app.router.add_get("/ws/voice", self.handle_websocket_voice)

    # ─── Auth helpers ─────────────────────────────────────────

    def _load_devices(self):
        """Cargar dispositivos vinculados desde disco."""
        if AUTH_FILE.exists():
            try:
                data = json.loads(AUTH_FILE.read_text())
                self.devices = data.get("devices", {})
                logger.info(f"📱 {len(self.devices)} dispositivos cargados")
            except Exception:
                self.devices = {}

    def _save_devices(self):
        """Guardar dispositivos vinculados a disco."""
        AUTH_FILE.parent.mkdir(parents=True, exist_ok=True)
        AUTH_FILE.write_text(json.dumps({"devices": self.devices}, indent=2))

    def _generate_api_key(self) -> str:
        return f"bmb_{secrets.token_hex(32)}"

    def _verify_device(self, request) -> Optional[str]:
        """Verificar api_key en query params o headers. Devuelve device_id o None."""
        api_key = request.query.get("api_key", "") or request.headers.get("X-API-Key", "")
        for dev_id, dev_info in self.devices.items():
            if dev_info.get("api_key") == api_key:
                return dev_id
        return None

    def _get_agent(self):
        if self.bmb_agent is None:
            logger.info("🔄 Inicializando agente BMB...")
            try:
                from bmb_cli.config import load_config
                from bmb_cli.env_loader import load_bmb_dotenv

                load_bmb_dotenv()
                config = load_config()
                provider_cfg = config.get("provider", {})
                base_url = provider_cfg.get("base_url", os.environ.get("DEEPSEEK_API_URL", "https://api.deepseek.com/v1"))
                api_key = provider_cfg.get("api_key", os.environ.get("DEEPSEEK_API_KEY", ""))
                model = provider_cfg.get("model", "deepseek-chat")

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
                )
                logger.info(f"✅ Agente BMB: model={model}")
            except Exception as e:
                logger.error(f"❌ Error al inicializar agente: {e}")
                logger.error(traceback.format_exc())
                return None
        return self.bmb_agent

    # ─── Health ───────────────────────────────────────────────

    async def handle_health(self, request):
        return web.json_response({
            "status": "ok",
            "version": "0.3.0",
            "name": "BMB Encover App Server",
            "clients_connected": len(self.clients),
            "sessions_active": len(self.sessions),
            "tabs_active": len(self.tabs),
            "devices_paired": len(self.devices),
            "agent_ready": self.bmb_agent is not None,
        })

    # ─── Pairing ──────────────────────────────────────────────

    async def handle_pair(self, request):
        """POST /api/pair — QR pairing handshake."""
        try:
            body = await request.json()
        except Exception:
            return web.json_response({"error": "JSON inválido"}, status=400)

        if not isinstance(body, dict):
            try:
                raw = await request.text()
                body = json.loads(raw)
            except Exception:
                return web.json_response({"error": "JSON inválido"}, status=400)

        token = body.get("token", "")
        device_name = body.get("device_name", "Unknown")
        device_type = body.get("device_type", "unknown")

        # Verificar token
        if token not in self._pairing_tokens:
            return web.json_response({"error": "Token inválido o expirado"}, status=401)

        if time.time() > self._pairing_tokens[token]:
            del self._pairing_tokens[token]
            return web.json_response({"error": "Token expirado (5 min)"}, status=401)

        # Token válido — generar API key permanente
        del self._pairing_tokens[token]
        device_id = str(uuid.uuid4())[:8]
        api_key = self._generate_api_key()

        self.devices[device_id] = {
            "api_key": api_key,
            "name": device_name,
            "type": device_type,
            "paired_at": time.time(),
            "last_seen": time.time(),
        }
        self._save_devices()

        logger.info(f"📱 Dispositivo vinculado: {device_name} ({device_id})")
        return web.json_response({
            "status": "paired",
            "api_key": api_key,
            "device_id": device_id,
            "agent_name": "BMB Encover",
        })

    @staticmethod
    def generate_pairing_token() -> dict:
        """Generar un token de pairing (para mostrar en QR)."""
        token = secrets.token_hex(16)
        expiry = time.time() + 300  # 5 minutos
        return {"token": token, "expires_at": expiry, "qr_data": f"bmb://pair?token={token}"}

    # ─── REST Chat ────────────────────────────────────────────

    async def handle_chat_rest(self, request):
        try:
            body = await request.json()
        except Exception:
            return web.json_response({"error": "JSON inválido"}, status=400)

        if not isinstance(body, dict):
            body = dict(await request.post())
            if not body:
                # Último intento: leer raw
                try:
                    raw = await request.text()
                    body = json.loads(raw)
                except Exception:
                    return web.json_response({"error": "JSON inválido"}, status=400)

        message = body.get("message", "").strip()
        session_id = body.get("session_id", str(uuid.uuid4()))
        tab_id = body.get("tab_id", "default")

        if not message:
            return web.json_response({"error": "Mensaje vacío"}, status=400)

        logger.info(f"📩 REST: tab={tab_id[:8]} msg='{message[:50]}...'")
        agent = self._get_agent()
        if agent is None:
            return web.json_response({"error": "Agente no disponible"}, status=503)

        try:
            response = await asyncio.to_thread(agent.chat, message)

            # Registrar en sesión
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
                "model": agent.model,
            })
        except Exception as e:
            logger.error(f"❌ Error: {e}")
            return web.json_response({"error": str(e)}, status=500)

    async def handle_list_sessions(self, request):
        sessions_list = [
            {
                "id": sid,
                "created": meta.get("created", 0),
                "tabs": len(meta.get("tabs", {})),
            }
            for sid, meta in self.sessions.items()
        ]
        return web.json_response({"sessions": sessions_list})

    # ─── WebSocket Chat (multi-tab) ───────────────────────────

    async def handle_websocket_chat(self, request):
        ws = web.WebSocketResponse()
        await ws.prepare(request)

        # Verificar device (si tiene api_key)
        device_id = self._verify_device(request)
        session_id = request.query.get("session_id", str(uuid.uuid4()))

        self.clients[device_id or session_id] = ws
        logger.info(f"🔗 WS chat: device={device_id or 'anon'} session={session_id[:8]}")

        await ws.send_json({
            "type": "connected",
            "session_id": session_id,
            "device_id": device_id or "",
            "message": "Conectado a BMB Encover Agent",
        })

        try:
            async for msg in ws:
                if msg.type == WSMsgType.TEXT:
                    data = json.loads(msg.data)
                    msg_type = data.get("type", "")
                    tab_id = data.get("tab_id", "default")

                    if msg_type == "message":
                        text = data.get("text", "").strip()
                        if not text:
                            continue

                        logger.info(f"💬 tab={tab_id[:8]} '{text[:50]}...'")

                        # Actualizar estado de la tab a processing
                        self.tabs[tab_id] = {
                            "device_id": device_id,
                            "session_id": session_id,
                            "status": "processing",
                            "last_message": text,
                        }
                        await ws.send_json({
                            "type": "status", "tab_id": tab_id, "status": "processing"
                        })

                        # Procesar con el agente
                        agent = self._get_agent()
                        if agent:
                            try:
                                await ws.send_json({
                                    "type": "typing", "tab_id": tab_id, "is_typing": True
                                })

                                response = await asyncio.to_thread(agent.chat, text)

                                await ws.send_json({
                                    "type": "message",
                                    "tab_id": tab_id,
                                    "text": response,
                                    "session_id": session_id,
                                })
                                await ws.send_json({
                                    "type": "typing", "tab_id": tab_id, "is_typing": False
                                })
                                self.tabs[tab_id]["status"] = "idle"
                            except Exception as e:
                                await ws.send_json({
                                    "type": "error", "tab_id": tab_id,
                                    "text": f"Error: {str(e)}",
                                })
                                self.tabs[tab_id]["status"] = "error"
                        else:
                            await ws.send_json({
                                "type": "error", "tab_id": tab_id,
                                "text": "Agente no disponible. Configure un modelo primero.",
                            })

                    elif msg_type == "ping":
                        await ws.send_json({"type": "pong"})

                    elif msg_type == "set_model":
                        new_model = data.get("model", "")
                        if new_model and self.bmb_agent:
                            self.bmb_agent.model = new_model
                            logger.info(f"🔧 Modelo cambiado: {new_model}")
                            await ws.send_json({"type": "model_changed", "model": new_model})

        except asyncio.CancelledError:
            pass
        except Exception as e:
            logger.error(f"❌ WS exception: {e}")
        finally:
            self.clients.pop(device_id or session_id, None)
            logger.info(f"🔌 WS desconectado")

        return ws

    # ─── WebSocket Voice (Live Mode) ──────────────────────────

    async def handle_websocket_voice(self, request):
        ws = web.WebSocketResponse()
        await ws.prepare(request)

        device_id = self._verify_device(request)
        session_id = request.query.get("session_id", str(uuid.uuid4()))
        logger.info(f"🎤 WS voice: device={device_id or 'anon'} session={session_id[:8]}")

        # Añadir cliente también al pool de chat (para recibir mensajes de texto)
        self.clients[device_id or f"voice_{session_id}"] = ws

        await ws.send_json({
            "type": "connected",
            "session_id": session_id,
            "device_id": device_id or "",
            "message": "Live mode conectado. Decime algo y te respondo.",
        })

        await ws.send_json({
            "type": "agent_status", "tab_id": "live",
            "status": "listening",
        })

        try:
            async for msg in ws:
                if msg.type == WSMsgType.TEXT:
                    data = json.loads(msg.data)
                    msg_type = data.get("type", "")
                    tab_id = data.get("tab_id", "live")

                    if msg_type == "message":
                        # Mensaje de texto durante live mode
                        text = data.get("text", "").strip()
                        if not text:
                            continue

                        logger.info(f"🎤 voice text: '{text[:50]}...'")
                        await ws.send_json({
                            "type": "agent_status", "tab_id": tab_id,
                            "status": "thinking",
                        })

                        agent = self._get_agent()
                        if agent:
                            try:
                                response = await asyncio.to_thread(agent.chat, text)
                                await ws.send_json({
                                    "type": "message", "tab_id": tab_id,
                                    "text": response, "session_id": session_id,
                                })
                            except Exception as e:
                                await ws.send_json({
                                    "type": "error", "tab_id": tab_id,
                                    "text": f"Error: {str(e)}",
                                })

                        await ws.send_json({
                            "type": "agent_status", "tab_id": tab_id,
                            "status": "listening",
                        })

                    elif msg_type == "audio_chunk":
                        # Audio chunk recibido (para STT futuro)
                        seq = data.get("seq", 0)
                        audio_data = data.get("data", "")
                        if seq == 1:
                            logger.info(f"🎤 audio streaming started...")

                        # Response temporal: acuse de recibo
                        if seq % 10 == 0:
                            await ws.send_json({
                                "type": "vad_state", "state": "speaking",
                            })

                    elif msg_type == "speech_end":
                        duration = data.get("duration_ms", 0)
                        logger.info(f"🎤 speech end: {duration}ms")
                        await ws.send_json({
                            "type": "vad_state", "state": "idle", "duration_ms": duration,
                        })
                        await ws.send_json({
                            "type": "agent_status", "tab_id": tab_id,
                            "status": "thinking",
                        })

                        # TODO: Aquí iría Whisper STT + agente + TTS
                        # Por ahora simulamos respuesta
                        await asyncio.sleep(1)
                        await ws.send_json({
                            "type": "message", "tab_id": tab_id,
                            "text": "Escuché algo. (STT + agente próximamente)",
                            "session_id": session_id,
                        })
                        await ws.send_json({
                            "type": "agent_status", "tab_id": tab_id,
                            "status": "listening",
                        })

                    elif msg_type == "ping":
                        await ws.send_json({"type": "pong"})

        except asyncio.CancelledError:
            pass
        except Exception as e:
            logger.error(f"❌ WS voice exception: {e}")
        finally:
            key = device_id or f"voice_{session_id}"
            self.clients.pop(key, None)
            logger.info(f"🔌 WS voice desconectado")

        return ws

    # ─── Arranque ─────────────────────────────────────────────

    def run(self):
        logger.info("╔══════════════════════════════════════════════╗")
        logger.info("║     BMB Encover — App API Server v0.3.0     ║")
        logger.info("╠══════════════════════════════════════════════╣")
        logger.info(f"║  REST: http://{self.host}:{self.port}/api/chat     ║")
        logger.info(f"║  WS:   ws://{self.host}:{self.port}/ws            ║")
        logger.info(f"║  Voice:ws://{self.host}:{self.port}/ws/voice      ║")
        logger.info(f"║  Pair: http://{self.host}:{self.port}/api/pair    ║")
        logger.info(f"║  Devices:{len(self.devices)} / Tabs:{len(self.tabs)}         ║")
        logger.info("╚══════════════════════════════════════════════╝")
        web.run_app(self.app, host=self.host, port=self.port, print=lambda *a: None)


def main():
    import argparse
    parser = argparse.ArgumentParser(description="BMB Encover App Server")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    args = parser.parse_args()
    AppServer(host=args.host, port=args.port).run()


if __name__ == "__main__":
    main()
