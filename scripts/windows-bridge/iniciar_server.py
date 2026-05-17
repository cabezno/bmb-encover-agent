import sys, time
sys.path.insert(0, "/opt/bmb-encover/scripts/windows-bridge")
from bmb_cmd import enviar_comando

enviar_comando('powershell -Command "Set-Content -Path \"$env:USERPROFILE\\.bmb\\.env\" -Value \'DEEPSEEK_API_KEY=sk-bce5166e987d41a4b22d8f4180642f35\' -Encoding UTF8"', esperar=False)
enviar_comando('powershell -Command "Add-Content -Path \"$env:USERPROFILE\\.bmb\\.env\" -Value \'BMB_ACCESS_TOKEN=bmb2026\' -Encoding UTF8"', esperar=False)

enviar_comando('taskkill /f /im python.exe 2>nul', esperar=False)
enviar_comando('taskkill /f /im python3.exe 2>nul', esperar=False)
enviar_comando('taskkill /f /im python3.11.exe 2>nul', esperar=False)

time.sleep(3)

cmd = 'start "BMB Server" cmd /c "cd /d C:\\Users\\Pc Nasa\\Desktop\\BMB && python app_server.py --port 8643 --verbose"'
enviar_comando(cmd, esperar=False)
print("Server enviado. Esperando...")
time.sleep(8)

r = enviar_comando("curl.exe -s http://127.0.0.1:8643/health", timeout=10)
print(f"Health: {r['output'][:150] if r['status']=='completado' else r['status']}")
