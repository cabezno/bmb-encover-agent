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
        # Endpoints para CLI
        self.app.router.add_get("/api/pair/token", self.handle_pair_token)
        self.app.router.add_get("/api/pair/devices", self.handle_pair_devices)
        self.app.router.add_post("/api/pair/revoke", self.handle_pair_revoke)

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
            raw = await request.text()
            body = json.loads(raw) if raw else {}
        except Exception:
            return web.json_response({"error": "JSON inválido"}, status=400)

        if not isinstance(body, dict):
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

    async def handle_pair_token(self, request):
        """GET /api/pair/token — Genera un token fresco para el CLI."""
        info = self.get_pairing_info()
        return web.json_response(info)

    async def handle_pair_devices(self, request):
        """GET /api/pair/devices — Lista dispositivos vinculados."""
        devices = self.list_paired_devices()
        return web.json_response({"devices": devices})

    async def handle_pair_revoke(self, request):
        """POST /api/pair/revoke — Revoca un dispositivo."""
        try:
            raw = await request.text()
            body = json.loads(raw) if raw else {}
        except Exception:
            return web.json_response({"error": "JSON inválido"}, status=400)
        device_id = body.get("device_id", "")
        if not device_id:
            return web.json_response({"error": "device_id requerido"}, status=400)
        if self.revoke_device(device_id):
            return web.json_response({"status": "revoked", "device_id": device_id})
        return web.json_response({"error": "Dispositivo no encontrado"}, status=404)

    def generate_pairing_token(self) -> dict:
        """Generar un token de pairing (para mostrar en QR) y lo registra internamente."""
        token = secrets.token_hex(16)
        expiry = time.time() + 300  # 5 minutos
        self._pairing_tokens[token] = expiry
        logger.info(f"🔑 Token de pairing generado: {token[:8]}... expira en 5 min")
        return {
            "token": token,
            "expires_at": expiry,
            "qr_data": f"bmb://pair?token={token}",
        }

    def get_pairing_info(self) -> dict:
        """Devuelve información de pairing con un token fresco para el CLI."""
        token_info = self.generate_pairing_token()
        return {
            "token": token_info["token"],
            "expires_at": token_info["expires_at"],
            "ip": self.host,
            "port": self.port,
            "qr_data": token_info["qr_data"],
        }

    def list_paired_devices(self) -> list[dict]:
        """Devuelve lista de dispositivos vinculados."""
        return [
            {
                "device_id": dev_id,
                "name": info.get("name", "Desconocido"),
                "type": info.get("type", "?"),
                "paired_at": info.get("paired_at", 0),
                "last_seen": info.get("last_seen", 0),
            }
            for dev_id, info in self.devices.items()
        ]

    def revoke_device(self, device_id: str) -> bool:
        """Revoca un dispositivo vinculado."""
        if device_id in self.devices:
            info = self.devices.pop(device_id)
            self._save_devices()
            logger.info(f"📱 Dispositivo revocado: {info.get('name', device_id)} ({device_id})")
            return True
        return False

    # ─── REST Chat ────────────────────────────────────────────

    async def handle_chat_rest(self, request):
        try:
            raw = await request.text()
            body = json.loads(raw) if raw else {}
        except Exception:
            return web.json_response({"error": "JSON inválido"}, status=400)

        if not isinstance(body, dict):
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

    # ─── WebSocket Chat (multi-tab con streaming) ────────────

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

                        # Procesar con el agente (con streaming)
                        agent = self._get_agent()
                        if agent:
                            try:
                                await ws.send_json({
                                    "type": "typing", "tab_id": tab_id, "is_typing": True
                                })

                                # Callback que envía chunks por WS a medida que se generan
                                full_response_parts = []

                                def stream_chunk_callback(chunk: str):
                                    if chunk:
                                        full_response_parts.append(chunk)
                                        # Encolar en el event loop del hilo principal
                                        asyncio.run_coroutine_threadsafe(
                                            ws.send_json({
                                                "type": "stream_chunk",
                                                "tab_id": tab_id,
                                                "text": chunk,
                                            }),
                                            asyncio.get_event_loop(),
                                        )

                                # Ejecutar el agente en un hilo separado, con stream_callback
                                response = await asyncio.to_thread(
                                    agent.chat, text, stream_callback=stream_chunk_callback
                                )

                                # Enviar fin del stream
                                await ws.send_json({
                                    "type": "stream_end",
                                    "tab_id": tab_id,
                                    "session_id": session_id,
                                })
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

    # ─── WebSocket Voice (Live Mode con STT + TTS simulado) ──

    async def handle_websocket_voice(self, request):
        ws = web.WebSocketResponse()
        await ws.prepare(request)

        device_id = self._verify_device(request)
        session_id = request.query.get("session_id", str(uuid.uuid4()))
        logger.info(f"🎤 WS voice: device={device_id or 'anon'} session={session_id[:8]}")

        # Almacenar chunks de audio para procesar al recibir speech_end
        audio_buffers: dict[str, list[dict]] = {}  # tab_id -> [chunks]

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
                        await self._process_voice_message(ws, tab_id, session_id, text)

                    elif msg_type == "audio_chunk":
                        # Audio chunk recibido — acumular para STT
                        seq = data.get("seq", 0)
                        audio_data = data.get("data", "")
                        if tab_id not in audio_buffers:
                            audio_buffers[tab_id] = []
                        audio_buffers[tab_id].append({"seq": seq, "data": audio_data})
                        if seq == 1:
                            logger.info(f"🎤 audio streaming started for tab={tab_id[:8]}...")
                        # Acuse de recibo cada 10 chunks
                        if seq % 10 == 0:
                            await ws.send_json({
                                "type": "vad_state", "state": "speaking",
                            })

                    elif msg_type == "speech_end":
                        duration = data.get("duration_ms", 0)
                        logger.info(f"🎤 speech end: {duration}ms, chunks accumulated: {len(audio_buffers.get(tab_id, []))}")
                        await ws.send_json({
                            "type": "vad_state", "state": "idle", "duration_ms": duration,
                        })
                        await ws.send_json({
                            "type": "agent_status", "tab_id": tab_id,
                            "status": "thinking",
                        })

                        # 1) Simular Whisper STT: extraer el texto del audio
                        stt_text = self._simulate_whisper_stt(audio_buffers.pop(tab_id, []), duration)
                        logger.info(f"🎤 STT result for tab={tab_id[:8]}: '{stt_text[:80]}...'")

                        # Enviar STT final al cliente
                        await ws.send_json({
                            "type": "stt_final", "tab_id": tab_id, "text": stt_text,
                        })

                        # 2) Procesar con el agente (con streaming)
                        await self._process_voice_message(ws, tab_id, session_id, stt_text, send_audio=True)

                    elif msg_type == "webrtc_offer":
                        # Placeholder para WebRTC real
                        sdp = data.get("sdp", "")
                        logger.info(f"🎤 WebRTC offer received (sdp length: {len(sdp)})")
                        await ws.send_json({
                            "type": "webrtc_answer",
                            "sdp": "placeholder_sdp_answer",
                        })

                    elif msg_type == "ice_candidate":
                        candidate = data.get("candidate", "")
                        logger.info(f"🎤 ICE candidate received: {candidate[:50]}...")

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

    async def _process_voice_message(
        self, ws: web.WebSocketResponse, tab_id: str,
        session_id: str, text: str, send_audio: bool = False,
    ):
        """Procesa un mensaje de texto en el canal de voz, con streaming y TTS simulado."""
        if not text:
            return

        await ws.send_json({
            "type": "agent_status", "tab_id": tab_id, "status": "thinking",
        })

        agent = self._get_agent()
        if not agent:
            await ws.send_json({
                "type": "error", "tab_id": tab_id,
                "text": "Agente no disponible.",
            })
            return

        try:
            # Callback para streaming de texto
            full_response_parts = []

            def stream_chunk_callback(chunk: str):
                if chunk:
                    full_response_parts.append(chunk)
                    asyncio.run_coroutine_threadsafe(
                        ws.send_json({
                            "type": "stream_chunk",
                            "tab_id": tab_id,
                            "text": chunk,
                        }),
                        asyncio.get_event_loop(),
                    )

            response = await asyncio.to_thread(
                agent.chat, text, stream_callback=stream_chunk_callback
            )

            # Enviar fin del stream de texto
            await ws.send_json({
                "type": "stream_end",
                "tab_id": tab_id,
                "session_id": session_id,
            })
            await ws.send_json({
                "type": "message",
                "tab_id": tab_id,
                "text": response,
                "session_id": session_id,
            })

            # Si send_audio=True, simular TTS y enviar audio chunks
            if send_audio and response:
                await self._send_simulated_audio(ws, tab_id, response)

            await ws.send_json({
                "type": "agent_status", "tab_id": tab_id, "status": "listening",
            })

        except Exception as e:
            await ws.send_json({
                "type": "error", "tab_id": tab_id, "text": f"Error: {str(e)}",
            })
            await ws.send_json({
                "type": "agent_status", "tab_id": tab_id, "status": "listening",
            })

    def _simulate_whisper_stt(self, audio_chunks: list[dict], duration_ms: int) -> str:
        """Simula Whisper STT sobre los chunks de audio recibidos.
        En producción, reemplazar con faster-whisper.
        """
        if not audio_chunks:
            return ""
        # Simulación: si los chunks no están vacíos, devolvemos un placeholder
        # En producción, aquí se decodificaría el base64, se pasaría a Whisper,
        # y se devolvería el texto transcrito.
        total_data_len = sum(len(c.get("data", "")) for c in audio_chunks)
        if total_data_len < 10:
            return ""
        # Placeholder: "texto transcrito" simulado
        return "(Transcripción de audio simulada — reemplazar con Whisper)"

    async def _send_simulated_audio(self, ws: web.WebSocketResponse, tab_id: str, text: str):
        """Simula el envío de audio TTS en chunks.
        En producción, reemplazar con un TTS real (e.g., Edge-TTS, Kokoro, etc.).
        """
        import base64

        await ws.send_json({
            "type": "agent_status", "tab_id": tab_id, "status": "speaking",
        })

        logger.info(f"🔊 Enviando audio TTS simulado para tab={tab_id[:8]} ({len(text)} chars)")

        # Simular N chunks de audio silencioso (placeholder)
        # En producción, aquí se llamaría al TTS y se segmentaría en opus
        num_chunks = max(1, min(10, len(text) // 20))
        for seq in range(1, num_chunks + 1):
            # Placeholder: datos de audio simulados (base64 de bytes vacíos con cabecera)
            fake_audio_bytes = b"\x00" * 320  # 20ms de silencio a 16kHz mono 16-bit
            fake_b64 = base64.b64encode(fake_audio_bytes).decode("ascii")

            await ws.send_json({
                "type": "audio_chunk",
                "tab_id": tab_id,
                "data": fake_b64,
                "seq": seq,
            })
            # Pequeña pausa para simuir latencia de streaming
            await asyncio.sleep(0.05)

        logger.info(f"🔊 Audio TTS simulado completado: {num_chunks} chunks")

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
# bump Fri May 15 20:32:16 -03 2026
# force rebuild Fri May 15 22:25:32 -03 2026
