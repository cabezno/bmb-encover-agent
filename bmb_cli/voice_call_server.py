"""Sistema de llamadas de voz en tiempo real para BMB.

Conecta apps Flutter (Windows/Android) via WebSocket.
Pipeline: Audio IN → VAD → Whisper → DeepSeek → VibeVoice TTS → Audio OUT

Arquitectura:
  App Flutter ←→ WebSocket (PCM/Opus) ←→ BMB Backend ←→ Whisper + LLM + TTS
"""

import asyncio
import json
import logging
import os
import struct
import time
import uuid
from enum import Enum
from typing import Optional

logger = logging.getLogger("bmb-call")


class CallState(Enum):
    IDLE = "idle"
    LISTENING = "listening"
    PROCESSING = "processing"
    SPEAKING = "speaking"


class CallSession:
    """Sesión de llamada de voz entre un cliente Flutter y BMB."""

    def __init__(self, session_id: str, device_id: str = ""):
        self.session_id = session_id
        self.device_id = device_id
        self.state = CallState.IDLE
        self.ws = None
        
        # Buffers de audio
        self.audio_buffer = bytearray()
        self.speech_detected = False
        self.silence_frames = 0
        
        # Tiempos
        self.created_at = time.time()
        self.last_activity = time.time()
        self.turn_count = 0
        
        # Callbacks
        self.on_audio_out = None

    # ── Pipeline de audio ──────────────────────────────────────────

    async def process_audio_chunk(self, chunk: bytes):
        """Procesar un chunk de audio del cliente (PCM 16kHz mono 16-bit).
        
        Detecta voz, acumula buffer, y cuando detecta fin de habla,
        ejecuta el pipeline completo.
        """
        self.last_activity = time.time()
        
        # Detección simple de actividad de voz (umbral de energía)
        import array
        samples = array.array('h', chunk)
        energy = sum(abs(s) for s in samples) / len(samples) if samples else 0
        
        VAD_THRESHOLD = 500  # Ajustable
        SILENCE_FRAMES_MAX = 20  # ~400ms de silencio = fin de habla

        if energy > VAD_THRESHOLD:
            self.speech_detected = True
            self.silence_frames = 0
            self.audio_buffer.extend(chunk)
            self.state = CallState.LISTENING
        elif self.speech_detected:
            self.silence_frames += 1
            self.audio_buffer.extend(chunk)
            
            if self.silence_frames > SILENCE_FRAMES_MAX:
                # Fin de habla - procesar
                await self._process_turn()
                self.speech_detected = False
                self.silence_frames = 0
                self.audio_buffer = bytearray()

    async def _process_turn(self):
        """Pipeline completo: STT → LLM → TTS."""
        self.state = CallState.PROCESSING
        self.turn_count += 1
        t0 = time.time()
        
        # Notificar al cliente que estamos procesando
        await self._send({"type": "state", "state": "processing"})

        # 1. Guardar buffer a WAV temporal
        import tempfile
        import wave
        tmp = tempfile.mktemp(suffix=".wav")
        with wave.open(tmp, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(16000)
            wf.writeframes(bytes(self.audio_buffer))

        # 2. STT - Whisper
        logger.info(f"[Turno {self.turn_count}] Transcribiendo...")
        try:
            from faster_whisper import WhisperModel
            model = WhisperModel("small", device="cpu", compute_type="int8")
            segments, _ = model.transcribe(tmp, language="es", beam_size=3)
            text = " ".join(seg.text.strip() for seg in segments)
        except Exception as e:
            text = ""
            logger.error(f"STT error: {e}")

        if not text.strip():
            await self._send({"type": "state", "state": "listening"})
            self.state = CallState.LISTENING
            return

        logger.info(f"  Usuario: {text[:100]}")
        await self._send({"type": "transcript", "text": text})

        # 3. LLM - DeepSeek
        logger.info(f"  Procesando con IA...")
        try:
            from openai import OpenAI
            client = OpenAI(
                base_url="https://api.deepseek.com/v1",
                api_key=os.environ.get("DEEPSEEK_API_KEY", ""),
            )
            response = client.chat.completions.create(
                model="deepseek-chat",
                messages=[
                    {"role": "system", "content": "Sos BMB, respondé en español de forma natural y concisa."},
                    {"role": "user", "content": text},
                ],
                max_tokens=300,
            )
            reply = response.choices[0].message.content
        except Exception as e:
            reply = f"Error: {e}"
            logger.error(f"LLM error: {e}")

        logger.info(f"  BMB: {reply[:100]}")
        await self._send({"type": "response_text", "text": reply})

        # 4. TTS - Edge (más rápido, o VibeVoice si está disponible)
        logger.info(f"  Generando voz...")
        output_path = tempfile.mktemp(suffix=".wav")
        
        try:
            import edge_tts
            communicate = edge_tts.Communicate(reply, "es-UY-MateoNeural")
            await communicate.save(output_path)
            
            # Leer el WAV generado y enviar al cliente
            with open(output_path, "rb") as f:
                audio_data = f.read()
            
            await self._send_audio(audio_data)
            logger.info(f"  ✅ Turno completado en {time.time()-t0:.1f}s")
        except Exception as e:
            logger.error(f"TTS error: {e}")

        # Limpiar
        try:
            os.unlink(tmp)
            os.unlink(output_path)
        except Exception:
            pass

        self.state = CallState.LISTENING
        await self._send({"type": "state", "state": "listening"})

    # ── WebSocket messaging ────────────────────────────────────────

    async def _send(self, data: dict):
        """Enviar mensaje JSON al cliente."""
        if self.ws and not self.ws.closed:
            try:
                await self.ws.send_json(data)
            except Exception:
                pass

    async def _send_audio(self, audio_data: bytes):
        """Enviar audio PCM al cliente (precedido de header)."""
        if self.ws and not self.ws.closed:
            try:
                # Header: tipo(4) + tamaño(4) + formato(4) = 12 bytes
                header = struct.pack("!III", 0x4155444F, len(audio_data), 16000)
                await self.ws.send_bytes(header + audio_data)
            except Exception:
                pass

    def get_summary(self) -> dict:
        return {
            "session_id": self.session_id,
            "device_id": self.device_id,
            "state": self.state.value,
            "turns": self.turn_count,
            "uptime": round(time.time() - self.created_at),
        }


# ── WebSocket Handler ─────────────────────────────────────────────

class CallServer:
    """Servidor WebSocket para llamadas de voz."""

    def __init__(self):
        self.sessions: dict[str, CallSession] = {}

    async def handle_ws(self, request):
        """Handle WebSocket connection from Flutter app."""
        from aiohttp import web, WSMsgType
        
        ws = web.WebSocketResponse()
        await ws.prepare(request)

        # Crear sesión
        device_id = request.query.get("device", "unknown")
        session = CallSession(str(uuid.uuid4())[:8], device_id)
        session.ws = ws
        self.sessions[session.session_id] = session

        logger.info(f"📞 Nueva llamada: {session.session_id} (device: {device_id})")
        await ws.send_json({
            "type": "connected",
            "session_id": session.session_id,
            "sample_rate": 16000,
            "format": "pcm_s16le",
        })

        try:
            async for msg in ws:
                session.last_activity = time.time()
                
                if msg.type == WSMsgType.BINARY:
                    # Audio chunk del cliente
                    await session.process_audio_chunk(msg.data)
                    
                elif msg.type == WSMsgType.TEXT:
                    data = json.loads(msg.data)
                    cmd = data.get("type")
                    
                    if cmd == "ping":
                        await ws.send_json({"type": "pong"})
                    elif cmd == "start_call":
                        session.state = CallState.LISTENING
                        await ws.send_json({"type": "state", "state": "listening"})
                    elif cmd == "end_call":
                        logger.info(f"📞 Llamada finalizada: {session.session_id}")
                        break

                elif msg.type == WSMsgType.ERROR:
                    logger.error(f"WS error: {ws.exception()}")

        except Exception as e:
            logger.error(f"Session error {session.session_id}: {e}")
        finally:
            self.sessions.pop(session.session_id, None)
            logger.info(f"📞 Sesión cerrada: {session.session_id}")

        return ws

    def get_status(self) -> dict:
        return {
            "active_calls": len(self.sessions),
            "sessions": [s.get_summary() for s in self.sessions.values()],
        }


# ── Instancia global ──────────────────────────────────────────────

_call_server: Optional[CallServer] = None


def get_call_server() -> CallServer:
    global _call_server
    if _call_server is None:
        _call_server = CallServer()
    return _call_server
