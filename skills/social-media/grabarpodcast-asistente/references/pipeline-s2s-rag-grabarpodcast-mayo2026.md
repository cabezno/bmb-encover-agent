# Pipeline S2S+RAG para GrabarPodcast (Mayo 2026)

Pipeline completo: Whisper (STT) → ChromaDB RAG → DeepSeek (LLM) → VibeVoice (TTS)

## Componentes

### 1. RAG — ChromaDB con sentence-transformers

```bash
# Índice creado en /tmp/grabarpodcast_chroma/
# 79 chunks de ~43 archivos extraídos de grabarpodcast.com
# Incluye: tienda (144 productos), categorías, páginas WP, packs con descuento
```

**Código:** `/tmp/create_rag_index.py`
**Datos:** `/tmp/grabarpodcast_rag/` (43 archivos .txt scrapeados)
**Embeddings:** `all-MiniLM-L6-v2` (~80MB)

### 2. Pipeline completo

**Script:** `/tmp/s2s_rag_pipeline.py`
**Uso:**
```bash
python3 s2s_rag_pipeline.py --text "consulta del cliente"
python3 s2s_rag_pipeline.py /ruta/audio.wav
```

**Flujo:**
1. STT (Whisper base) → texto
2. RAG (ChromaDB) → recupera 5 documentos relevantes
3. LLM (DeepSeek via API) → genera respuesta con contexto
4. TTS (VibeVoice sp-Spk1_man) → genera audio

**Rendimiento en CPU (sin GPU):**
- RAG query: ~4.3s
- STT (Whisper base): ~15s carga, ~1s transcripción
- LLM (DeepSeek): ~3.4s
- TTS (VibeVoice): ~4-17s según texto
- Total: ~50-170s para respuestas de 6-48s de audio

### 3. VibeVoice — Todas las voces generadas

**Directorio:** `/tmp/vibevoice_all_voices/` (25 archivos .wav)
**Script de generación:** `/tmp/gen_all_voices.py`

Voces disponibles:
- Español: sp-Spk0_woman, sp-Spk1_man
- Portugués: pt-Spk0_woman, pt-Spk1_man
- Inglés: en-Carter, en-Davis, en-Emma, en-Frank, en-Grace, en-Mike
- Alemán, Francés, Italiano, Japonés, Coreano, Holandés, Polaco, Hindi

### 4. VibeVoice tuning para español

**Script:** `/tmp/tune_spanish_voice.py`
**Pruebas:** `/tmp/vibevoice_tuning/` (8 archivos)

Técnicas probadas:
- cfg_scale: 0.8, 1.0, 1.5, 2.0
- DDPM steps: 5, 10
- Pitch shift: -2 semitonos
- Texto rioplatense ("che", "dale", "bo")

Resultado: cfg_scale no cambia el acento. El modelo genera español genérico de España.

### 5. CosyVoice 3 — Instalado con clonación de voz

**Modelo:** `/tmp/CosyVoice/pretrained_models/Fun-CosyVoice3-0.5B/` (~9.75GB)
**Script de prueba:** `/tmp/test_cosyvoice3.py`
**Script de clonación:** `/tmp/cosyvoice3_clone_test.py`
**Script de tuning de acento:** `/tmp/cosyvoice3_tune_accent.py`
**Script final:** `/tmp/cosyvoice3_final_tests.py`
**Outputs:** `/tmp/cosyvoice3_cloned/`, `/tmp/cosyvoice3_tuned/`, `/tmp/cosyvoice3_final/`
**Voz prompt de Santiago:** `/tmp/santi_voice_prompt.wav` (9.9s, extraído de `/root/.hermes/audio_cache/`)

**Veredicto:** CosyVoice 3 suena a español de España, no latino. Ver `references/cosyvoice3-accent-investigacion-mayo2026.md`

### Entornos Python

- VibeVoice: `/tmp/vibevoice_env/` (Python 3.11)
- CosyVoice: `/tmp/cosyvoice_env/` (Python 3.11)
