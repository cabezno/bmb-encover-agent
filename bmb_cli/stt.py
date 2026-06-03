"""Módulo STT (Speech-to-Text) para BMB - Whisper local + VAD.

Reconocimiento de voz con faster-whisper, detección de actividad de voz,
y streaming para pipeline de conversación.

Config:
  bmb config set stt.model small      # tiny, base, small, medium, large-v3
  bmb config set stt.language es
  bmb config set stt.device auto       # cuda, cpu, auto
"""

import json
import logging
import os
import time
from pathlib import Path
from typing import Optional, Callable

logger = logging.getLogger("bmb-stt")


# ─── Config ───────────────────────────────────────────────────────

def _get_config() -> dict:
    cfg = {
        "model": "small",
        "language": "es",
        "device": "auto",
        "compute_type": "int8",
        "vad_mode": 1,  # 0-3, 3=most aggressive
    }
    try:
        from bmb_cli.config import get_config_value
        cfg["model"] = get_config_value("stt.model", "small")
        cfg["language"] = get_config_value("stt.language", "es")
        cfg["device"] = get_config_value("stt.device", "auto")
    except Exception:
        pass
    return cfg


def _resolve_device():
    """Determinar device: auto → cuda si disponible, sino cpu."""
    cfg = _get_config()
    if cfg["device"] != "auto":
        return cfg["device"]
    try:
        import torch
        return "cuda" if torch.cuda.is_available() else "cpu"
    except Exception:
        return "cpu"


# ── Whisper Engine ────────────────────────────────────────────────

class WhisperEngine:
    """Wrapper sobre faster-whisper para transcripción.

    Uso:
        engine = WhisperEngine()
        text = engine.transcribe("audio.wav")
        print(text)
    """

    _instance = None
    _model = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        if self._model is not None:
            return
        cfg = _get_config()
        device = _resolve_device()
        model_name = cfg["model"]
        compute = cfg["compute_type"]

        print(f"  → Cargando Whisper ({model_name}) en {device}...")
        t0 = time.time()
        try:
            from faster_whisper import WhisperModel
            self._model = WhisperModel(model_name, device=device, compute_type=compute)
            self._language = cfg["language"]
            logger.info(f"Whisper cargado: {model_name} en {device} ({time.time()-t0:.1f}s)")
            print(f"  ✓ Whisper listo ({time.time()-t0:.1f}s)")
        except ImportError:
            print("  ❌ faster-whisper no instalado. pip install faster-whisper")
            raise
        except Exception as e:
            print(f"  ❌ Error cargando Whisper: {e}")
            raise

    def transcribe(self, audio_path: str, language: str = None) -> str:
        """Transcribir archivo de audio a texto.

        Args:
            audio_path: Ruta al archivo (.wav, .mp3, .ogg)
            language: Código ISO del idioma (opcional, default = config)

        Returns:
            Texto transcrito
        """
        if not Path(audio_path).exists():
            logger.error(f"Audio no encontrado: {audio_path}")
            return ""

        lang = language or self._language
        t0 = time.time()

        try:
            segments, info = self._model.transcribe(
                audio_path,
                language=lang,
                beam_size=3,
                vad_filter=True,
                vad_parameters=dict(
                    min_silence_duration_ms=500,
                    threshold=0.5,
                ),
            )
            text = " ".join(seg.text.strip() for seg in segments)
            elapsed = time.time() - t0
            logger.info(f"Transcripción: {len(text)} chars en {elapsed:.2f}s")
            return text.strip()
        except Exception as e:
            logger.error(f"Error en transcripción: {e}")
            return ""

    def transcribe_bytes(self, audio_bytes: bytes, language: str = None) -> str:
        """Transcribir audio desde bytes (útil para streaming)."""
        import tempfile
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            f.write(audio_bytes)
            tmp_path = f.name

        try:
            return self.transcribe(tmp_path, language)
        finally:
            try:
                os.unlink(tmp_path)
            except Exception:
                pass


# ── Voice Activity Detection ──────────────────────────────────────

class VAD:
    """Voice Activity Detection usando webrtcvad.

    Detecta cuando hay voz hablada en audio. Útil para:
    - Saber cuándo el usuario dejó de hablar
    - Segmentar audio para transcripción
    """

    def __init__(self, mode: int = 1):
        """
        Args:
            mode: 0-3, 3 = más agresivo (menos falsos positivos)
        """
        try:
            import webrtcvad
            self._vad = webrtcvad.Vad(mode)
        except ImportError:
            logger.warning("webrtcvad no instalado, usando VAD simulado")
            self._vad = None

        self._frame_size = 480  # 30ms a 16kHz
        self._sample_rate = 16000
        self._history = []

    def is_speech(self, frame: bytes) -> bool:
        """Detectar si un frame de 30ms contiene voz."""
        if self._vad is None:
            return True  # Si no hay VAD, asumir voz

        if len(frame) != self._frame_size * 2:  # 16-bit samples
            return False

        return self._vad.is_speech(frame, self._sample_rate)

    def detect_end_of_speech(self, frames: list, silence_frames: int = 10) -> bool:
        """Detectar fin de habla después de N frames de silencio.

        Args:
            frames: Lista de frames de audio
            silence_frames: Cuántos frames seguidos de silencio = fin

        Returns:
            True si detecta fin de habla
        """
        if len(frames) < silence_frames:
            return False

        recent = frames[-silence_frames:]
        speech_count = sum(1 for f in recent if self.is_speech(f))

        return speech_count == 0  # Todos en silencio


# ── Comandos CLI ──────────────────────────────────────────────────

def cmd_listen(args):
    """Escuchar desde micrófono, transcribir y devolver texto."""
    duration = getattr(args, "duration", 5)
    device = getattr(args, "device", None)

    print(f"\n🎤 Escuchando ({duration}s)...")

    try:
        import sounddevice as sd
        import numpy as np
    except ImportError:
        print("❌ sounddevice no instalado. pip install sounddevice")
        return

    # Config
    sample_rate = 16000
    channels = 1

    # Grabar
    try:
        audio = sd.rec(
            int(duration * sample_rate),
            samplerate=sample_rate,
            channels=channels,
            dtype="int16",
            device=device,
        )
        sd.wait()
    except Exception as e:
        print(f"❌ Error grabando: {e}")
        return

    print("  ✓ Audio capturado. Transcribiendo...")

    # Guardar temporal y transcribir
    import tempfile
    import wave

    tmp = tempfile.mktemp(suffix=".wav")
    with wave.open(tmp, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(audio.tobytes())

    engine = WhisperEngine()
    text = engine.transcribe(tmp)

    try:
        os.unlink(tmp)
    except Exception:
        pass

    if text:
        print(f"\n📝 Transcripción:\n{text}")
    else:
        print("\n❌ No se detectó voz")

    return text


def cmd_install_deps(args):
    """Instalar dependencias de STT."""
    print("→ Instalando dependencias STT...")
    import subprocess
    deps = [
        "faster-whisper",
        "sounddevice",
        "webrtcvad",
        "numpy",
        "scipy",
    ]
    for dep in deps:
        print(f"  Instalando {dep}...")
        r = subprocess.run(["pip", "install", dep], capture_output=True, text=True)
        if r.returncode == 0:
            print(f"  ✓ {dep}")
        else:
            print(f"  ❌ {dep}: {r.stderr[:100]}")
    print("\n✅ Instalación completada")
