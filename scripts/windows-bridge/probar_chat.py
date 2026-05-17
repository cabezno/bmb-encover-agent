#!/usr/bin/env python3
"""Prueba chat. Escribe JSON con Python en %TEMP% y hace POST."""
import sys, json, time
sys.path.insert(0, "/opt/bmb-encover/scripts/windows-bridge")
from bmb_cmd import enviar_comando

# Paso 1: Escribir el JSON con echo directo
enviar_comando('echo {"message":"Hola"} > "%TEMP%\\bmb_payload.json"', esperar=False)
time.sleep(1)

# Paso 2: Verificar archivo
r = enviar_comando('type "%TEMP%\\bmb_payload.json"', timeout=5)
print(f"Payload: {r.get('output','?')[:100].strip()}")

# Paso 3: POST
r = enviar_comando(
    'curl.exe -s -X POST http://localhost:8643/api/chat -H "Content-Type: application/json" -d @%TEMP%\\bmb_payload.json',
    timeout=30
)
out = r.get("output","")
if "response" in out:
    print(f"✅ {out[:300]}")
else:
    print(out[:500])
