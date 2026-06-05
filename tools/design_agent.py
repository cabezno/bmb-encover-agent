import json
import logging
import requests
from tools.registry import registry

logger = logging.getLogger(__name__)


def design_action(chat_message: str = None, action: str = None,
                  params: dict = None) -> str:
    """Interact with the Design Agent server."""
    base_url = "http://localhost:8000"

    # 1. Chat loop execution
    if chat_message:
        try:
            r = requests.post(f"{base_url}/api/chat", json={"message": chat_message}, timeout=120)
            if r.status_code == 200:
                return json.dumps(r.json(), ensure_ascii=False)
            return json.dumps({"success": False, "error": f"Server returned status {r.status_code}: {r.text}"})
        except Exception as e:
            return json.dumps({"success": False, "error": f"Failed to connect to Design Agent: {e}"})

    # 2. Direct tool execution
    if action:
        try:
            r = requests.post(f"{base_url}/api/execute", json={"tool": action, "params": params or {}}, timeout=30)
            if r.status_code == 200:
                return json.dumps(r.json(), ensure_ascii=False)
            return json.dumps({"success": False, "error": f"Server returned status {r.status_code}: {r.text}"})
        except Exception as e:
            return json.dumps({"success": False, "error": f"Failed to connect to Design Agent: {e}"})

    # 3. Status check (fallback when no args provided)
    try:
        r_status = requests.get(f"{base_url}/api/status", timeout=5)
        r_tools = requests.get(f"{base_url}/api/tools", timeout=5)
        status_data = r_status.json() if r_status.status_code == 200 else {}
        tools_data = r_tools.json() if r_tools.status_code == 200 else {}
        return json.dumps({
            "success": True,
            "status": status_data,
            "available_design_tools": tools_data.get("tools", [])
        }, ensure_ascii=False)
    except Exception as e:
        return json.dumps({
            "success": False,
            "error": f"Design Agent server is not running on port 8000. Start it first: {e}"
        })


registry.register(
    name="design_action",
    toolset="design",
    schema={
        "name": "design_action",
        "description": (
            "Interact with the local Design Agent to control graphic design software "
            "(Adobe Photoshop, GIMP, etc.). Can execute specific design tools directly "
            "or send a natural language instruction to run the full design agent loop."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "chat_message": {
                    "type": "string",
                    "description": "Natural language request to run the design agent loop (e.g. 'create a cyan banner with text HELLO WORLD')"
                },
                "action": {
                    "type": "string",
                    "description": "Specific tool/command to execute directly (e.g. 'new_document', 'add_text', 'resize_image')"
                },
                "params": {
                    "type": "object",
                    "description": "Arguments/parameters for the direct action (e.g. {'width': 1920, 'height': 1080})."
                }
            }
        }
    },
    handler=lambda args, **kw: design_action(
        chat_message=args.get("chat_message"),
        action=args.get("action"),
        params=args.get("params")
    )
)
