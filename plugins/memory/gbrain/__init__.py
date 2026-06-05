"""GBrain memory plugin — MemoryProvider interface.

Persistent memory via the GBrain CLI (``gbrain``).
Local-first memory consolidation and hybrid search.
"""

from __future__ import annotations

import json
import logging
import os
import shutil
import subprocess
import threading
from pathlib import Path
from typing import Any, Dict, List, Optional

from agent.memory_provider import MemoryProvider

logger = logging.getLogger(__name__)

# Timeouts
_QUERY_TIMEOUT = 15
_CAPTURE_TIMEOUT = 30

# Minimum lengths to filter noise
_MIN_QUERY_LEN = 10
_MIN_OUTPUT_LEN = 20

# ---------------------------------------------------------------------------
# gbrain binary resolution
# ---------------------------------------------------------------------------

_gbrain_path_lock = threading.Lock()
_cached_gbrain_path: Optional[str] = None


def _resolve_gbrain_path() -> Optional[str]:
    """Find the gbrain binary on PATH or well-known install locations."""
    global _cached_gbrain_path
    with _gbrain_path_lock:
        if _cached_gbrain_path is not None:
            return _cached_gbrain_path if _cached_gbrain_path != "" else None

    found = shutil.which("gbrain")
    if not found:
        home = Path.home()
        candidates = [
            home / ".bun" / "bin" / "gbrain",
            Path("/usr/local/bin/gbrain"),
            Path("/usr/bin/gbrain"),
        ]
        for c in candidates:
            if c.exists():
                found = str(c)
                break

    with _gbrain_path_lock:
        if _cached_gbrain_path is not None:
            return _cached_gbrain_path if _cached_gbrain_path != "" else None
        _cached_gbrain_path = found or ""
    return found


def _run_gbrain(args: List[str], timeout: int = _QUERY_TIMEOUT,
               cwd: str = None) -> dict:
    """Run a gbrain CLI command. Returns {success, output, error}."""
    gbrain_path = _resolve_gbrain_path()
    if not gbrain_path:
        return {"success": False, "error": "gbrain CLI not found. Install: bun install -g github:garrytan/gbrain"}

    cmd = [gbrain_path] + args
    effective_cwd = cwd or os.getcwd()

    env = os.environ.copy()
    gbrain_bin_dir = str(Path(gbrain_path).parent)
    env["PATH"] = gbrain_bin_dir + os.pathsep + env.get("PATH", "")

    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True,
            timeout=timeout, cwd=effective_cwd, env=env,
        )
        stdout = result.stdout.strip()
        stderr = result.stderr.strip()

        if result.returncode == 0:
            return {"success": True, "output": stdout}
        return {"success": False, "error": stderr or stdout or f"gbrain exited {result.returncode}"}

    except subprocess.TimeoutExpired:
        return {"success": False, "error": f"gbrain timed out after {timeout}s"}
    except FileNotFoundError:
        global _cached_gbrain_path
        with _gbrain_path_lock:
            _cached_gbrain_path = None
        return {"success": False, "error": "gbrain CLI not found"}
    except Exception as e:
        return {"success": False, "error": str(e)}


# ---------------------------------------------------------------------------
# Tool schemas
# ---------------------------------------------------------------------------

QUERY_SCHEMA = {
    "name": "gbrain_query",
    "description": (
        "Search GBrain's hybrid database (vector + tsvector) for relevant context, "
        "decisions, meetings, and personal facts. Returns memories and synthesized knowledge "
        "across people, companies, ideas, and sessions."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "query": {"type": "string", "description": "Search term or question to query the brain."},
        },
        "required": ["query"],
    },
}

CAPTURE_SCHEMA = {
    "name": "gbrain_capture",
    "description": (
        "Capture a new memory, fact, decision, or note in GBrain. "
        "Saves the content into the brain's inbox/ directory and index. "
        "Use this for persistent storage of important knowledge."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "content": {"type": "string", "description": "The text content to capture."},
            "type": {"type": "string", "description": "Page type (e.g. note, project, person, meeting).", "default": "note"},
        },
        "required": ["content"],
    },
}

STATUS_SCHEMA = {
    "name": "gbrain_status",
    "description": "Check GBrain CLI status and page count statistics.",
    "parameters": {"type": "object", "properties": {}, "required": []},
}


# ---------------------------------------------------------------------------
# MemoryProvider implementation
# ---------------------------------------------------------------------------

class GBrainMemoryProvider(MemoryProvider):
    """GBrain memory provider implementing the MemoryProvider interface."""

    def __init__(self):
        self._cwd = ""
        self._session_id = ""
        self._turn_count = 0
        self._sync_thread: Optional[threading.Thread] = None

    @property
    def name(self) -> str:
        return "gbrain"

    def is_available(self) -> bool:
        return _resolve_gbrain_path() is not None

    def get_config_schema(self):
        return []

    def initialize(self, session_id: str, **kwargs) -> None:
        self._cwd = os.getcwd()
        self._session_id = session_id
        self._turn_count = 0

    def system_prompt_block(self) -> str:
        if not _resolve_gbrain_path():
            return ""
        return (
            "# GBrain Memory\n"
            "Active. Hybrid knowledge search (vector + text) and graph traversal.\n"
            "Use gbrain_query to retrieve context and gbrain_capture to store new facts."
        )

    def prefetch(self, query: str, *, session_id: str = "") -> str:
        if not query or len(query.strip()) < _MIN_QUERY_LEN:
            return ""
        result = _run_gbrain(
            ["query", query.strip()[:5000]],
            timeout=_QUERY_TIMEOUT, cwd=self._cwd,
        )
        if result["success"] and result.get("output"):
            output = result["output"].strip()
            if len(output) > _MIN_OUTPUT_LEN:
                return f"## GBrain Context\n{output}"
        return ""

    def queue_prefetch(self, query: str, *, session_id: str = "") -> None:
        pass

    def sync_turn(self, user_content: str, assistant_content: str, *, session_id: str = "") -> None:
        self._turn_count += 1
        if len(user_content.strip()) < _MIN_QUERY_LEN:
            return

        def _sync():
            try:
                combined = f"User: {user_content[:2000]}\nAssistant: {assistant_content[:2000]}"
                # Capture turn
                slug = f"chat/turn_{self._session_id}_{self._turn_count}"
                _run_gbrain(
                    ["capture", combined, "--slug", slug, "--type", "chat_turn"],
                    timeout=_CAPTURE_TIMEOUT, cwd=self._cwd,
                )
                # Re-index stale embeddings
                _run_gbrain(["embed", "--stale"], timeout=_CAPTURE_TIMEOUT, cwd=self._cwd)
            except Exception as e:
                logger.debug("GBrain sync failed: %s", e)

        if self._sync_thread and self._sync_thread.is_alive():
            self._sync_thread.join(timeout=5.0)

        self._sync_thread = threading.Thread(
            target=_sync, daemon=True, name="gbrain-sync"
        )
        self._sync_thread.start()

    def on_memory_write(self, action: str, target: str, content: str) -> None:
        if action not in ("add", "replace") or not content:
            return

        def _write():
            try:
                label = "User profile" if target == "user" else "Agent memory"
                _run_gbrain(
                    ["capture", f"[{label}] {content}", "--type", "profile"],
                    timeout=_CAPTURE_TIMEOUT, cwd=self._cwd,
                )
                _run_gbrain(["embed", "--stale"], timeout=_CAPTURE_TIMEOUT, cwd=self._cwd)
            except Exception as e:
                logger.debug("GBrain memory write mirror failed: %s", e)

        t = threading.Thread(target=_write, daemon=True, name="gbrain-memwrite")
        t.start()

    def get_tool_schemas(self) -> List[Dict[str, Any]]:
        return [QUERY_SCHEMA, CAPTURE_SCHEMA, STATUS_SCHEMA]

    def handle_tool_call(self, tool_name: str, args: dict, **kwargs) -> str:
        if tool_name == "gbrain_query":
            q = args.get("query", "")
            result = _run_gbrain(["query", q], cwd=self._cwd)
            if result["success"]:
                return json.dumps({"success": True, "results": result["output"]})
            return json.dumps({"success": False, "error": result["error"]})
        elif tool_name == "gbrain_capture":
            content = args.get("content", "")
            page_type = args.get("type", "note")
            result = _run_gbrain(["capture", content, "--type", page_type], cwd=self._cwd)
            if result["success"]:
                return json.dumps({"success": True, "slug": result["output"]})
            return json.dumps({"success": False, "error": result["error"]})
        elif tool_name == "gbrain_status":
            result = _run_gbrain(["stats"], cwd=self._cwd)
            if result["success"]:
                return json.dumps({"success": True, "stats": result["output"]})
            return json.dumps({"success": False, "error": result["error"]})
        return json.dumps({"success": False, "error": f"Unknown tool {tool_name}"})
