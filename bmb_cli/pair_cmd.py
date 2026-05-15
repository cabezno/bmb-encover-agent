"""
BMB Pairing — Generación de QR y comando `bmb pair`

Muestra un QR en la terminal para que la app mobile lo escanee.
El QR contiene: bmb://<ip>:<port>/pair?token=<token>

USO:
  bmb pair                          # Muestra QR para vincular dispositivo
  bmb pair --qr-ascii               # QR en ASCII (terminal)
  bmb pair --qr-image               # QR como imagen PNG
  bmb pair --list                   # Lista dispositivos vinculados
  bmb pair --revoke <device_id>    # Revoca un dispositivo
"""

import json
import os
import socket
import sys
import time
import secrets
from pathlib import Path

# Intentar importar QR
try:
    import qrcode
    QR_AVAILABLE = True
except ImportError:
    QR_AVAILABLE = False

AUTH_FILE = Path(os.path.expanduser("~/.bmb/app_auth.json"))

# Token temporal (en producción, usar app_server.AppServer.generate_pairing_token)
_pairing_tokens: dict[str, dict] = {}


def get_local_ip() -> str:
    """Obtener IP local preferiblemente no loopback."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


def get_tailscale_ip() -> str:
    """Obtener IP de Tailscale si está disponible."""
    try:
        import subprocess
        result = subprocess.run(
            ["tailscale", "ip", "-4"],
            capture_output=True, text=True, timeout=2
        )
        ip = result.stdout.strip()
        if ip:
            return ip
    except Exception:
        pass
    return ""


def load_devices() -> dict:
    """Cargar dispositivos vinculados."""
    if AUTH_FILE.exists():
        try:
            return json.loads(AUTH_FILE.read_text()).get("devices", {})
        except Exception:
            return {}
    return {}


def save_devices(devices: dict):
    """Guardar dispositivos vinculados."""
    AUTH_FILE.parent.mkdir(parents=True, exist_ok=True)
    AUTH_FILE.write_text(json.dumps({"devices": devices}, indent=2))


def generate_token() -> dict:
    """Generar un token de pairing válido por 5 minutos."""
    token = secrets.token_hex(16)
    expiry = time.time() + 300
    ip = get_tailscale_ip() or get_local_ip()
    port = os.environ.get("BMB_APP_PORT", "8643")
    qr_data = f"bmb://{ip}:{port}/pair?token={token}"
    
    _pairing_tokens[token] = {"expiry": expiry, "ip": ip, "port": port}
    
    return {
        "token": token,
        "expires_at": expiry,
        "ip": ip,
        "port": port,
        "qr_data": qr_data,
    }


def show_qr_ascii(qr_data: str):
    """Mostrar QR en ASCII en la terminal."""
    if not QR_AVAILABLE:
        print("[ERROR] qrcode no instalado. Ejecute: pip install qrcode[pil]")
        return
    
    qr = qrcode.QRCode(box_size=1, border=2)
    qr.add_data(qr_data)
    qr.make()
    
    print()
    print("  Escaneá este QR con la app BMB:")
    print()
    qr.print_ascii(invert=True)
    print()
    print(f"  📡 {qr_data}")
    print()


def show_qr_image(qr_data: str):
    """Mostrar QR como imagen PNG (abre el archivo)."""
    if not QR_AVAILABLE:
        print("[ERROR] qrcode no instalado. Ejecute: pip install qrcode[pil]")
        return
    
    import qrcode.image.pil
    
    img = qrcode.make(qr_data)
    path = "/tmp/bmb_qr.png"
    img.save(path)
    
    print(f"  📸 QR guardado en: {path}")
    try:
        # Intentar abrir con visor de imágenes
        import subprocess
        subprocess.Popen(["xdg-open", path])
        print("  👁️  Abriendo visor de imágenes...")
    except Exception:
        print("  💡 Abrí el archivo manualmente: xdg-open " + path)


def cmd_pair(args: list[str] = None):
    """Comando `bmb pair` principal."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Vincular dispositivos a BMB")
    parser.add_argument("action", nargs="?", default="show",
                        choices=["show", "list", "revoke", "image"],
                        help="Acción: show (default), list, revoke <id>, image")
    parser.add_argument("device_id", nargs="?", default="",
                        help="ID del dispositivo a revocar")
    
    parsed = parser.parse_args(args)
    
    if parsed.action == "list":
        devices = load_devices()
        if not devices:
            print("  📱 No hay dispositivos vinculados.")
            print("  💡 Ejecute `bmb pair` para generar un QR.")
            return
        
        print(f"  📱 Dispositivos vinculados ({len(devices)}):")
        print()
        for dev_id, info in devices.items():
            name = info.get("name", "Desconocido")
            dev_type = info.get("type", "?")
            paired = time.strftime("%Y-%m-%d %H:%M", time.localtime(info.get("paired_at", 0)))
            last_seen = time.strftime("%Y-%m-%d %H:%M", time.localtime(info.get("last_seen", 0)))
            print(f"  🆔 {dev_id}")
            print(f"     Nombre: {name}")
            print(f"     Tipo: {dev_type}")
            print(f"     Vinculado: {paired}")
            print(f"     Última vez: {last_seen}")
            print()
    
    elif parsed.action == "revoke":
        if not parsed.device_id:
            print("[ERROR] Especificá el ID del dispositivo a revocar.")
            print("        Ej: bmb pair revoke a1b2c3d4")
            return
        
        devices = load_devices()
        if parsed.device_id in devices:
            info = devices.pop(parsed.device_id)
            save_devices(devices)
            print(f"  ✅ Dispositivo '{info.get('name', parsed.device_id)}' revocado.")
        else:
            print(f"  ❌ No se encontró dispositivo con ID: {parsed.device_id}")
            print("     Usá `bmb pair list` para ver los IDs disponibles.")
    
    elif parsed.action == "image":
        token = generate_token()
        show_qr_image(token["qr_data"])
        print(f"  ⏳ Token válido por 5 minutos")
        print(f"  🔌 IP: {token['ip']}:{token['port']}")
    
    else:  # show (default)
        print()
        print("  ╔══════════════════════════════════════╗")
        print("  ║   BMB Encover — Vincular dispositivo ║")
        print("  ╚══════════════════════════════════════╝")
        print()
        
        token = generate_token()
        
        print(f"  🔌 IP:          {token['ip']}:{token['port']}")
        print(f"  ⏳ Expira:       {time.strftime('%H:%M:%S', time.localtime(token['expires_at']))}")
        print()
        
        show_qr_ascii(token["qr_data"])
        
        print("  Abrí la app BMB en tu móvil y escaneá el QR.")
        print("  O ingresá manualmente:")
        print(f"    IP: {token['ip']}")
        print(f"    Puerto: {token['port']}")
        print(f"    Token: {token['token']}")
        print()
        print("  💡 Para conexión remota, instalá Tailscale")
        print("     en PC y móvil con la misma cuenta.")
        print()


if __name__ == "__main__":
    cmd_pair(sys.argv[1:] if len(sys.argv) > 1 else None)
