#!/usr/bin/env python3
"""BlackMagicBox Encover Agent — Rename Script v2"""
import os
import re
import sys

BMB = "/opt/bmb-encover"
EXCLUDE_DIRS = {'.git', 'venv', 'node_modules', '__pycache__', '.hermes'}

def should_exclude(path):
    parts = path.replace(BMB, '').lstrip('/').split('/')
    return any(p in EXCLUDE_DIRS for p in parts)

# ----- FASE 1: Renombrar archivos y directorios -----
print("📁 FASE 1: Renombrando archivos...")

renames = [
    ('bmb', 'bmb'),
    ('Hermes', 'Encover'),
    ('HERMES', 'BMB_ENCOVER'),
]

for root, dirs, files in os.walk(BMB, topdown=False):
    if should_exclude(root):
        continue
    
    for name in files + dirs:
        old_path = os.path.join(root, name)
        new_name = name
        for old, new in renames:
            new_name = new_name.replace(old, new)
        if new_name != name:
            new_path = os.path.join(root, new_name)
            try:
                os.rename(old_path, new_path)
                print(f"  📄 {os.path.relpath(old_path, BMB)[:60]} → {new_name}")
            except OSError as e:
                pass  # puede fallar si el archivo ya existe

print("✅ FASE 1 completa")

# ----- FASE 2: Renombrar contenido -----
print("\n📝 FASE 2: Renombrando contenido...")

extensions = {'.py', '.js', '.ts', '.tsx', '.json', '.yaml', '.yml', '.md', '.sh', '.txt', '.html', '.css', '.cfg', '.ini', '.toml', '.xml', '.env.example'}

replacements = [
    # Constantes y env
    ('BMB_ENCOVER_HOME', 'BMB_ENCOVER_HOME'),
    ('BMB_ENCOVER_CONFIG', 'BMB_ENCOVER_CONFIG'),
    
    # Paquete y módulos
    ('bmb_agent.', 'bmb_agent.'),
    ('bmb_agent', 'bmb_agent'),
    ('bmb_cli.', 'bmb_cli.'),
    ('bmb_cli', 'bmb_cli'),
    ('bmb_state', 'bmb_state'),
    ('bmb_logging', 'bmb_logging'),
    ('bmb_constants', 'bmb_constants'),
    ('bmb_time', 'bmb_time'),
    
    # Rutas de usuario
    ('~/.bmb/', '~/.bmb/'),
    ('~/.bmb', '~/.bmb'),
    ('$HOME/.bmb', '$HOME/.bmb'),
    ('$HOME/.bmb', '$HOME/.bmb'),
    ('get_bmb_home', 'get_bmb_home'),
    ('display_bmb_home', 'display_bmb_home'),
    
    # Comandos CLI
    ('"bmb ', '"bmb '),
    ("'bmb ", "'bmb "),
    (' bmb ', ' bmb '),
    ('/bmb ', '/bmb '),
    ('bmb gateway', 'bmb gateway'),
    ('bmb skill', 'bmb skill'),
    ('bmb tool', 'bmb tool'),
    ('bmb profile', 'bmb profile'),
    ('bmb logs', 'bmb logs'),
    ('bmb config', 'bmb config'),
    ('bmb setup', 'bmb setup'),
    ('bmb whatsapp', 'bmb whatsapp'),
    ('bmb webhook', 'bmb webhook'),
    ('bmb cron', 'bmb cron'),
    ('bmb tui', 'bmb tui'),
    ('bmb help', 'bmb help'),
    ('bmb update', 'bmb update'),
    
    # Clases
    ('class EncoverCLI', 'class EncoverCLI'),
    ('EncoverCLI(', 'EncoverCLI('),
    ('class Encover(', 'class Encover('),
    ('class EncoverAgent', 'class EncoverAgent'),
    ('AIAgent', 'AIAgent'),  # no cambiar
    
    # Branding
    ('BlackMagicBox Encover Agent', 'BlackMagicBox Encover Agent'),
    ('BMB_ENCOVER_AGENT', 'BMB_ENCOVER_AGENT'),
    ('Encover', 'Encover'),
    ('Encover', 'Encover'),
    ('blackmagicbox', 'blackmagicbox'),
    
    # Nombre proyecto
    ('bmb-encover', 'bmb-encover'),
    
    # Skills
    ('bmb-encover-skill-authoring', 'bmb-agent-skill-authoring'),
    ('debugging-bmb-tui-commands', 'debugging-bmb-tui-commands'),
    
    # Gateway
    ('bmb-gateway', 'bmb-gateway'),
    ('bmb_kanban', 'bmb_kanban'),
    ('bmb-achievements', 'bmb-achievements'),
]

count = 0
modified_files = set()

for root, dirs, files in os.walk(BMB):
    if should_exclude(root):
        continue
    for fname in files:
        ext = os.path.splitext(fname)[1]
        if ext not in extensions:
            continue
        path = os.path.join(root, fname)
        
        try:
            with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
        except:
            continue
        
        original = content
        for old, new in replacements:
            content = content.replace(old, new)
        
        if content != original:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(content)
            modified_files.add(path)
            count += 1
            rel = os.path.relpath(path, BMB)
            if len(rel) > 70:
                rel = '...' + rel[-67:]
            print(f"  ✏️  {rel}")

print(f"\n✅ FASE 2 completa: {count} archivos modificados")

# ----- Verificación final -----
print("\n🔍 Verificación: referencias restantes a 'bmb' (sin contar venv/node_modules/bmb)...")
remaining = []
for root, dirs, files in os.walk(BMB):
    if should_exclude(root):
        continue
    for fname in files:
        ext = os.path.splitext(fname)[1]
        if ext not in extensions:
            continue
        path = os.path.join(root, fname)
        try:
            with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                for i, line in enumerate(f, 1):
                    lower = line.lower()
                    if 'bmb' in line and 'bmb' not in line and 'bmb_tools' not in line and 'hermesito' not in lower:
                        remaining.append((path, i, line.strip()[:100]))
        except:
            pass

if remaining:
    print(f"  ⚠️  {len(remaining)} referencias encontradas (pueden ser falsos positivos):")
    for path, line, text in remaining[:20]:
        print(f"     {os.path.relpath(path, BMB)}:{line}: {text}")
else:
    print("  ✅ Ninguna referencia residual")

print("\n🎉 Rename completado!")
print("📌 Próximo paso: regenerar venv")
