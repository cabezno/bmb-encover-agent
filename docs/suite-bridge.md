# Suite BMB Bridge — Documentación para desarrolladores

## ¿Qué es?

El Suite Bridge es el centro de comunicaciones entre **BMB Undercover Agent** y las aplicaciones de tu suite. Cada app se conecta al bridge y recibe comandos de BMB en tiempo real.

## Arquitectura

```
BMB Agent (bmb suite start)
    │ Puerto 8644
    ▼
Suite Bridge (WebSocket + REST)
    │
    ├── ws://localhost:8644/ws/suite/gestor-ias
    ├── ws://localhost:8644/ws/suite/editor-caja-negra
    ├── ws://localhost:8644/ws/suite/editor-video
    └── ws://localhost:8644/ws/suite/streaming
```

## Cómo conectar cada app

Cada aplicación solo necesita incluir el archivo `suite_bridge_client.py` (o copiar el código relevante) y crear un cliente:

```python
from bmb_client import BMBAppClient

app = BMBAppClient(
    app_id="gestor-ias",          # ID único
    name="Mi App",                # Nombre visible
    bridge_url="ws://localhost:8644",
)

@app.on_command("ejecutar-plan")
def handle(params):
    print(f"Ejecutando: {params}")
    return {"status": "ok"}

app.connect()
app.wait()
```

## IDs de aplicación

| ID | App | Endpoints |
|----|-----|-----------|
| `gestor-ias` | Gestor de IAs | ejecutar-plan, plan-status, agents |
| `editor-caja-negra` | Editor Caja Negra | generar-contenido, publicar, schedule, analytics |
| `editor-video` | Editor de Video | render, timeline, effects, export |
| `streaming` | Streaming | iniciar-stream, detener-stream, scene, record |

## Protocolo WebSocket

### Bridge → App (comandos)
```json
{
  "type": "command",
  "task_id": "a1b2c3d4",
  "command": "ejecutar-plan",
  "params": {"plan": "...", "objetivos": []}
}
```

### App → Bridge (respuesta)
```json
{
  "type": "response",
  "task_id": "a1b2c3d4",
  "result": {"status": "ok", "data": "..."}
}
```

### App → Bridge (evento espontáneo)
```json
{
  "type": "event",
  "event": "progreso",
  "data": {"porcentaje": 75, "mensaje": "Renderizando..."}
}
```

## Endpoints REST (para pruebas)

```
GET  http://localhost:8644/api/suite/status
GET  http://localhost:8644/api/suite/apps
POST http://localhost:8644/api/suite/command/gestor-ias
     Body: {"command": "ejecutar-plan", "params": {}}
```

## Requisitos mínimos

- Python 3.8+
- aiohttp (pip install aiohttp)
- Conexión al mismo host que BMB (localhost o LAN)
