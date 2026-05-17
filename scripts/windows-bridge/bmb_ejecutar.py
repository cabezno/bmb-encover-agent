#!/usr/bin/env python3
"""bmb_ejecutar.py — Ejecuta comandos en Windows desde BMB (Linux).

Uso:
    python3 bmb_ejecutar.py "bmb_FUNCIONA.exe --version"
    python3 bmb_ejecutar.py "bmb_FUNCIONA.exe app-server --port 8643"
    python3 bmb_ejecutar.py "curl.exe http://localhost:8643/health"

Requiere: watchdog corriendo en Windows (BMB_CMD/watchdog.bat)
"""
import sys
sys.path.insert(0, "/opt/bmb-encover/scripts/windows-bridge")
from bmb_cmd import enviar_comando

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python3 bmb_ejecutar.py <comando>")
        sys.exit(1)
    
    comando = " ".join(sys.argv[1:])
    print(f"🚀 Enviando comando a Windows: {comando[:80]}")
    resultado = enviar_comando(comando, esperar=True, timeout=120)
    
    print(f"\n📋 Resultado:")
    print(f"  Estado: {resultado['status']}")
    print(f"  Exit code: {resultado.get('exit_code', '?')}")
    if "output" in resultado:
        print(f"\n{resultado['output']}")
