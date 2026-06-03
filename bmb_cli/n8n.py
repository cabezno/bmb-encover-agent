"""Módulo n8n — Instalación, gestión y orquestación de n8n para BMB Undercover Agent.

BMB instala y gestiona n8n localmente. n8n ejecuta workflows de publicación
en redes sociales (Twitter, Instagram, Facebook, LinkedIn, YouTube, WordPress)
disparados por webhooks desde BMB.

Puertos:
  - n8n web UI: 5678
  - BMB app server: 8644
  - Webhooks n8n: http://localhost:5678/webhook/bmb-*
"""

import json
import logging
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

logger = logging.getLogger("bmb-n8n")

N8N_DATA_DIR = Path.home() / ".bmb" / "n8n"
N8N_WORKFLOWS_DIR = N8N_DATA_DIR / "workflows"
N8N_CONFIG_FILE = N8N_DATA_DIR / "config.json"

# Puerto por defecto de n8n
N8N_PORT = 5678
BMB_API_PORT = 8644


# ─── Estado ───────────────────────────────────────────────────────

def _load_state() -> dict:
    """Cargar estado de n8n desde ~/.bmb/n8n/config.json"""
    if N8N_CONFIG_FILE.exists():
        try:
            return json.loads(N8N_CONFIG_FILE.read_text())
        except Exception:
            pass
    return {"installed": False, "version": "", "workflows": [], "status": "unknown"}


def _save_state(state: dict):
    """Guardar estado de n8n."""
    N8N_CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
    N8N_CONFIG_FILE.write_text(json.dumps(state, indent=2, ensure_ascii=False))


# ─── Instalación ──────────────────────────────────────────────────

def cmd_install(args):
    """Instalar n8n localmente (via npm o docker)."""
    state = _load_state()
    method = getattr(args, "method", "auto")

    print("╔══════════════════════════════════════╗")
    print("║  BMB n8n — Instalación              ║")
    print("╚══════════════════════════════════════╝")
    print()

    # Verificar si ya está instalado
    if shutil.which("n8n"):
        print("✓ n8n ya está instalado en el sistema")
        result = subprocess.run(["n8n", "--version"], capture_output=True, text=True, timeout=15)
        state["installed"] = True
        state["version"] = result.stdout.strip() or "desconocida"
        _save_state(state)
        return

    # Intentar npm
    npm = shutil.which("npm")
    if npm and method in ("auto", "npm"):
        print("→ Instalando n8n via npm...")
        try:
            result = subprocess.run(
                [npm, "install", "-g", "n8n"],
                capture_output=True, text=True, timeout=120,
            )
            if result.returncode == 0:
                print("✓ n8n instalado correctamente via npm")
                ver = subprocess.run(["n8n", "--version"], capture_output=True, text=True, timeout=15)
                state["installed"] = True
                state["version"] = ver.stdout.strip() or "npm"
                state["method"] = "npm"
                _save_state(state)
                return
            else:
                print(f"✗ npm install falló: {result.stderr[:200]}")
        except subprocess.TimeoutExpired:
            print("✗ npm install timed out")

    # Intentar Docker
    docker = shutil.which("docker")
    if docker and method in ("auto", "docker"):
        print("→ Instalando n8n via Docker...")
        try:
            subprocess.run(
                ["docker", "pull", "n8nio/n8n"],
                capture_output=True, text=True, timeout=120,
            )
            print("✓ Imagen n8n descargada")
            state["installed"] = True
            state["version"] = "docker"
            state["method"] = "docker"
            _save_state(state)
            return
        except Exception as e:
            print(f"✗ Docker pull falló: {e}")

    print()
    print("✗ No se pudo instalar n8n.")
    print("  Instalá manualmente: npm install -g n8n")
    print("  O con Docker: docker run -d --name n8n -p 5678:5678 n8nio/n8n")


# ─── Iniciar / Detener ────────────────────────────────────────────

def cmd_start(args):
    """Iniciar n8n."""
    state = _load_state()
    print("→ Iniciando n8n...")

    method = state.get("method", "npm")

    if method == "docker":
        try:
            subprocess.run(
                ["docker", "start", "n8n"],
                capture_output=True, text=True, timeout=30,
            )
            print("✓ n8n iniciado (Docker)")
        except Exception as e:
            print(f"✗ Error iniciando n8n docker: {e}")
    else:
        # npm: lanzar en background
        try:
            proc = subprocess.Popen(
                ["n8n", "start"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            state["pid"] = proc.pid
            _save_state(state)
            print(f"✓ n8n iniciado (PID: {proc.pid})")
            print(f"  UI: http://localhost:{N8N_PORT}")
        except FileNotFoundError:
            print("✗ n8n no encontrado. Ejecute 'bmb n8n install' primero")


def cmd_stop(args):
    """Detener n8n."""
    state = _load_state()

    if state.get("method") == "docker":
        try:
            subprocess.run(["docker", "stop", "n8n"], capture_output=True, text=True, timeout=30)
            print("✓ n8n detenido (Docker)")
        except Exception as e:
            print(f"✗ Error: {e}")
        return

    pid = state.get("pid")
    if pid:
        try:
            subprocess.run(["kill", str(pid)], timeout=5)
            print(f"✓ n8n detenido (PID: {pid})")
        except Exception:
            print(f"  PID {pid} no encontrado, puede que ya esté detenido")

    # También matar procesos n8n sueltos
    try:
        subprocess.run(["pkill", "-f", "n8n"], timeout=5)
    except Exception:
        pass

    state["pid"] = None
    _save_state(state)


def cmd_restart(args):
    """Reiniciar n8n."""
    cmd_stop(args)
    time.sleep(2)
    cmd_start(args)


# ─── Estado ───────────────────────────────────────────────────────

def cmd_status(args):
    """Mostrar estado de n8n."""
    state = _load_state()

    print("╔══════════════════════════════════════╗")
    print("║  BMB n8n — Estado                   ║")
    print("╚══════════════════════════════════════╝")
    print()

    if not state.get("installed"):
        print("❌ n8n no instalado")
        print("  Ejecute: bmb n8n install")
        return

    print(f"  Versión: {state.get('version', 'desconocida')}")
    print(f"  Método:  {state.get('method', 'desconocido')}")
    print(f"  Puerto:  {N8N_PORT}")

    # Verificar si está corriendo
    running = False
    if state.get("method") == "docker":
        try:
            r = subprocess.run(
                ["docker", "ps", "--filter", "name=n8n", "--format", "{{.Status}}"],
                capture_output=True, text=True, timeout=10,
            )
            if r.stdout.strip():
                running = True
                print(f"  Estado:  ✅ Corriendo ({r.stdout.strip()})")
        except Exception:
            pass
    else:
        pid = state.get("pid")
        if pid:
            try:
                os.kill(pid, 0)
                running = True
                print(f"  Estado:  ✅ Corriendo (PID: {pid})")
            except OSError:
                pass

    if not running:
        print(f"  Estado:  ❌ Detenido")
        print()
        print("  Para iniciar: bmb n8n start")
        print(f"  UI web:       http://localhost:{N8N_PORT}")

    print()
    print(f"  Workflows: {len(state.get('workflows', []))}")
    print(f"  Webhooks n8n → BMB: http://localhost:{BMB_API_PORT}/api/n8n/*")
    print(f"  Webhooks BMB → n8n: http://localhost:{N8N_PORT}/webhook/bmb-*")


# ─── Publicar contenido ───────────────────────────────────────────

def cmd_publish(args):
    """Enviar contenido para publicar via n8n."""
    text = args.text
    platforms = getattr(args, "platforms", "twitter")

    print(f"→ Enviando contenido a n8n para publicar en: {platforms}")
    print(f"  Texto: {text[:100]}{'...' if len(text) > 100 else ''}")
    print()

    # Llamar al webhook de n8n
    import urllib.request
    import urllib.error

    data = json.dumps({
        "text": text,
        "platforms": platforms.split(",") if isinstance(platforms, str) else platforms,
        "type": "publish",
    }).encode()

    try:
        req = urllib.request.Request(
            f"http://localhost:{N8N_PORT}/webhook/bmb-publish",
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            result = resp.read().decode()
            print(f"✓ Publicado exitosamente")
            print(f"  Respuesta: {result[:200]}")
    except urllib.error.URLError as e:
        print(f"✗ Error conectando con n8n: {e}")
        print("  ¿Está n8n corriendo?")
        print("  bmb n8n status")
    except Exception as e:
        print(f"✗ Error: {e}")


# ─── Generar contenido ────────────────────────────────────────────

def cmd_generate(args):
    """Generar contenido con la IA y enviarlo a n8n para publicar."""
    prompt = args.prompt
    platforms = getattr(args, "platforms", "twitter")

    print(f"→ Generando contenido para: {platforms}")
    print(f"  Prompt: {prompt}")
    print()

    # Llamar al app_server de BMB para generar con IA
    import urllib.request
    import urllib.error

    data = json.dumps({
        "prompt": f"Generá contenido para redes sociales ({platforms}) sobre: {prompt}",
        "platforms": platforms.split(","),
        "type": "generate_and_publish",
    }).encode()

    try:
        req = urllib.request.Request(
            f"http://localhost:{BMB_API_PORT}/api/n8n/generate",
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=60) as resp:
            result = resp.read().decode()
            parsed = json.loads(result)
            print(f"✓ Contenido generado")
            if "content" in parsed:
                print(f"\n{parsed['content'][:300]}")
            if "post_id" in parsed:
                print(f"\n  Post ID: {parsed['post_id']}")
            print(f"\n  Respuesta completa: {result[:500]}")
    except urllib.error.URLError as e:
        print(f"✗ Error conectando con BMB: {e}")
    except Exception as e:
        print(f"✗ Error: {e}")


# ─── Programar semana ─────────────────────────────────────────────

def cmd_schedule_week(args):
    """Programar una semana completa de contenido."""
    topic = args.topic
    platforms = getattr(args, "platforms", "twitter,linkedin,facebook")

    print(f"→ Programando semana de contenido sobre: {topic}")
    print(f"  Plataformas: {platforms}")
    print()

    prompt = (
        f"Generá 7 publicaciones para redes sociales ({platforms}) sobre '{topic}', "
        f"una para cada día de la semana. "
        f"Incluí título, texto, hashtags y sugerí imágenes. "
        f"Formato JSON con día, plataforma, contenido."
    )

    # Aquí llamaríamos al agente para generar y después a n8n para programar
    print("  Función en desarrollo — próximamente")
    print("  Por ahora, use: bmb n8n publish")
