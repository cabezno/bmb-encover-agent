---
name: multi-model-orchestration
description: "Configuración de orquestación multi-modelo para Hermes/BMB: Claude planifica, DeepSeek ejecuta, con hoja de ruta y objetivos compartidos."
version: 1.0.0
date: 2026-05-21
author: Santiago (cabezno)
tags:
  - orchestration
  - multi-model
  - claude
  - deepseek
  - planning
  - execution
  - roadmap
---

# Multi-Model Orchestration: Claude planifica, DeepSeek ejecuta

## Arquitectura

```
[Usuario] → pregunta/tarea
    ↓
┌─────────────────────────────────────┐
│  FASE 1: CLAUDE (planificador)       │
│  - Analiza la tarea                  │
│  - Crea plan paso a paso             │
│  - Define objetivos y métricas        │
│  - Genera hoja de ruta               │
│  - Guarda en contexto compartido     │
└──────────────┬──────────────────────┘
               ↓ plan aprobado
┌─────────────────────────────────────┐
│  FASE 2: DEEPSEEK (ejecutor)         │
│  - Lee plan del contexto              │
│  - Ejecuta paso 1, 2, 3...           │
│  - Usa herramientas (terminal, API)   │
│  - Reporta progreso                   │
│  - Actualiza hoja de ruta             │
└──────────────┬──────────────────────┘
               ↓ tarea completada
┌─────────────────────────────────────┐
│  REPORTE: Resumen de ejecución       │
│  - Qué se hizo                       │
│  - Qué falta                         │
│  - Próximos pasos                    │
└─────────────────────────────────────┘
```

## Configuración para Hermes

### 1. Agregar API key de Claude

En `~/.hermes/.env`:
```
ANTHROPIC_API_KEY=sk-ant-...
```

### 2. Configurar providers

En `~/.hermes/config.yaml`:
```yaml
models:
  default: deepseek-chat
  providers:
    deepseek:
      base_url: https://api.deepseek.com/v1
      api_key: ${DEEPSEEK_API_KEY}
    anthropic:
      api_key: ${ANTHROPIC_API_KEY}

multi_model:
  enabled: true
  planner:
    provider: anthropic
    model: claude-sonnet-4
    temperature: 0.3
  executor:
    provider: deepseek
    model: deepseek-chat
    temperature: 0.1
  context_file: "~/.bmb/roadmap.json"
```

### 3. Comando: `bmb orchestrate` (o `hermes orchestrate`)

```
bmb orchestrate "Crear un sistema de autopublicación para redes sociales"
```

Esto:
1. Toma la tarea
2. La envía a **Claude** para planificar
3. Claude genera una hoja de ruta con pasos y objetivos
4. Guarda en `roadmap.json`
5. **DeepSeek** ejecuta cada paso
6. Reporta progreso

## Hoja de ruta (contexto compartido)

```json
{
  "task": "Crear sistema de autopublicación",
  "status": "in_progress",
  "plan": [
    {
      "step": 1,
      "objective": "Analizar APIs disponibles",
      "status": "completed",
      "executor": "deepseek",
      "output": "Twitter API v2 OK, Instagram Graph API OK"
    },
    {
      "step": 2,
      "objective": "Crear módulo de conexión",
      "status": "in_progress",
      "executor": "deepseek",
      "output": null
    },
    {
      "step": 3,
      "objective": "Implementar scheduler",
      "status": "pending",
      "executor": "deepseek",
      "output": null
    }
  ],
  "metrics": {
    "total_steps": 5,
    "completed": 1,
    "in_progress": 1,
    "pending": 3
  }
}
```

## Cómo se usa

### Desde el CLI de Hermes/BMB:

```
# Planificar solo (Claude)
bmb orchestrate plan "Crear un bot de Twitter"

# Ejecutar plan existente (DeepSeek)
bmb orchestrate execute

# Planificar + ejecutar (completo)
bmb orchestrate full "Desarrollar API para clientes"

# Ver estado de la hoja de ruta actual
bmb orchestrate status

# Marcar paso como completado manualmente
bmb orchestrate complete --step 2
```

### Configuración de alternancia automática:

```yaml
multi_model:
  auto_switch: true
  # Si auto_switch=true, cada vez que detecta una tarea compleja:
  # 1. Pide a Claude que planifique
  # 2. Cambia automáticamente a DeepSeek para ejecutar
  # 3. Vuelve a Claude si necesita replanificar
  replan_threshold: 0.3  # Si 30%+ de pasos fallan, replanificar
```

## Implementación técnica

El orquestador funciona como un **wrapper** sobre el agente:

1. Intercepta la tarea del usuario
2. Si es compleja (define heurística), llama a Claude primero
3. Claude genera plan JSON en `roadmap.json`
4. Cambia provider a DeepSeek
5. DeepSeek ejecuta cada paso, actualizando el roadmap
6. Al finalizar, genera reporte

Requiere implementar el módulo `orchestrator.py` en `bmb_cli/` con:
- `orchestrate_plan(task)` → llama a Claude
- `orchestrate_execute()` → lee roadmap, ejecuta con DeepSeek
- `orchestrate_status()` → muestra progreso
