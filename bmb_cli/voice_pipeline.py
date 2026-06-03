"""Pipeline de voz para BMB: Whisper STT + RAG + LLM + VibeVoice/Edge TTS.

Flujo:
  [Audio] → Whisper STT → RAG (consulta conocimientos) → LLM (responde) → TTS streaming → [Audio]

Configuración:
  bmb config set voice.stt local|openai
  bmb config set voice.tts edge|vibevoice|gemini
  bmb config set voice.rag_dir ~/.bmb/knowledge/
"""

import json
import logging
import os
import tempfile
import time
from pathlib import Path

logger = logging.getLogger("bmb-voice")

# ── Config ───────────────────────────────────────────────────────

def _get_config() -> dict:
    cfg = {
        "stt_provider": "local",      # local (whisper), openai
        "tts_provider": "edge",       # edge, vibevoice, gemini
        "rag_dir": str(Path.home() / ".bmb" / "knowledge"),
        "llm_model": "",              # vacío = usa el modelo default de BMB
    }
    try:
        from bmb_cli.config import get_config_value
        cfg["stt_provider"] = get_config_value("voice.stt", "local")
        cfg["tts_provider"] = get_config_value("voice.tts", "edge")
        cfg["rag_dir"] = get_config_value("voice.rag_dir", cfg["rag_dir"])
    except Exception:
        pass
    return cfg


# ── STT: Whisper ─────────────────────────────────────────────────

def _transcribe_local(audio_path: str) -> str:
    """Transcribir audio con Whisper local (faster-whisper)."""
    try:
        from faster_whisper import WhisperModel
    except ImportError:
        print("❌ faster-whisper no instalado. pip install faster-whisper")
        return ""

    print(f"  → Transcribiendo audio con Whisper local...")
    model = WhisperModel("base", device="cpu", compute_type="int8")
    segments, info = model.transcribe(audio_path, language="es", beam_size=3)
    text = " ".join(seg.text for seg in segments)
    print(f"  ✓ Transcripción: {text[:100]}{'...' if len(text) > 100 else ''}")
    return text.strip()


def _transcribe_openai(audio_path: str) -> str:
    """Transcribir con OpenAI Whisper API."""
    try:
        from openai import OpenAI
    except ImportError:
        print("❌ openai no instalado")
        return ""

    client = OpenAI()
    print(f"  → Transcribiendo audio con OpenAI Whisper API...")
    with open(audio_path, "rb") as f:
        transcript = client.audio.transcriptions.create(
            model="whisper-1", file=f, language="es"
        )
    text = transcript.text.strip()
    print(f"  ✓ Transcripción: {text[:100]}{'...' if len(text) > 100 else ''}")
    return text


def transcribe(audio_path: str) -> str:
    """Elegir STT según configuración."""
    cfg = _get_config()
    provider = cfg["stt_provider"]

    if provider == "openai":
        return _transcribe_openai(audio_path)
    else:
        return _transcribe_local(audio_path)


# ── RAG ──────────────────────────────────────────────────────────

def _load_knowledge() -> str:
    """Cargar documentos de conocimiento desde el directorio RAG."""
    cfg = _get_config()
    rag_dir = Path(cfg["rag_dir"])

    if not rag_dir.exists():
        return ""

    docs = []
    for f in rag_dir.glob("*.txt") or rag_dir.glob("*.md"):
        try:
            docs.append(f.read_text(encoding="utf-8").strip())
        except Exception:
            pass

    if docs:
        return "\n\n---\n\n".join(docs)
    return ""


def query_rag(query: str) -> str:
    """Consulta simple RAG: busca keywords en los documentos."""
    knowledge = _load_knowledge()
    if not knowledge:
        return ""

    # Búsqueda simple por palabras clave
    query_lower = query.lower()
    words = set(query_lower.split())
    chunks = knowledge.split("\n\n---\n\n")
    relevant = []

    for chunk in chunks:
        chunk_lower = chunk.lower()
        matches = sum(1 for w in words if w in chunk_lower)
        if matches > 0:
            relevant.append((matches, chunk))

    relevant.sort(reverse=True)
    top = relevant[:3]
    if top:
        return "\n\n".join(r[1][:500] for r in top)
    return ""


# ── TTS: Edge / VibeVoice ────────────────────────────────────────

async def _tts_edge(text: str, output_path: str):
    """Generar audio con Edge-TTS (async)."""
    import edge_tts

    print(f"  → Generando audio con Edge-TTS (MateoNeural)...")
    voice = "es-UY-MateoNeural"
    communicate = edge_tts.Communicate(text, voice)
    await communicate.save(output_path)
    print(f"  ✓ Audio guardado: {output_path}")

async def _tts_vibevoice(text: str, output_path: str):
    """Generar audio con VibeVoice Realtime."""
    try:
        from vibevoice.modular.modeling_vibevoice_streaming_inference import (
            VibeVoiceStreamingForConditionalGenerationInference,
        )
        from vibevoice.processor.vibevoice_streaming_processor import (
            VibeVoiceStreamingProcessor,
        )

        print(f"  → Generando audio con VibeVoice Realtime...")
        processor = VibeVoiceStreamingProcessor.from_pretrained(
            "microsoft/vibevoice-realtime-0.5b"
        )
        model = VibeVoiceStreamingForConditionalGenerationInference.from_pretrained(
            "microsoft/vibevoice-realtime-0.5b"
        )
        # Formato Speaker 0: texto (requerido por VibeVoice)
        formatted = f"Speaker 0: {text}"
        inputs = processor(text=formatted, return_tensors="pt")
        audio = model.generate(**inputs)
        import soundfile as sf
        sf.write(output_path, audio[0].numpy(), 24000)
        print(f"  ✓ Audio guardado (VibeVoice): {output_path}")
    except ImportError:
        print(f"  ⚠️ VibeVoice no instalado. Usando Edge-TTS.")
        await _tts_edge(text, output_path)
    except Exception as e:
        print(f"  ❌ Error VibeVoice: {e}")
        await _tts_edge(text, output_path)


async def _async_tts(text: str, output_path: str):
    """Async wrapper para TTS."""
    cfg = _get_config()
    provider = cfg["tts_provider"]

    if provider == "vibevoice":
        await _tts_vibevoice(text, output_path)
    else:
        await _tts_edge(text, output_path)


def tts(text: str, output_path: str = None) -> str:
    """Generar audio desde texto. Devuelve path del archivo."""
    if not output_path:
        output_path = rf"C:\Users\Pc Nasa\Desktop\BMB\bmb_voice_{int(time.time())}.mp3"
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)

    import asyncio
    try:
        asyncio.run(_async_tts(text, output_path))
    except RuntimeError:
        loop = asyncio.new_event_loop()
        loop.run_until_complete(_async_tts(text, output_path))
        loop.close()

    return output_path


# ── Comandos CLI ─────────────────────────────────────────────────

def cmd_transcribe(args):
    """Transcribir un archivo de audio."""
    audio_path = args.audio
    if not Path(audio_path).exists():
        print(f"❌ Archivo no encontrado: {audio_path}")
        return

    print(f"\n🎤 Transcribiendo: {audio_path}")
    text = transcribe(audio_path)
    if text:
        print(f"\n📝 Transcripción:\n{text}")


def cmd_speak(args):
    """Convertir texto a audio."""
    text = args.text
    output = getattr(args, "output", None)

    print(f"\n🔊 Generando audio para: {text[:80]}{'...' if len(text) > 80 else ''}")
    path = tts(text, output)
    print(f"\n✅ Audio guardado: {path}")


def cmd_converse(args):
    """Pipeline completo: STT → RAG → LLM → TTS."""
    audio_path = args.audio
    if not Path(audio_path).exists():
        print(f"❌ Archivo no encontrado: {audio_path}")
        return

    print("\n╔══════════════════════════════════════╗")
    print("║   BMB Voice — Pipeline completo     ║")
    print("╚══════════════════════════════════════╝")
    print()

    # 1. STT
    print("🎤 [1/4] Transcripción de audio...")
    text = transcribe(audio_path)
    if not text:
        print("❌ No se pudo transcribir el audio")
        return

    # 2. RAG
    print(f"\n📚 [2/4] Consultando base de conocimiento...")
    context = query_rag(text)
    if context:
        print(f"  ✓ Contexto relevante encontrado ({len(context)} chars)")
    else:
        print(f"  - Sin contexto RAG configurado")

    # 3. LLM
    print(f"\n🤖 [3/4] Generando respuesta con IA...")
    system_prompt = "Eres un asistente útil. Respondé en español de Uruguay."
    if context:
        system_prompt += f"\n\nContexto:\n{context}"

    # Llamar al LLM de BMB
    try:
        from openai import OpenAI
        # Usar DeepSeek como provider por defecto
        client = OpenAI(
            base_url="https://api.deepseek.com/v1",
            api_key=os.environ.get("DEEPSEEK_API_KEY", ""),
        )
        response = client.chat.completions.create(
            model="deepseek-chat",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": text},
            ],
            max_tokens=500,
        )
        respuesta = response.choices[0].message.content
        print(f"  ✓ Respuesta: {respuesta[:100]}{'...' if len(respuesta) > 100 else ''}")
    except Exception as e:
        respuesta = f"Error generando respuesta: {e}"
        print(f"  ❌ {respuesta}")

    # 4. TTS
    print(f"\n🔊 [4/4] Generando audio de respuesta...")
    output_path = rf"C:\Users\Pc Nasa\Desktop\BMB\bmb_voice_{int(time.time())}.mp3"
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    tts(respuesta, output_path)
    print(f"\n✅ Pipeline completo!")
    print(f"   Transcripción: {text}")
    print(f"   Respuesta: {respuesta[:200]}")
    print(f"   Audio: {output_path}")


def cmd_rag_add(args):
    """Agregar un documento a la base de conocimiento RAG."""
    file_path = args.file
    if not Path(file_path).exists():
        print(f"❌ Archivo no encontrado: {file_path}")
        return

    cfg = _get_config()
    rag_dir = Path(cfg["rag_dir"])
    rag_dir.mkdir(parents=True, exist_ok=True)

    dest = rag_dir / Path(file_path).name
    import shutil
    shutil.copy2(file_path, dest)
    print(f"✅ Documento agregado al conocimiento: {dest}")


def cmd_rag_list(args):
    """Listar documentos en la base de conocimiento."""
    cfg = _get_config()
    rag_dir = Path(cfg["rag_dir"])

    if not rag_dir.exists():
        print("📚 Base de conocimiento vacía")
        return

    files = list(rag_dir.glob("*"))
    if not files:
        print("📚 Base de conocimiento vacía")
        return

    print(f"\n📚 Documentos en base de conocimiento ({len(files)}):\n")
    for f in files:
        size = f.stat().st_size
        print(f"  📄 {f.name} ({size/1024:.1f} KB)")
