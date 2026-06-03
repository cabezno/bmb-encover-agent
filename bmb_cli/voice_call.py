"""Pipeline de llamadas de voz para BMB.

Orquesta: Audio IN → VAD → Whisper STT → LLM → TTS → Audio OUT

Flujo de llamada:
  IDLE → LISTENING (usuario habla) → THINKING (procesa) → SPEAKING (responde) → LISTENING (sigue)

Integración con gateways:
  - WhatsApp: notas de voz
  - Telegram: mensajes de voz
"""

import asyncio
import json
import logging
import os
import tempfile
import time
import uuid
from enum import Enum
from pathlib import Path
from typing import Optional, Callable

logger = logging.getLogger("bmb-voice-pipeline")


class CallState(Enum):
    IDLE = "idle"
    LISTENING = "listening"
    THINKING = "thinking"
    SPEAKING = "speaking"


class CallSession:
    """Una sesión de llamada de voz completa.

    Maneja el ciclo: escuchar → pensar → hablar → escuchar...
    """

    def __init__(self, session_id: str = None, platform: str = "cli",
                 on_audio_out: Callable = None):
        self.session_id = session_id or str(uuid.uuid4())[:8]
        self.platform = platform  # cli, whatsapp, telegram
        self.state = CallState.IDLE
        self.on_audio_out = on_audio_out  # Callback para enviar audio

        # Contadores
        self.turn_count = 0
        self.total_listening = 0.0
        self.total_thinking = 0.0
        self.total_speaking = 0.0

        logger.info(f"📞 Sesión de llamada creada: {self.session_id}")

    # ── Pipeline completo ──────────────────────────────────────────

    async def process_audio(self, audio_path: str) -> Optional[str]:
        """Pipeline completo: audio → texto → respuesta → audio.

        Args:
            audio_path: Ruta al audio de entrada

        Returns:
            Ruta al audio de respuesta, o None si falla
        """
        self.state = CallState.LISTENING
        self.turn_count += 1
        t0 = time.time()

        # 1. STT - Transcribir
        print(f"\n🎤 [Turno {self.turn_count}] Transcribiendo audio...")
        from bmb_cli.stt import WhisperEngine
        engine = WhisperEngine()
        text = engine.transcribe(audio_path)
        if not text:
            logger.warning("No se detectó voz en el audio")
            self.state = CallState.IDLE
            return None

        print(f"   Usuario: {text[:150]}")
        listening_time = time.time() - t0
        self.total_listening += listening_time

        # 2. THINKING - Procesar con LLM
        self.state = CallState.THINKING
        t1 = time.time()

        print(f"   Procesando respuesta...")
        from openai import OpenAI
        client = OpenAI(
            base_url="https://api.deepseek.com/v1",
            api_key=os.environ.get("DEEPSEEK_API_KEY", ""),
        )

        try:
            response = client.chat.completions.create(
                model="deepseek-chat",
                messages=[
                    {"role": "system", "content": "Sos BMB Undercover Agent, un asistente en español. Respondé de forma natural y conversacional, como en una llamada de voz. Respuestas concisas."},
                    {"role": "user", "content": text},
                ],
                max_tokens=300,
            )
            reply = response.choices[0].message.content
        except Exception as e:
            reply = f"Error: {e}"
            logger.error(f"LLM error: {e}")

        print(f"   BMB: {reply[:150]}")
        thinking_time = time.time() - t1
        self.total_thinking += thinking_time

        # 3. SPEAKING - Generar audio con TTS
        self.state = CallState.SPEAKING
        t2 = time.time()

        output_path = os.path.join(
            tempfile.gettempdir(),
            f"bmb_response_{self.session_id}_{self.turn_count}.mp3"
        )

        print(f"   Generando voz...")
        await _generate_speech(reply, output_path)

        speaking_time = time.time() - t2
        self.total_speaking += speaking_time

        total = time.time() - t0
        print(f"   ✅ Turno completado en {total:.1f}s "
              f"(escucha:{listening_time:.1f} + pensar:{thinking_time:.1f} + hablar:{speaking_time:.1f})")

        self.state = CallState.LISTENING
        return output_path

    def get_summary(self) -> dict:
        """Resumen de la sesión."""
        return {
            "session_id": self.session_id,
            "platform": self.platform,
            "turns": self.turn_count,
            "total_time": {
                "listening": round(self.total_listening, 1),
                "thinking": round(self.total_thinking, 1),
                "speaking": round(self.total_speaking, 1),
            },
            "state": self.state.value,
        }


# ── TTS (reutiliza voice_pipeline) ────────────────────────────────

async def _generate_speech(text: str, output_path: str):
    """Generar audio de respuesta. Intenta VibeVoice, fallback Edge-TTS."""
    cfg = _get_voice_config()
    provider = cfg.get("tts_provider", "edge")

    if provider == "vibevoice":
        try:
            from vibevoice.modular.modeling_vibevoice import VibeVoiceForConditionalGeneration
            from vibevoice.processor import VibeVoiceProcessor
            processor = VibeVoiceProcessor.from_pretrained("microsoft/vibevoice-realtime-0.5b")
            model = VibeVoiceForConditionalGeneration.from_pretrained("microsoft/vibevoice-realtime-0.5b")
            inputs = processor(text=text, return_tensors="pt", voice="es-LATAM")
            audio = model.generate(**inputs)
            import soundfile as sf
            sf.write(output_path, audio[0].numpy(), 24000)
            return
        except Exception as e:
            logger.warning(f"VibeVoice falló, usando Edge: {e}")

    # Fallback Edge-TTS
    import edge_tts
    communicate = edge_tts.Communicate(text, "es-UY-MateoNeural")
    await communicate.save(output_path)


def _get_voice_config() -> dict:
    cfg = {"tts_provider": "edge", "stt_model": "small"}
    try:
        from bmb_cli.config import get_config_value
        cfg["tts_provider"] = get_config_value("voice.tts", "edge")
        cfg["stt_model"] = get_config_value("stt.model", "small")
    except Exception:
        pass
    return cfg


# ── Comandos CLI ──────────────────────────────────────────────────

# Almacén de sesiones activas
_active_sessions: dict[str, CallSession] = {}


def _get_session(session_id: str = None, platform: str = "cli") -> CallSession:
    """Obtener o crear una sesión."""
    if session_id and session_id in _active_sessions:
        return _active_sessions[session_id]
    session = CallSession(session_id=session_id, platform=platform)
    if session_id:
        _active_sessions[session_id] = session
    return session


def cmd_call(args):
    """Iniciar modo llamada: escucha micrófono, procesa, responde."""
    duration = getattr(args, "duration", 10)
    continuous = getattr(args, "continuous", False)
    session = _get_session()

    print("\n╔══════════════════════════════════════╗")
    print("║   BMB Voice Call — Modo llamada     ║")
    print("╚══════════════════════════════════════╝")
    print(f"  Sesión: {session.session_id}")
    print(f"  Duración: {duration}s por turno")
    print(f"  Continuo: {continuous}")
    print()

    try:
        import sounddevice as sd
        import numpy as np
        import wave
    except ImportError:
        print("❌ sounddevice no instalado. pip install sounddevice")
        return

    sample_rate = 16000

    while True:
        # Grabar audio
        print(f"\n🎤 Escuchando ({duration}s)...")
        audio = sd.rec(
            int(duration * sample_rate),
            samplerate=sample_rate,
            channels=1,
            dtype="int16",
        )
        sd.wait()

        # Guardar temporal
        tmp = tempfile.mktemp(suffix=".wav")
        with wave.open(tmp, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            wf.writeframes(audio.tobytes())

        # Pipeline completo
        import asyncio
        loop = asyncio.new_event_loop()
        result = loop.run_until_complete(session.process_audio(tmp))
        loop.close()

        try:
            os.unlink(tmp)
        except Exception:
            pass

        if result:
            print(f"   🔊 Respuesta guardada: {result}")

        if not continuous:
            break

    print(f"\n📊 Resumen de llamada:")
    print(json.dumps(session.get_summary(), indent=2, ensure_ascii=False))


def cmd_call_status(args):
    """Estado de las sesiones de llamada activas."""
    if not _active_sessions:
        print("📞 No hay sesiones activas")
        return

    print(f"\n📞 Sesiones activas ({len(_active_sessions)}):\n")
    for sid, session in _active_sessions.items():
        summary = session.get_summary()
        print(f"  [{sid}] {summary['platform']} - {summary['turns']} turnos - {summary['state']}")


def cmd_call_end(args):
    """Finalizar una sesión de llamada."""
    session_id = getattr(args, "session_id", None)
    if session_id and session_id in _active_sessions:
        session = _active_sessions.pop(session_id)
        print(f"📞 Sesión {session_id} finalizada: {session.turn_count} turnos")
    else:
        _active_sessions.clear()
        print("📞 Todas las sesiones finalizadas")
