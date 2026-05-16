# -*- mode: python ; coding: utf-8 -*-
"""
PyInstaller spec para BMB App Server (.exe para Windows)
Uso: pyinstaller app-server.spec
"""
import sys, os
from pathlib import Path

ROOT = Path.cwd().resolve()

a = Analysis(
    ["app_server.py"],
    pathex=[str(ROOT)],
    binaries=[],
    datas=[],
    hiddenimports=[
        "bmb_cli", "bmb_cli.config", "bmb_cli.env_loader",
        "bmb_constants", "bmb_state", "bmb_logging", "bmb_time",
        "run_agent", "model_tools", "toolsets",
        "gateway", "gateway.run", "gateway.config",
        "agent", "agent.memory_manager", "agent.prompt_builder",
        "agent.skill_utils", "agent.skill_commands", "agent.display",
        "agent.credential_pool", "agent.credential_sources",
        "agent.file_safety", "agent.redact", "agent.google_oauth",
        "tools", "tools.registry",
        "aiohttp", "aiohttp.web",
        "yaml", "json", "uuid", "secrets", "asyncio",
        "unittest", "unittest.mock",
        "asyncio.base_events", "asyncio.events", "asyncio.futures",
        "asyncio.locks", "asyncio.protocols", "asyncio.queues",
        "asyncio.runners", "asyncio.streams", "asyncio.tasks",
        "asyncio.transports",
        "concurrent", "concurrent.futures",
        "multiprocessing", "threading",
        "ctypes", "socket", "selectors", "select",
        "email", "email.mime", "email.mime.text",
        "http", "http.client",
        "urllib", "urllib.parse", "urllib.request",
        "xml", "xml.parsers.expat",
        "html.parser",
        "io", "pathlib", "shutil", "tempfile",
        "hashlib", "hmac", "base64", "binascii", "struct",
        "textwrap", "pprint", "copy", "weakref", "types", "enum",
        "dataclasses", "abc", "collections", "itertools", "functools",
        "operator", "inspect", "traceback", "ast",
        "pickle", "sqlite3",
        "zoneinfo", "calendar", "datetime",
        "getpass", "platform", "subprocess", "signal", "contextvars",
        "importlib", "importlib.metadata",
        "pkgutil",
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=["tkinter", "PyQt5", "matplotlib", "scipy", "pandas",
              "notebook", "jupyter", "test", "tests"],
    module_collection_mode={"bmb_cli": "py", "agent": "pyz",
                            "tools": "pyz", "gateway": "pyz"},
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz, a.scripts, a.binaries, a.zipfiles, a.datas, [],
    name="bmb-app-server",
    debug=False, bootloader_ignore_signals=False,
    strip=False, upx=True,
    console=True,
    disable_windowed_traceback=False,
)
