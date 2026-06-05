import sys
import json
import logging
import threading
import time
from pathlib import Path

# Add user dir to import path to find pomodoro_soda
sys.path.insert(0, str(Path("C:/Users/User")))

from pomodoro_soda.engine import PurePomodoroStateEngine
from pomodoro_soda.persistence import AtomicPersistenceManager
from pomodoro_soda.audio import AudioEventTrigger
from pomodoro_soda.renderer import TerminalViewRenderer
from tools.registry import registry

logger = logging.getLogger(__name__)

# Core global state
_engine_lock = threading.Lock()
_engine = None
_tick_thread = None
_db_file_path = str(Path.home() / ".bmb" / "pomodoro_history.json")


def _init_engine():
    global _engine, _tick_thread
    with _engine_lock:
        if _engine is not None:
            return

        history = AtomicPersistenceManager.load(_db_file_path)

        def save_fn(hist):
            AtomicPersistenceManager.save(_db_file_path, hist)

        _engine = PurePomodoroStateEngine(
            notifyStateChange=lambda s: None,
            triggerDataSave=save_fn,
            history=history
        )

        # Start tick daemon thread
        def run_ticks():
            while True:
                time.sleep(1)
                with _engine_lock:
                    if _engine.state == "running":
                        _engine.execute_command("tick")

        _tick_thread = threading.Thread(target=run_ticks, daemon=True, name="pomodoro-ticker")
        _tick_thread.start()


def pomodoro_action(command: str = "status") -> str:
    """Execute a pomodoro command and return current render."""
    _init_engine()
    cmd = command.strip().lower()

    with _engine_lock:
        if cmd in ("start", "pause", "resume", "stop", "skip"):
            _engine.execute_command(cmd)
            # Trigger audio feedback if needed
            info = _engine.get_session_info()
            event = info.get("current_event")
            if event:
                AudioEventTrigger.trigger(event)

        # Always return the rendered state
        info = _engine.get_session_info()
        rendered = TerminalViewRenderer.render(info)
        return rendered


registry.register(
    name="pomodoro_action",
    toolset="pomodoro",
    schema={
        "name": "pomodoro_action",
        "description": (
            "Control the Pomodoro Soda timer. Command can be 'start', 'pause', "
            "'resume', 'stop', 'skip', or 'status' (default)."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "command": {
                    "type": "string",
                    "enum": ["start", "pause", "resume", "stop", "skip", "status"],
                    "default": "status",
                    "description": "Command to execute."
                }
            }
        }
    },
    handler=lambda args, **kw: pomodoro_action(
        command=args.get("command", "status")
    )
)
