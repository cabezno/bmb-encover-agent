#!/usr/bin/env python3
"""Barrido final: cambiar todo hermes_ → bmb_ en archivos .py, .md, .json, .yaml, .sh"""
import os
import re

BMB = "/opt/bmb-encover"
EXCLUDE = {'venv', 'node_modules', '.git', '__pycache__', '.hermes'}

def should_exclude(path):
    parts = path.replace(BMB, '').lstrip('/').split('/')
    return any(p in EXCLUDE for p in parts)

# Patrones: (regex, replacement)
# Orden: más específicos primero
patterns = [
    # Ya no tienen sentido estos reemplazos porque la mayoría ya se hizo
    # Pero algunos casos puntuales que quedaron:
    
    # Variables/parámetros con hermes_ como prefijo
    (r'bmb_home\b', 'bmb_home'),
    (r'_bmb_home\b', '_bmb_home'),
    (r'bmb_dir\b', 'bmb_dir'),
    (r'_bmb_dir\b', '_bmb_dir'),
    (r'bmb_root\b', 'bmb_root'),
    (r'_bmb_root\b', '_bmb_root'),
    (r'bmb_cfg\b', 'bmb_cfg'),
    (r'bmb_bin\b', 'bmb_bin'),
    (r'_bmb_bin\b', '_bmb_bin'),
    (r'bmb_cmd\b', 'bmb_cmd'),
    (r'bmb_config\b', 'bmb_config'),
    (r'bmb_meta\b', 'bmb_meta'),
    (r'bmb_action\b', 'bmb_action'),
    (r'bmb_procs\b', 'bmb_procs'),
    (r'bmb_node_bin\b', 'bmb_node_bin'),
    
    # Strings con hermes (en comillas simples o dobles que son nombres internos)
    (r'"bmb_', '"bmb_'),
    (r"'bmb_", "'bmb_"),
    (r'`bmb_', '`bmb_'),
    
    # Nombres de archivos/directorios temporales
    (r'bmb_voice', 'bmb_voice'),
    (r'bmb_sandbox', 'bmb_sandbox'),
    (r'bmb_rpc', 'bmb_rpc'),
    (r'bmb_bg_', 'bmb_bg_'),
    (r'bmb_exec_', 'bmb_exec_'),
    (r'bmb_shrink_', 'bmb_shrink_'),
    (r'bmb_conversation_', 'bmb_conversation_'),
    (r'bmb_gateway_transport', 'bmb_gateway_transport'),
    (r'bmb_pkce', 'bmb_pkce'),
    (r'bmb_memory', 'bmb_memory'),
    (r'bmb_tool', 'bmb_tool'),
    (r'bmb_approve', 'bmb_approve'),
    (r'bmb_confirm', 'bmb_confirm'),
    (r'bmb_deny', 'bmb_deny'),
    (r'bmb_task_id', 'bmb_task_id'),
    (r'bmb_pgid', 'bmb_pgid'),
    (r'bmb_ec', 'bmb_ec'),
    (r'bmb_ink', 'bmb_ink'),
    (r'bmb_estree', 'bmb_estree'),
    (r'bmb_parser', 'bmb_parser'),
    (r'bmb_run_generation', 'bmb_run_generation'),
    (r'bmb_server_name', 'bmb_server_name'),
    (r'bmb_env_access', 'bmb_env_access'),
    (r'bmb_config_mod', 'bmb_config_mod'),
    (r'bmb_dialog', 'bmb_dialog'),
    (r'bmb_bot', 'bmb_bot'),
    (r'bmb_meet', 'bmb_meet'),
    
    # User agent / version
    (r'bmb_xai_user_agent', 'bmb_xai_user_agent'),
    (r'bmb_version', 'bmb_version'),
    (r'bmb_agent', 'bmb_agent'),
    
    # Gateway hooks / modules
    (r'bmb_hook_', 'bmb_hook_'),
    (r'_bmb_user_memory', '_bmb_user_memory'),
    
    # Misc - comentarios y strings sueltos
    (r'BMB/', 'BMB/'),
    (r'BMB/', 'BMB/'),
    (r'@bmb', '@bmb'),
    (r'hermes\.local', 'bmb.local'),

    # Archivos .md con comandos
    (r'^hermes ', 'bmb '),
    (r'^/hermes', '/bmb'),
    
    # URLs de gateway
    (r'source=bmb', 'source=bmb'),
    (r'&tp=bmb', '&tp=bmb'),
    (r'from=bmb', 'from=bmb'),
    
    # Eventos SSE
    (r'hermes\.tool\.progress', 'bmb.tool.progress'),
    (r'hermes\.api_server', 'bmb.api_server'),
    (r'hermes\.run', 'bmb.run'),
    
    # Después de todo, cambiar "hermes" suelto que no sea parte de otra palabra
    # Solo en strings y comentarios, no en nombres de variables largos
]

def process_file(path, ext):
    try:
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
    except:
        return False
    
    original = content
    for pat, repl in patterns:
        if isinstance(pat, tuple):
            # (pattern, replacement, kwargs)
            flags = pat.get('flags', 0)
            content = re.sub(pat[0], repl, content, flags=flags)
        else:
            content = re.sub(pat, repl, content)
    
    if content != original:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    return False

count = 0
extensions = {'.py', '.md', '.json', '.yaml', '.yml', '.sh', '.txt', '.js', '.ts', '.tsx', '.html', '.css'}

for root, dirs, files in os.walk(BMB):
    if should_exclude(root):
        continue
    for fname in files:
        ext = os.path.splitext(fname)[1]
        if ext not in extensions:
            continue
        path = os.path.join(root, fname)
        if process_file(path, ext):
            count += 1
            rel = os.path.relpath(path, BMB)
            if len(rel) > 70:
                rel = '...' + rel[-67:]
            print(f"  ✏️  {rel}")

print(f"\n✅ {count} archivos modificados")

# Verificación final
print("\n🔍 Verificación de referencias residuales...")
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
                    if 'hermes' in line.lower():
                        # Saltar falsos positivos obvios
                        lower = line.lower()
                        if any(x in lower for x in ['bmb', 'encover', 'hermesito', 'bmb_tools',
                                                      '@bmbproject', 'hermesproject', 'hermes.dev',
                                                      'hermes-parser', 'hermes-estree', 'hermes-ink',
                                                      'bmb_ink', 'bmb_estree', 'bmb_parser',
                                                      '_bmb_', 'bmb_agent']):
                            continue
                        remaining.append((path, i, line.strip()[:100]))
        except:
            pass

if remaining:
    print(f"  ⚠️  {len(remaining)} referencias (pueden ser residuos en READMEs de plugins):")
    for path, line, text in remaining[:10]:
        print(f"     {os.path.relpath(path, BMB)}:{line}: {text}")
    if len(remaining) > 10:
        print(f"     ... y {len(remaining)-10} más")
else:
    print("  ✅ Cero referencias residuales")
