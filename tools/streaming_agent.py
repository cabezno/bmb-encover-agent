import json
import logging
import requests
from tools.registry import registry

logger = logging.getLogger(__name__)


def streaming_action(command: str = None) -> str:
    """Interact with the Streaming Agent server."""
    base_url = "http://localhost:7860"

    # 1. Process command
    if command:
        try:
            r = requests.post(f"{base_url}/command", json={"text": command}, timeout=90)
            if r.status_code == 200:
                return json.dumps(r.json(), ensure_ascii=False)
            return json.dumps({"success": False, "error": f"Server returned status {r.status_code}: {r.text}"})
        except Exception as e:
            return json.dumps({"success": False, "error": f"Failed to connect to Streaming Agent: {e}"})

    # 2. Get status and state
    try:
        r_status = requests.get(f"{base_url}/status", timeout=5)
        r_state = requests.get(f"{base_url}/state", timeout=5)
        status_data = r_status.json() if r_status.status_code == 200 else {}
        state_data = r_state.json() if r_state.status_code == 200 else {}
        return json.dumps({
            "success": True,
            "status": status_data,
            "stream_state": state_data
        }, ensure_ascii=False)
    except Exception as e:
        return json.dumps({
            "success": False,
            "error": f"Streaming Agent server is not running on port 7860. Start it first: {e}"
        })


registry.register(
    name="streaming_action",
    toolset="streaming",
    schema={
        "name": "streaming_action",
        "description": (
            "Interact with the local Streaming Agent to control streaming software "
            "(OBS Studio, vMix, etc.). Send a command to change scenes, start/stop stream, "
            "mute sources, or query the active scene list."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "command": {
                    "type": "string",
                    "description": "The command or instruction for the streaming setup (e.g. 'switch to scene Gameplay', 'mute microphone', 'start streaming')."
                }
            }
        }
    },
    handler=lambda args, **kw: streaming_action(
        command=args.get("command")
    )
)
