import json
import logging
import requests
from pathlib import Path
from tools.registry import registry

logger = logging.getLogger(__name__)

BASE_URL = "http://localhost:8765"


def brand_action(logo_path: str, remove_bg: bool = True) -> str:
    """Extract brand identity parameters from a logo file."""
    url = f"{BASE_URL}/api/extract"
    path = Path(logo_path)
    if not path.exists():
        return json.dumps({"success": False, "error": f"Logo file not found: {logo_path}"})

    try:
        with open(path, "rb") as f:
            files = {"logo": (path.name, f, "image/png")}
            data = {"remove_bg": str(remove_bg).lower()}
            r = requests.post(url, files=files, data=data, timeout=30)
            if r.status_code == 200:
                return json.dumps(r.json(), ensure_ascii=False)
            return json.dumps({"success": False, "error": f"Server returned status {r.status_code}: {r.text}"})
    except Exception as e:
        return json.dumps({"success": False, "error": f"Failed to connect to Brand Pipeline: {e}"})


def director_action(action_type: str, title: str = None, subtitle: str = None,
                    duration: int = 5000, fx_type: str = None) -> str:
    """Trigger live overlay display or audio-visual FX on the broadcast screen."""
    url = f"{BASE_URL}/api/director/trigger"

    if fx_type:
        # Emergency or Glitch effects
        payload = {
            "action": "TRIGGER_FX",
            "type": fx_type.strip().lower()
        }
    else:
        # Standard lower-third overlay
        payload = {
            "action": "SHOW_OVERLAY",
            "data": {
                "title": title or "Alert",
                "subtitle": subtitle or "",
                "duration": duration
            }
        }

    try:
        r = requests.post(url, json=payload, timeout=10)
        if r.status_code == 200:
            return json.dumps({"success": True, "result": r.json()})
        return json.dumps({"success": False, "error": f"Server returned status {r.status_code}: {r.text}"})
    except Exception as e:
        return json.dumps({"success": False, "error": f"Failed to connect to Director: {e}"})


def overlays_director(logo_path: str, title: str, subtitle: str = "",
                      duration: int = 5000) -> str:
    """Extract brand colors/assets from a logo and immediately trigger a live lower-third overlay on screen."""
    # 1. Extract logo details
    brand_res = json.loads(brand_action(logo_path))
    if not brand_res.get("colors"):
        return json.dumps({"success": False, "error": "Failed to extract brand identity for overlay."})

    # 2. Trigger live broadcast overlay with branding
    director_res = json.loads(director_action(
        action_type="SHOW_OVERLAY",
        title=title,
        subtitle=subtitle,
        duration=duration
    ))

    return json.dumps({
        "success": director_res.get("success", False),
        "brand_identity": brand_res,
        "director_status": director_res
    }, ensure_ascii=False)


# Register separate Brand action tool
registry.register(
    name="brand_action",
    toolset="brand",
    schema={
        "name": "brand_action",
        "description": "Analyze a logo file to extract dominant colors, font classification, brand text, and audio vibe.",
        "parameters": {
            "type": "object",
            "properties": {
                "logo_path": {"type": "string", "description": "Absolute path to the logo image file (PNG/JPG)."},
                "remove_bg": {"type": "boolean", "description": "Whether to isolate the logo using MobileSAM.", "default": True}
            },
            "required": ["logo_path"]
        }
    },
    handler=lambda args, **kw: brand_action(
        logo_path=args.get("logo_path"),
        remove_bg=args.get("remove_bg", True)
    )
)

# Register separate Director action tool
registry.register(
    name="director_action",
    toolset="director",
    schema={
        "name": "director_action",
        "description": "Trigger dynamic lower-third overlays or visual FX (glitch/emergency) on the live stream dashboard.",
        "parameters": {
            "type": "object",
            "properties": {
                "action_type": {"type": "string", "enum": ["SHOW_OVERLAY", "TRIGGER_FX"], "default": "SHOW_OVERLAY"},
                "title": {"type": "string", "description": "Primary text for the lower-third overlay."},
                "subtitle": {"type": "string", "description": "Secondary text/subtitle for the overlay."},
                "duration": {"type": "integer", "description": "Display duration in milliseconds.", "default": 5000},
                "fx_type": {"type": "string", "enum": ["emergency", "glitch"], "description": "Visual effect type to trigger."}
            },
            "required": ["action_type"]
        }
    },
    handler=lambda args, **kw: director_action(
        action_type=args.get("action_type"),
        title=args.get("title"),
        subtitle=args.get("subtitle"),
        duration=args.get("duration", 5000),
        fx_type=args.get("fx_type")
    )
)

# Register combined Overlays Director tool
registry.register(
    name="overlays_director",
    toolset="brand_director",
    schema={
        "name": "overlays_director",
        "description": "Process a logo file to extract branding parameters and immediately trigger a live lower-third broadcast overlay.",
        "parameters": {
            "type": "object",
            "properties": {
                "logo_path": {"type": "string", "description": "Path to the logo image file."},
                "title": {"type": "string", "description": "Title text to show on the overlay."},
                "subtitle": {"type": "string", "description": "Subtitle text to show on the overlay."},
                "duration": {"type": "integer", "description": "Display duration in milliseconds.", "default": 5000}
            },
            "required": ["logo_path", "title"]
        }
    },
    handler=lambda args, **kw: overlays_director(
        logo_path=args.get("logo_path"),
        title=args.get("title"),
        subtitle=args.get("subtitle", ""),
        duration=args.get("duration", 5000)
    )
)
