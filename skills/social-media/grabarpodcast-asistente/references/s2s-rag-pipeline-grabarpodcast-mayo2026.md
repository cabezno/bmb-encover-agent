# Pipeline S2S+RAG para GrabarPodcast (Mayo 2026)

## Arquitectura

```
[Cliente escribe/audio WhatsApp] → Hermes Gateway
  → Whisper (STT local) → texto
  → ChromaDB RAG (79 chunks de grabarpodcast.com) → contexto relevante
  → DeepSeek-chat (LLM) → respuesta contextualizada
  → VibeVoice/CosyVoice 3/XTTS-v2 (TTS) → audio de respuesta
  → WhatsApp (audio nativo)
```

## Componentes

### 1. RAG Index (ChromaDB)
- **Ubicación:** `/tmp/grabarpodcast_chroma/`
- **Embeddings:** all-MiniLM-L6-v2 (sentence-transformers)
- **Chunks:** 79 documentos extraídos de grabarpodcast.com
- **Fuentes:** Tienda (páginas 1-16), Categorías (Podcast/Streaming/Packs), WP REST API pages (inicio, tienda, contacto, términos, carrito, mi-cuenta)
- **Creación:** `python3 /tmp/create_rag_index.py`

### 2. Pipeline completo
- **Script:** `/tmp/s2s_rag_pipeline.py`
- **Uso:** `python3 s2s_rag_pipeline.py --text "consulta del cliente"`
- **Modo audio:** `python3 s2s_rag_pipeline.py /ruta/audio_cliente.wav`
- **Dependencias:** whisper, chromadb, sentence-transformers, requests, vibevoice

### 3. Pipeline S2S simple (Whisper → VibeVoice, sin RAG)
- **Script:** `/tmp/s2s_pipeline.py`
- **Uso:** `python3 s2s_pipeline.py /ruta/audio.wav`

## Rendimiento (CPU, sin GPU, WSL2)

| Componente | Tiempo |
|-----------|--------|
| Whisper (base) | 0.9s para 7s de audio |
| RAG query | 0.1s |
| DeepSeek LLM | 3.4s |
| VibeVoice (7s audio) | 17s |
| **Total pipeline** | ~50s (primera vez, modelos descargados) |

**En GPU (RTX 3060/5070Ti esperado):** <2s total para respuestas cortas.

## Modelos TTS probados

| Modelo | Acento | Clonación | Streaming | RTF CPU | 
|--------|--------|-----------|-----------|---------|
| VibeVoice Realtime-0.5B | Español España (experimental) | ❌ Voces fijas | ✅ ~300ms | 3.3x |
| CosyVoice 3 0.5B | Español ibérico | ✅ Zero-shot | ✅ ~150ms | 6-8x |
| XTTS-v2 | Español genérico | ✅ Zero-shot 6s | ❌ | 2.4x |

## Voz de Santiago clonada

- **Archivo:** `/tmp/santi_voice_prompt.wav` (9.9s, 16kHz)
- **Fuente:** Audio de WhatsApp (aud_9e154676c3f1.ogg)
- **Usado con:** XTTS-v2 y CosyVoice 3 para clonación
- **Nota:** CosyVoice 3 clona el timbre pero impone acento español de España. XTTS-v2 preserva mejor la entonación original.

## Para probar nuevamente

```bash
# Activar entorno
source /tmp/cosyvoice_env/bin/activate  # para CosyVoice 3
source /tmp/vibevoice_env/bin/activate   # para VibeVoice/XTTS

# Probar pipeline con texto
python3 /tmp/s2s_rag_pipeline.py --text "¿Cuánto cuesta grabar un podcast con 2 cámaras?"

# Probar XTTS con voz clonada
python3 -c "
from TTS.api import TTS
import os
os.environ['COQUI_TOS_AGREED'] = '1'
tts = TTS('tts_models/multilingual/multi-dataset/xtts_v2', gpu=False)
tts.tts_to_file(text='Hola bienvenido a GrabarPodcast', file_path='/tmp/test.wav', speaker_wav='/tmp/santi_voice_prompt.wav', language='es')
"
```
