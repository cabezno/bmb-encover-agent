#!/usr/bin/env python3
"""Envía un comando a Windows via watchdog bridge."""
import sys, os, uuid, json, time
from pathlib import Path

WINDOWS_CMD_DIR = Path("/mnt/c/Users/Pc Nasa/BMB_CMD")
LOGS_DIR = WINDOWS_CMD_DIR / "logs"

def enviar_comando(comando: str, esperar: bool = True, timeout: int = 60) -> dict:
    """Crea .bat, espera log y devuelve resultado."""
    WINDOWS_CMD_DIR.mkdir(parents=True, exist_ok=True)
    LOGS_DIR.mkdir(parents=True, exist_ok=True)
    
    bat_id = uuid.uuid4().hex[:8]
    bat_path = WINDOWS_CMD_DIR / f"cmd_{bat_id}.bat"
    log_path = LOGS_DIR / f"cmd_{bat_id}.log"
    
    # Escribir .bat
    bat_content = f"""@echo off
chcp 65001 >nul
echo === INICIO ===
{comando}
echo === EXIT_CODE: %ERRORLEVEL% ===
"""
    bat_path.write_text(bat_content, encoding="utf-8")
    print(f"  📄 Creado: cmd_{bat_id}.bat → {comando[:60]}...")
    
    if not esperar:
        return {"id": bat_id, "status": "enviado"}
    
    # Esperar el log
    for i in range(timeout):
        time.sleep(1)
        if log_path.exists():
            log_text = log_path.read_text(encoding="utf-8")
            # Extraer exit_code
            exit_code = -1
            for line in log_text.split("\n"):
                if "EXIT_CODE:" in line:
                    try:
                        exit_code = int(line.split("EXIT_CODE:")[1].strip())
                    except:
                        pass
            return {
                "id": bat_id,
                "status": "completado" if exit_code == 0 else "fallido",
                "exit_code": exit_code,
                "output": log_text[:2000],
            }
    
    return {"id": bat_id, "status": "timeout"}

def leer_log(bat_id: str) -> str:
    """Leer log de un comando específico."""
    log_path = LOGS_DIR / f"cmd_{bat_id}.log"
    if log_path.exists():
        return log_path.read_text(encoding="utf-8")
    return "Log no encontrado"

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python3 bmb_cmd.py <comando>")
        print("Ej:  python3 bmb_cmd.py 'bmb_FUNCIONA.exe --version'")
        sys.exit(1)
    
    resultado = enviar_comando(" ".join(sys.argv[1:]))
    print(f"\nResultado: {resultado['status']} (exit: {resultado.get('exit_code', '?')})")
    if "output" in resultado:
        print(f"\nOutput:\n{resultado['output'][:500]}")
