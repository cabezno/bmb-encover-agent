#!/usr/bin/env python3
"""BMB Encover Skills Index — Catálogo combinado de skills built-in e instalados.

Escanea:
  1) /opt/bmb-encover/skills/   (built-in)
  2) /root/.hermes/skills/       (instaladas)

Para cada skill lee SKILL.md, extrae name, description, tags del frontmatter YAML,
y genera /opt/bmb-encover/skills/index.json con una lista ordenada de objetos
{name, description, tags, path, source}.

Uso:
  python3 scripts/skills_index.py
"""

import json
import os
import re
import sys
from pathlib import Path


# ── Rutas fijas ──────────────────────────────────────────────────────
BUILTIN_DIR = Path("/opt/bmb-encover/skills")
INSTALLED_DIR = Path("/root/.hermes/skills")
OUTPUT_PATH = BUILTIN_DIR / "index.json"


# ── Parser de frontmatter YAML (sin dependencias) ───────────────────

def parse_frontmatter(content: str) -> dict:
    """Parse minimal YAML frontmatter (--- delimitado) sin dependencias.

    Soporta:
      - key: scalar
      - key: [inline, list]
      - key:                    (multiline list)
          - item1
          - item2
      - nested:
          key: value
      - nested:
          inner:
            tags: [a, b]
    """
    match = re.match(r"^---\n(.*?)\n(?:---|\.\.\.)", content, re.DOTALL)
    if not match:
        return {}

    lines = match.group(1).split("\n")

    # Primera pasada: normalizar indentación, filtrar vacías
    cleaned = []
    for line in lines:
        if line.strip() == "":
            continue
        # Reemplazar indent tabs por espacios
        cleaned.append(line.expandtabs(2))

    if not cleaned:
        return {}

    # Construcción recursiva basada en indentación
    return _parse_yaml_block(cleaned)


def _get_indent(line: str) -> int:
    """Obtener nivel de indentación (espacios al inicio)."""
    return len(line) - len(line.lstrip())


def _parse_yaml_block(lines: list, base_indent: int = 0) -> dict:
    """Parsear un bloque YAML a partir de líneas con indentación >= base_indent."""
    result = {}
    i = 0
    while i < len(lines):
        line = lines[i]
        indent = _get_indent(line)
        if indent < base_indent:
            # Regresar al caller (fin del bloque anidado)
            break
        stripped = line.strip()

        # Saltar líneas que no son key: value
        m = re.match(r"^(\S[\w\-/.]*)\s*:\s*(.*)", stripped)
        if not m:
            i += 1
            continue

        key = m.group(1).strip()
        value = m.group(2).strip()

        # ── Si el valor es un inline list: [a, b, c] ──
        if value.startswith("[") and value.endswith("]"):
            items = [x.strip().strip("\"'") for x in value[1:-1].split(",") if x.strip()]
            result[key] = items
            i += 1
            continue

        # ── Si el valor es un scalar (no vacío) ──
        if value and value != "|":
            value = value.strip("\"'")
            if value.lower() == "null":
                result[key] = None
            elif value.lower() == "true":
                result[key] = True
            elif value.lower() == "false":
                result[key] = False
            else:
                result[key] = value
            i += 1
            continue

        # ── Si value está vacío → esperar bloque anidado o lista ──
        # Mirar la siguiente línea para determinar si es lista o dict
        if i + 1 >= len(lines):
            result[key] = None
            i += 1
            break

        next_indent = _get_indent(lines[i + 1])
        next_stripped = lines[i + 1].strip()

        if next_indent > indent and next_stripped.startswith("- "):
            # ── Lista multilinea ──
            items = []
            j = i + 1
            while j < len(lines) and _get_indent(lines[j]) > indent:
                lstripped = lines[j].strip()
                if lstripped.startswith("- "):
                    items.append(lstripped[2:].strip().strip("\"'"))
                j += 1
            result[key] = items
            i = j
            continue

        elif next_indent > indent:
            # ── Dict anidado ──
            sub_lines = lines[i + 1:]
            sub_result = _parse_yaml_block(sub_lines, base_indent=next_indent)
            result[key] = sub_result
            # Avanzar i por las líneas consumidas
            consumed = len(lines) - len(sub_lines) + len(sub_result)  # aproximación
            # Mejor: contar cuántas líneas consumió _parse_yaml_block
            consumed_count = 1  # la línea actual
            j = i + 1
            while j < len(lines) and _get_indent(lines[j]) >= next_indent:
                consumed_count += 1
                j += 1
            i += consumed_count
            continue

        else:
            # Valor vacío, nada debajo
            result[key] = None
            i += 1
            continue

    return result


def extract_tags(frontmatter: dict) -> list:
    """Extraer tags desde frontmatter, soportando múltiples formatos."""
    # 1) Top-level tags como lista (solo si no está vacío — "tags" podría no existir)
    tags = frontmatter.get("tags", None)
    if isinstance(tags, list) and len(tags) > 0:
        return tags

    # 2) Top-level tags como string (raro)
    if isinstance(tags, str) and tags:
        return [tags]

    # 3) metadata.hermes.tags
    metadata = frontmatter.get("metadata", {})
    if isinstance(metadata, dict):
        hermes = metadata.get("hermes", {})
        if isinstance(hermes, dict):
            htags = hermes.get("tags", [])
            if isinstance(htags, list) and len(htags) > 0:
                return htags
            if isinstance(htags, str) and htags:
                return [htags]

    return []


def extract_description(frontmatter: dict) -> str:
    """Extraer description del frontmatter."""
    desc = frontmatter.get("description", "")
    return desc.strip() if isinstance(desc, str) else str(desc) if desc else ""


def extract_name(frontmatter: dict, fallback: str) -> str:
    """Extraer name del frontmatter, fallback al nombre del directorio."""
    name = frontmatter.get("name", fallback)
    return name.strip() if isinstance(name, str) else str(name) if name else fallback


# ── Escaneo de skills ───────────────────────────────────────────────

def scan_skills(skills_dir: Path, source: str) -> list[dict]:
    """Escanear skills/ → SKILL.md recursivo, extraer metadatos."""
    if not skills_dir.is_dir():
        print(f"  ⚠️  Directorio no encontrado: {skills_dir}", file=sys.stderr)
        return []

    skills = []
    paths_seen = set()
    for skill_md in sorted(skills_dir.rglob("SKILL.md")):
        try:
            content = skill_md.read_text(encoding="utf-8")
            frontmatter = parse_frontmatter(content)
            name = extract_name(frontmatter, skill_md.parent.name)
            description = extract_description(frontmatter)
            tags = extract_tags(frontmatter)

            # Ruta relativa al directorio base de skills
            try:
                rel_path = skill_md.relative_to(skills_dir)
            except ValueError:
                rel_path = Path(source) / skill_md.parent.name / "SKILL.md"

            entry = {
                "name": name,
                "description": description,
                "tags": tags,
                "path": str(rel_path),
                "source": source,
            }

            # Evitar duplicados (mismo path relativo dentro de mismo source)
            path_key = str(rel_path)
            if path_key in paths_seen:
                continue
            paths_seen.add(path_key)

            skills.append(entry)
        except Exception as e:
            print(f"  ⚠️  Error parsing {skill_md}: {e}", file=sys.stderr)

    return skills


# ── Main ────────────────────────────────────────────────────────────

def main():
    print("🔍 Escaneando skills...")
    print("")
    print(f"  📂 Built-in:  {BUILTIN_DIR}")
    print(f"  📂 Installed: {INSTALLED_DIR}")
    print("")

    all_skills = []

    # 1) Built-in skills
    builtin = scan_skills(BUILTIN_DIR, "built-in")
    print(f"  ✅ Built-in:  {len(builtin)} skills encontrados")
    all_skills.extend(builtin)

    # 2) Installed skills
    installed = scan_skills(INSTALLED_DIR, "installed")
    print(f"  ✅ Installed: {len(installed)} skills encontrados")
    all_skills.extend(installed)

    # 3) Ordenar alfabéticamente por name
    all_skills.sort(key=lambda s: s["name"].lower())

    print("")
    print(f"  📊 Total: {len(all_skills)} skills combinados")

    # 4) Escribir index.json
    os.makedirs(OUTPUT_PATH.parent, exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(all_skills, f, indent=2, ensure_ascii=False)

    print(f"  ✅ Index escrito: {OUTPUT_PATH}")
    print("")
    print("🎉 Done!")


if __name__ == "__main__":
    main()
