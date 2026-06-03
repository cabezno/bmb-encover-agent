"""Cliente para conectar cualquier aplicación de la Suite BMB con BMB Undercover Agent.

Cada app de la suite necesita solo este archivo para conectarse al bridge.
Usa WebSocket para comunicación bidireccional en tiempo real.

Modo de uso:
    from bmb_client import BMBAppClient

    app = BMBAppClient(
        app_id="gestor-ias",
        name="Mi App",
        bridge_url="ws://localhost:8644",
    )

    # Conectar y recibir comandos
    app.connect()

    # Escuchar comandos de BMB
    @app.on_command("ejecutar-plan")
    def handle_plan(params):
        print(f"Ejecutando plan: {params}")
        return {"status": "ok", "result": "Plan ejecutado"}

    app.wait()
"""

import asyncio
import json
import logging
import threading
import time
import uuid
from typing import Any, Callable, Optional

logger = logging.getLogger("bmb-client")


class BMBAppClient:
    """Cliente WebSocket para conectar una app con BMB Undercover Agent.

    Args:
        app_id: Identificador único de la app (gestor-ias, editor-caja-negra, editor-video, streaming)
        name: Nombre legible de la app
        bridge_url: URL del bridge de BMB (default: ws://localhost:8644)
        api_key: API key opcional para autenticación
    """

    def __init__(self, app_id: str, name: str = "",
                 bridge_url: str = "ws://localhost:8644",
                 api_key: str = ""):
        self.app_id = app_id
        self.name = name or app_id
        self.bridge_url = bridge_url.rstrip("/")
        self.api_key = api_key
        self.session_id: Optional[str] = None
        self._ws = None
        self._loop = None
        self._thread = None
        self._running = False
        self._command_handlers: dict[str, Callable] = {}
        self._connected = False

    # ── Decorador para registrar handlers ──────────────────────────

    def on_command(self, command: str):
        """Decorador: registrar handler para un comando.

        Uso:
            @app.on_command("ejecutar")
            def handle(params):
                return {"status": "ok"}
        """
        def decorator(func: Callable):
            self._command_handlers[command] = func
            return func
        return decorator

    # ── Conexión ──────────────────────────────────────────────────

    def connect(self):
        """Conectar al bridge de BMB (bloqueante, corre en segundo plano)."""
        self._running = True
        self._thread = threading.Thread(target=self._run_loop, daemon=True)
        self._thread.start()

    def _run_loop(self):
        """Ejecutar el event loop en un thread separado."""
        self._loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self._loop)
        try:
            self._loop.run_until_complete(self._connect_and_listen())
        except Exception as e:
            logger.error(f"Error en conexión: {e}")
        finally:
            self._loop.close()

    async def _connect_and_listen(self):
        """Conectar y escuchar mensajes del bridge."""
        import aiohttp

        ws_url = f"{self.bridge_url.replace('http://', 'ws://').replace('https://', 'wss://')}/ws/suite/{self.app_id}"

        logger.info(f"🔌 Conectando a BMB bridge: {ws_url}")

        try:
            async with aiohttp.ClientSession() as session:
                async with session.ws_connect(ws_url) as ws:
                    self._ws = ws
                    self._connected = True

                    # Esperar mensaje de connected
                    msg = await ws.receive()
                    if msg.type == aiohttp.WSMsgType.TEXT:
                        data = json.loads(msg.data)
                        if data.get("type") == "connected":
                            self.session_id = data.get("session_id")
                            print(f"✅ Conectado a BMB Bridge")
                            print(f"   App: {self.name} ({self.app_id})")
                            print(f"   Sesión: {self.session_id}")
                            print(f"   Esperando comandos...\n")

                    # Escuchar comandos
                    async for msg in ws:
                        if msg.type == aiohttp.WSMsgType.TEXT:
                            await self._handle_message(json.loads(msg.data))
                        elif msg.type == aiohttp.WSMsgType.ERROR:
                            logger.error(f"Error WS: {ws.exception()}")

        except Exception as e:
            logger.error(f"❌ No se pudo conectar a BMB bridge: {e}")
            print(f"\n❌ No se pudo conectar a BMB Bridge en {ws_url}")
            print(f"   Asegurate de que BMB esté corriendo con 'bmb suite start'")
        finally:
            self._connected = False

    async def _handle_message(self, data: dict):
        """Procesar mensaje del bridge."""
        msg_type = data.get("type")

        if msg_type == "command":
            await self._handle_command(data)
        elif msg_type == "ping":
            await self._ws.send_json({"type": "pong"})

    async def _handle_command(self, data: dict):
        """Ejecutar comando recibido de BMB."""
        command = data.get("command", "")
        params = data.get("params", {})
        task_id = data.get("task_id", "")

        logger.info(f"📨 Comando recibido: {command}")

        # Buscar handler
        handler = self._command_handlers.get(command)
        if not handler:
            logger.warning(f"Comando desconocido: {command}")
            await self._send_response(task_id, {"error": f"Comando desconocido: {command}"})
            return

        # Ejecutar handler
        try:
            if asyncio.iscoroutinefunction(handler):
                result = await handler(params)
            else:
                result = handler(params)
            await self._send_response(task_id, {"status": "ok", "result": result})
        except Exception as e:
            logger.error(f"Error ejecutando {command}: {e}")
            await self._send_response(task_id, {"error": str(e)})

    async def _send_response(self, task_id: str, result: dict):
        """Enviar respuesta al bridge."""
        if self._ws and not self._ws.closed:
            await self._ws.send_json({
                "type": "response",
                "task_id": task_id,
                "result": result,
            })

    # ── Enviar eventos a BMB ───────────────────────────────────────

    async def send_event(self, event: str, data: dict = None):
        """Enviar un evento a BMB (por ejemplo: progreso, notificación)."""
        if self._ws and not self._ws.closed:
            await self._ws.send_json({
                "type": "event",
                "event": event,
                "data": data or {},
            })

    # ── Utilidades ─────────────────────────────────────────────────

    def wait(self):
        """Mantener el programa corriendo hasta Ctrl+C."""
        try:
            while self._running:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\nDesconectando...")
            self._running = False

    @property
    def is_connected(self) -> bool:
        return self._connected


# ═══════════════════════════════════════════════════════════════════
# Ejemplos de uso para cada aplicación de la suite
# ═══════════════════════════════════════════════════════════════════

def ejemplo_gestor_ias():
    """Ejemplo: Gestor de IAs - ejecuta planes grandes."""
    app = BMBAppClient(
        app_id="gestor-ias",
        name="Gestor de IAs",
    )

    @app.on_command("ejecutar-plan")
    def ejecutar_plan(params):
        """Recibe un plan de BMB y lo ejecuta."""
        plan = params.get("plan", "")
        objetivos = params.get("objetivos", [])
        print(f"📋 Ejecutando plan: {plan[:50]}...")
        # TODO: implementar ejecución del plan
        return {"status": "ejecutando", "plan_id": plan}

    @app.on_command("plan-status")
    def plan_status(params):
        """Devuelve el estado del plan actual."""
        return {"status": "in_progress", "progreso": "45%"}

    app.connect()
    app.wait()


def ejemplo_editor_caja_negra():
    """Ejemplo: Editor Caja Negra - contenido para redes."""
    app = BMBAppClient(
        app_id="editor-caja-negra",
        name="Editor Caja Negra",
    )

    @app.on_command("generar-contenido")
    def generar(params):
        """BMB pide generar contenido."""
        tema = params.get("tema", "")
        plataforma = params.get("plataforma", "twitter")
        print(f"📝 Generando contenido para {plataforma}: {tema}")
        return {"status": "generado", "contenido": f"Post sobre {tema}"}

    @app.on_command("publicar")
    def publicar(params):
        """BMB pide publicar en redes."""
        contenido = params.get("contenido", "")
        plataformas = params.get("plataformas", ["twitter"])
        print(f"📤 Publicando en {plataformas}: {contenido[:50]}...")
        return {"status": "publicado", "urls": {"twitter": "https://..."}}

    app.connect()
    app.wait()


def ejemplo_editor_video():
    """Ejemplo: Editor de Video."""
    app = BMBAppClient(
        app_id="editor-video",
        name="Editor de Video",
    )

    @app.on_command("render")
    def render(params):
        proyecto = params.get("proyecto", "")
        formato = params.get("formato", "mp4")
        print(f"🎬 Renderizando {proyecto} a {formato}...")
        return {"status": "rendering", "estimado": "5 minutos"}

    @app.on_command("exportar")
    def exportar(params):
        archivo = params.get("archivo", "")
        destino = params.get("destino", "")
        print(f"📦 Exportando {archivo} a {destino}")
        return {"status": "exportado", "path": destino}

    app.connect()
    app.wait()


def ejemplo_streaming():
    """Ejemplo: Streaming y grabación."""
    app = BMBAppClient(
        app_id="streaming",
        name="Streaming/Grabación",
    )

    @app.on_command("iniciar-stream")
    def iniciar(params):
        plataforma = params.get("plataforma", "youtube")
        titulo = params.get("titulo", "Stream")
        print(f"📡 Iniciando stream en {plataforma}: {titulo}")
        return {"status": "live", "stream_url": f"https://{plataforma}.com/stream"}

    @app.on_command("cambiar-escena")
    def escena(params):
        escena = params.get("escena", "principal")
        print(f"🔄 Cambiando a escena: {escena}")
        return {"status": "ok", "escena_actual": escena}

    app.connect()
    app.wait()
