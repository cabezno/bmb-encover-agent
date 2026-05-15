"""Resolve BMB_ENCOVER_HOME for standalone skill scripts.

Skill scripts may run outside the Hermes process (e.g. system Python,
nix env, CI) where ``bmb_constants`` is not importable.  This module
provides the same ``get_bmb_home()`` and ``display_bmb_home()``
contracts as ``bmb_constants`` without requiring it on ``sys.path``.

When ``bmb_constants`` IS available it is used directly so that any
future enhancements (profile resolution, Docker detection, etc.) are
picked up automatically.  The fallback path replicates the core logic
from ``bmb_constants.py`` using only the stdlib.

All scripts under ``google-workspace/scripts/`` should import from here
instead of duplicating the ``BMB_ENCOVER_HOME = Path(os.getenv(...))`` pattern.
"""

from __future__ import annotations

import os
from pathlib import Path

try:
    from bmb_constants import display_bmb_home as display_bmb_home
    from bmb_constants import get_bmb_home as get_bmb_home
except (ModuleNotFoundError, ImportError):

    def get_bmb_home() -> Path:
        """Return the Hermes home directory (default: ~/.bmb).

        Mirrors ``bmb_constants.get_bmb_home()``."""
        val = os.environ.get("BMB_ENCOVER_HOME", "").strip()
        return Path(val) if val else Path.home() / ".hermes"

    def display_bmb_home() -> str:
        """Return a user-friendly ``~/``-shortened display string.

        Mirrors ``bmb_constants.display_bmb_home()``."""
        home = get_bmb_home()
        try:
            return "~/" + str(home.relative_to(Path.home()))
        except ValueError:
            return str(home)
