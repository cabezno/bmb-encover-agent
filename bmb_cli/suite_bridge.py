"""Bridge de la Suite BMB — Conexión entre BMB Agent y las aplicaciones de la suite.

Arquitectura:
  BMB Agent (IA orquestadora)
    ↓ WebSocket / REST
  Bridge BMB Suite (puerto 8644)
    ↓ WebSocket / IPC
  ┌──────────┬──────────┬──────────────┬────────────────┐
  │ Gestor   │ Editor   │ Editor de    │ Streaming /    │
  │ de IAs   │ Caja     │ Video        │ Grabación     │
  │          │ Negra    │              │                │
  └──────────┴──────────┴──────────────┴────────────────┘

Protocolo: JSON sobre WebSocket + REST endpoints
Autenticación: API key por aplicación
"""

import asyncio
import json
import logging
import os
import time
import uuid
from enum import Enum
from pathlib import Path
from typing import Any, Callable, Optional

logger = logging.getLogger("bmb-suite-bridge")


# ─── Aplicaciones de la Suite ─────────────────────────────────────

class AppID(Enum):
    GESTOR_IAS = "gestor-ias"
    EDITOR_CAJA_NEGRA = "editor-caja-negra"
    EDITOR_VIDEO = "editor-video"
    STREAMING = "streaming"


APP_INFO = {
    AppID.GESTOR_IAS: {
        "name": "Gestor de IAs",
        "description": "Ejecuta planes grandes: software, empresas completas",
        "version": "1.0.0",
        "endpoints": ["/execute-plan", "/plan-status", "/agents"],
    },
    AppID.EDITOR_CAJA_NEGRA: {
        "name": "Editor Caja Negra",
        "description": "Genera y gestiona contenido para redes sociales",
        "version": "1.0.0",
        "endpoints": ["/generate-content", "/publish", "/schedule", "/analytics"],
    },
    AppID.EDITOR_VIDEO: {
        "name": "Editor de Video",
        "description": "Edición y producción de video",
        "version": "1.0.0",
        "endpoints": ["/render", "/timeline", "/effects", "/export"],
    },
    AppID.STREAMING: {
        "name": "Streaming/Grabación",
        "description": "Transmisión en vivo y grabación de video",
        "version": "1.0.0",
        "endpoints": ["/start-stream", "/stop-stream", "/scene", "/record"],
    },
}


# ─── Sesión de aplicación ─────────────────────────────────────────

class AppSession:
    """Conexión con una aplicación de la suite BMB."""

    def __init__(self, app_id: AppID, ws_connection=None):
        self.app_id = app_id
        self.ws = ws_connection
        self.connected = ws_connection is not None
        self.session_id = str(uuid.uuid4())[:8]
        self.connected_at = time.time()
        self.last_activity = time.time()
        self.pending_tasks: dict[str, dict] = {}

    def is_alive(self) -> bool:
        return self.connected and (time.time() - self.last_activity) < 60

    def to_dict(self) -> dict:
        info = APP_INFO.get(self.app_id, {})
        return {
            "app_id": self.app_id.value,
            "name": info.get("name", self.app_id.value),
            "session_id": self.session_id,
            "connected": self.connected,
            "uptime": round(time.time() - self.connected_at),
            "pending_tasks": len(self.pending_tasks),
        }


# ─── Bridge principal ─────────────────────────────────────────────

class SuiteBridge:
    """Bridge de comunicaciones entre BMB y las aplicaciones de la suite.

    BMB se conecta al bridge y envía comandos a las apps.
    Las apps se conectan al bridge y reciben/envian eventos.
    """

    def __init__(self, host: str = "0.0.0.0", port: int = 8644):
        self.host = host
        self.port = port
        self.sessions: dict[str, AppSession] = {}
        self._running = False

    # ── Registro de apps ───────────────────────────────────────────

    def register_app(self, app_id: AppID, ws=None) -> AppSession:
        """Registrar una aplicación en el bridge."""
        session = AppSession(app_id, ws)
        self.sessions[session.session_id] = session
        logger.info(f"🔌 App registrada: {app_id.value} (sesión: {session.session_id})")
        return session

    def unregister_app(self, session_id: str):
        """Desconectar una aplicación."""
        if session_id in self.sessions:
            app = self.sessions.pop(session_id)
            logger.info(f"🔌 App desconectada: {app.app_id.value}")

    def get_app(self, app_id: AppID) -> Optional[AppSession]:
        """Obtener sesión activa de una app."""
        for session in self.sessions.values():
            if session.app_id == app_id and session.is_alive():
                return session
        return None

    # ── Envío de comandos ──────────────────────────────────────────

    async def send_command(self, app_id: AppID, command: str,
                           params: dict = None) -> dict:
        """Enviar un comando a una aplicación y esperar respuesta.

        Args:
            app_id: A qué app enviar
            command: Comando a ejecutar
            params: Parámetros del comando

        Returns:
            Respuesta de la aplicación
        """
        session = self.get_app(app_id)
        if not session:
            return {"error": f"App {app_id.value} no conectada", "status": "offline"}

        task_id = str(uuid.uuid4())[:8]
        payload = {
            "type": "command",
            "task_id": task_id,
            "command": command,
            "params": params or {},
            "timestamp": time.time(),
        }

        session.pending_tasks[task_id] = {"status": "sent", "sent_at": time.time()}

        if session.ws:
            try:
                await session.ws.send_json(payload)
                # Esperar respuesta
                for _ in range(100):  # timeout 10s
                    await asyncio.sleep(0.1)
                    task = session.pending_tasks.get(task_id)
                    if task and task["status"] == "completed":
                        return task.get("result", {"status": "completed"})
                return {"error": "timeout", "status": "pending"}
            except Exception as e:
                return {"error": str(e), "status": "error"}
        else:
            return {"error": "sin conexión WebSocket", "status": "offline"}

    async def receive_response(self, session_id: str, task_id: str,
                                result: dict):
        """Procesar respuesta de una aplicación."""
        session = self.sessions.get(session_id)
        if session and task_id in session.pending_tasks:
            session.pending_tasks[task_id]["status"] = "completed"
            session.pending_tasks[task_id]["result"] = result
            session.last_activity = time.time()

    # ── Estado ─────────────────────────────────────────────────────

    def get_status(self) -> dict:
        """Estado completo del bridge."""
        apps_status = {}
        for app_id in AppID:
            session = self.get_app(app_id)
            apps_status[app_id.value] = {
                "connected": session is not None,
                "session": session.to_dict() if session else None,
                "info": APP_INFO.get(app_id, {}),
            }

        return {
            "bridge": {
                "host": self.host,
                "port": self.port,
                "running": self._running,
                "apps_connected": sum(1 for s in self.sessions.values() if s.connected),
            },
            "apps": apps_status,
        }

    # ── Iniciar servidor ───────────────────────────────────────────

    async def start(self):
        """Iniciar el bridge como servidor HTTP + WebSocket."""
        from aiohttp import web

        self._running = True
        app = web.Application()

        # Endpoints
        app.router.add_get("/api/suite/status", self._handle_status)
        app.router.add_get("/api/suite/apps", self._handle_list_apps)
        app.router.add_post("/api/suite/command/{app_id}", self._handle_command)
        app.router.add_get("/ws/suite/{app_id}", self._handle_websocket)

        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, self.host, self.port)
        await site.start()

        logger.info(f"🏗️  Suite Bridge corriendo en {self.host}:{self.port}")
        print(f"\n🏗️  BMB Suite Bridge activo:")
        print(f"   Puerto: {self.port}")
        for app_id in AppID:
            info = APP_INFO[app_id]
            print(f"   • {info['name']} (/{app_id.value})")

    # ── Handlers HTTP ──────────────────────────────────────────────

    async def _handle_status(self, request):
        return web.json_response(self.get_status())

    async def _handle_list_apps(self, request):
        apps = []
        for app_id, info in APP_INFO.items():
            session = self.get_app(app_id)
            apps.append({
                "id": app_id.value,
                "name": info["name"],
                "description": info["description"],
                "connected": session is not None,
                "endpoints": info["endpoints"],
            })
        return web.json_response(apps)

    async def _handle_command(self, request):
        app_id_str = request.match_info["app_id"]
        try:
            app_id = AppID(app_id_str)
        except ValueError:
            return web.json_response({"error": f"App no válida: {app_id_str}"}, status=400)

        body = await request.json()
        command = body.get("command")
        params = body.get("params", {})

        result = await self.send_command(app_id, command, params)
        return web.json_response(result)

    async def _handle_websocket(self, request):
        app_id_str = request.match_info["app_id"]
        try:
            app_id = AppID(app_id_str)
        except ValueError:
            return web.Response(text=f"App no válida: {app_id_str}", status=400)

        ws = web.WebSocketResponse()
        await ws.prepare(request)

        session = self.register_app(app_id, ws)
        await ws.send_json({"type": "connected", "session_id": session.session_id})

        try:
            async for msg in ws:
                if msg.type == web.WSMsgType.TEXT:
                    data = json.loads(msg.data)
                    if data.get("type") == "response":
                        await self.receive_response(
                            session.session_id,
                            data.get("task_id"),
                            data.get("result", {}),
                        )
                    elif data.get("type") == "event":
                        logger.info(f"📨 Evento de {app_id.value}: {data.get('event')}")
                        # Reenviar a BMB
                        await self._forward_to_bmb(data)
                elif msg.type == web.WSMsgType.ERROR:
                    logger.error(f"WS error {app_id.value}: {ws.exception()}")
        except Exception as e:
            logger.error(f"WS exception {app_id.value}: {e}")
        finally:
            self.unregister_app(session.session_id)

        return ws

    async def _forward_to_bmb(self, data: dict):
        """Reenviar eventos de las apps a BMB (implementar según necesidad)."""
        logger.debug(f"Evento reenviado a BMB: {data.get('event')}")


# ── Comandos CLI ──────────────────────────────────────────────────

_bridge_instance: Optional[SuiteBridge] = None


def cmd_suite_start(args):
    """Iniciar el bridge de la suite BMB."""
    global _bridge_instance
    host = getattr(args, "host", "0.0.0.0")
    port = getattr(args, "port", 8644)

    print("\n╔══════════════════════════════════════╗")
    print("║   BMB Suite Bridge                   ║")
    print("╚══════════════════════════════════════╝")
    print()
    print("  Aplicaciones disponibles:")
    for app_id in AppID:
        info = APP_INFO[app_id]
        print(f"    • {info['name']}")
        print(f"      ID: {app_id.value}")
        for ep in info["endpoints"]:
            print(f"      Endpoint: {ep}")
    print()
    print("  Iniciando bridge...")

    _bridge_instance = SuiteBridge(host=host, port=port)

    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        loop.run_until_complete(_bridge_instance.start())
        loop.run_forever()
    except KeyboardInterrupt:
        print("\n\nBridge detenido.")
    finally:
        loop.close()


def cmd_suite_status(args):
    """Estado del bridge y apps conectadas."""
    global _bridge_instance
    if not _bridge_instance:
        print("❌ Bridge no iniciado. Ejecute: bmb suite start")
        return

    status = _bridge_instance.get_status()
    print("\n🏗️  BMB Suite Bridge — Estado:")
    print(f"   Host: {status['bridge']['host']}:{status['bridge']['port']}")
    print(f"   Apps conectadas: {status['bridge']['apps_connected']}")
    print()
    for app_id, app in status["apps"].items():
        icon = "✅" if app["connected"] else "❌"
        print(f"  {icon} {app['info']['name']}")
        print(f"     ID: {app_id}")
        if app["session"]:
            print(f"     Sesión: {app['session']['session_id']}")
            print(f"     Activo: {app['session']['uptime']}s")


def cmd_suite_command(args):
    """Enviar comando a una aplicación."""
    global _bridge_instance
    if not _bridge_instance:
        print("❌ Bridge no iniciado")
        return

    app_id_str = args.app_id
    command = args.command

    try:
        app_id = AppID(app_id_str)
    except ValueError:
        print(f"❌ App no válida: {app_id_str}")
        print(f"   Apps: {', '.join(a.value for a in AppID)}")
        return

    print(f"→ Enviando comando '{command}' a {app_id.value}...")
    loop = asyncio.new_event_loop()
    result = loop.run_until_complete(
        _bridge_instance.send_command(app_id, command)
    )
    loop.close()
    print(f"   Respuesta: {json.dumps(result, indent=2, ensure_ascii=False)}")
