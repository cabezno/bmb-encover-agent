---
name: bmb-n8n-social-media
description: "Integración de BMB Undercover Agent con n8n para automatización de creación y publicación de contenido en redes sociales via webhooks."
version: 1.0.0
date: 2026-05-20
author: Santiago (cabezno)
tags:
  - n8n
  - webhooks
  - automation
  - social-media
  - content
  - workflow
---

# BMB + n8n: Social Media Content Automation Suite

## Arquitectura

```
                    ┌──────────────────┐
                    │    BMB Agent     │
                    │  (IA / LLM)      │
                    └───┬──────────┬───┘
                        │          │
                 Webhook│          │Webhook
                   POST │          │ POST
                        ▼          ▼
              ┌──────────────────────────┐
              │         n8n              │
              │  Workflow Automation     │
              │  (Flujos visuales)       │
              └──┬───────────┬───────────┘
                 │           │
       ┌─────────┤    ┌──────┤
       ▼         ▼    ▼      ▼
    Twitter   Instagram  Facebook  LinkedIn
    (xurl)    (n8n)     (n8n)     (n8n)
```

## ¿Qué es n8n?

n8n es un automatizador de flujos de trabajo open source (como Zapier / Make pero corre en tu propio servidor). Tiene cientos de conectores nativos y permite:

- Disparar workflows por webhook, schedule, o evento
- Conectarse a APIs de redes sociales, WordPress, email, etc.
- Procesar contenido con IA (via OpenAI, DeepSeek, etc.)
- Publicar automáticamente
- Manejar errores y reintentos

## Instalación de n8n (en WSL o Windows)

### Opción 1: Docker (recomendada)
```bash
docker run -d \
  --name n8n \
  -p 5678:5678 \
  -v n8n_data:/home/node/.n8n \
  n8nio/n8n
```

### Opción 2: npm (Windows)
```bash
npm install n8n -g
n8n start
```

### Opción 3: Windows ejecutable
Descargar desde https://n8n.io/download/

Luego abrir: `http://localhost:5678`

## Webhooks BMB ↔ n8n

### Endpoints que BMB expone para n8n

| Método | Endpoint | Puerto | Descripción |
|--------|----------|--------|-------------|
| POST | `/api/n8n/chat` | 8644 | Enviar mensaje/prompt al agente |
| POST | `/api/n8n/generate` | 8644 | Generar contenido (texto, imagen) |
| POST | `/api/n8n/analyze` | 8644 | Analizar texto, sentimiento, keywords |
| POST | `/api/n8n/schedule` | 8644 | Programar publicación |
| GET  | `/api/n8n/status` | 8644 | Estado del agente |

### Endpoints que n8n expone para BMB

BMB puede llamar webhooks de n8n para disparar workflows:

```
http://localhost:5678/webhook/bmb-publicar
http://localhost:5678/webhook/bmb-generar-imagen
http://localhost:5678/webhook/bmb-analizar-tendencias
http://localhost:5678/webhook/bmb-programar-semana
```

## Flujos típicos

### 1. Generar y publicar contenido automático

```
BMB (genera texto) → Webhook POST /api/n8n/generate → n8n workflow:
  1. Recibe prompt de BMB
  2. BMB genera contenido con IA
  3. n8n formatea para cada red
  4. n8n programa publicación
  5. n8n publica en Twitter (xurl), LinkedIn, Facebook
  6. n8n devuelve resultado a BMB
```

### 2. Programación semanal de contenido

```
BMB → "Creame contenido para esta semana" → n8n:
  1. BMB genera 7 posts (uno por día)
  2. n8n los programa en buffer
  3. n8n programa publicaciones diarias
  4. n8n notifica a BMB cuando se publican
```

### 3. Análisis de tendencias + contenido

```
n8n scheduler (cada 6h) → BMB webhook:
  1. n8n envía tendencias a BMB
  2. BMB analiza y sugiere contenido
  3. BMB responde con ideas de posts
  4. n8n programa los mejores
```

### 4. Respuesta automática en redes

```
Red social (mención) → n8n webhook → BMB:
  1. Alguien menciona en Twitter/Instagram
  2. n8n captura el evento
  3. n8n envía a BMB para analizar
  4. BMB sugiere/genera respuesta
  5. n8n publica la respuesta
```

## Configuración paso a paso

### 1. Instalar n8n

```bash
# Docker
docker run -d --name n8n -p 5678:5678 -v n8n_data:/home/node/.n8n n8nio/n8n
```

### 2. Configurar webhooks en n8n

En la UI de n8n (http://localhost:5678):
1. Crear nuevo workflow
2. Agregar nodo "Webhook"
3. Configurar ruta: `/bmb-publicar`
4. Agregar nodo "HTTP Request" apuntando a BMB: `http://localhost:8644/api/n8n/generate`
5. Agregar nodo "Twitter / LinkedIn / Facebook" para publicar
6. Activar workflow

### 3. Configurar BMB para hablar con n8n

```bash
# En config.yaml de BMB
n8n:
  enabled: true
  base_url: "http://localhost:5678"
  webhook_prefix: "/webhook/bmb-"
```

### 4. Probar conexión

```bash
# Desde BMB
curl -X POST http://localhost:8644/api/n8n/status
# Respuesta esperada: {"status": "ok", "n8n_connected": true}
```

## Ejemplo: Workflow n8n para publicación en Twitter vía BMB

**n8n workflow JSON** (importar en n8n):

```json
{
  "name": "BMB → Twitter Publisher",
  "nodes": [
    {
      "name": "Webhook",
      "type": "n8n-nodes-base.webhook",
      "parameters": {
        "path": "bmb-publicar",
        "responseMode": "lastNode"
      }
    },
    {
      "name": "HTTP Request - BMB AI",
      "type": "n8n-nodes-base.httpRequest",
      "parameters": {
        "url": "http://localhost:8644/api/n8n/generate",
        "method": "POST",
        "sendBody": true,
        "bodyParameters": {
          "parameters": [
            {"name": "prompt", "value": "={{$json.body.prompt}}"},
            {"name": "tone", "value": "={{$json.body.tone || 'profesional'}}"}
          ]
        }
      }
    },
    {
      "name": "Twitter",
      "type": "n8n-nodes-base.twitter",
      "parameters": {
        "text": "={{$json.content}}"
      }
    }
  ]
}
```

## Comandos BMB para n8n

```bash
# Ver estado de n8n
bmb n8n status

# Enviar contenido para publicar
bmb n8n publish "Mi nuevo post" --platform twitter,linkedin

# Generar y publicar
bmb n8n generate "Tema: inteligencia artificial" --schedule "2026-05-21 10:00"

# Programar semana completa
bmb n8n schedule-week "Marketing digital" --platforms all

# Ver historial de publicaciones
bmb n8n history --last 10
```

## Skills relacionadas

- `bmb-xurl` — Publicación directa en X/Twitter
- `bmb-wordpress` — Publicación en WordPress/WooCommerce
- `bmb-app-server` — API REST + WebSocket para apps
- `grabarpodcast-asistente` — Contexto completo del negocio GrabarPodcast
- `grabarpodcast-woocommerce-admin` — Gestión de WooCommerce

## Puerto de comunicación

Todo pasa por el puerto 8644 del app_server de BMB. Los webhooks de n8n apuntan a:

```
BMB:    http://localhost:8644/api/n8n/*
n8n:    http://localhost:5678/webhook/bmb-*
```
