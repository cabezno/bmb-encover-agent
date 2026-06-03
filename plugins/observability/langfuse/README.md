# Langfuse Observability Plugin

This plugin ships bundled with BMB but is **opt-in** — it only loads when
you explicitly enable it.

## Enable

Pick one:

```bash
# Interactive: walks you through credentials + SDK install + enable
bmb tools  # → Langfuse Observability

# Manual
pip install langfuse
hermes plugins enable observability/langfuse
```

## Required credentials

Set these in `~/.bmb/.env` (or via `bmb tools`):

```bash
BMB_LANGFUSE_PUBLIC_KEY=pk-lf-...
BMB_LANGFUSE_SECRET_KEY=sk-lf-...
BMB_LANGFUSE_BASE_URL=https://cloud.langfuse.com   # or your self-hosted URL
```

Without the SDK or credentials the hooks no-op silently — the plugin fails
open.

## Verify

```bash
hermes plugins list                 # observability/langfuse should show "enabled"
hermes chat -q "hello"              # then check Langfuse for a "BMB turn" trace
```

## Optional tuning

```bash
BMB_LANGFUSE_ENV=production       # environment tag
BMB_LANGFUSE_RELEASE=v1.0.0       # release tag
BMB_LANGFUSE_SAMPLE_RATE=0.5      # sample 50% of traces
BMB_LANGFUSE_MAX_CHARS=12000      # max chars per field (default: 12000)
BMB_LANGFUSE_DEBUG=true           # verbose plugin logging
```

## Disable

```bash
hermes plugins disable observability/langfuse
```
