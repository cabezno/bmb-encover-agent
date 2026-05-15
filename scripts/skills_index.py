"""
BMB Skills Index — Catálogo agéntico de skills

Genera un index.json con todos los skills disponibles,
parseable por agentes (BMB, Claude Code, Cursor, etc.)

Formato:
  skills/
  ├── index.json          ← Catálogo completo
  ├── index.embeddings    ← Embeddings para búsqueda semántica
  └── <category>/
      └── <skill-name>/
          └── SKILL.md    ← Skill individual

Uso:
  python3 skills_index.py --scan /opt/bmb-encover/skills --output /opt/bmb-encover/skills/index.json
"""

import os
import json
import hashlib
import re
from pathlib import Path
from datetime import datetime


def scan_skills(skills_dir: str) -> list[dict]:
    """Escanear directorio de skills y generar índice."""
    skills = []
    skills_path = Path(skills_dir)

    for skill_md in skills_path.rglob("SKILL.md"):
        try:
            # Parsear frontmatter YAML manualmente (sin dependencias)
            content = skill_md.read_text(encoding="utf-8")
            frontmatter = parse_frontmatter(content)
            body = extract_body(content)

            # Metadatos
            name = frontmatter.get("name", skill_md.parent.name)
            description = frontmatter.get("description", "")
            tags = frontmatter.get("tags", [])
            version = frontmatter.get("version", "0.0.0")
            author = frontmatter.get("author", "")
            related = frontmatter.get("related_skills", [])

            # Categoría (basada en la ruta del directorio)
            rel_path = skill_md.relative_to(skills_path)
            category = str(rel_path.parent.parent.name)  # skills/<category>/<name>/SKILL.md

            # Detectar tipo de skill por contenido
            skill_type = detect_skill_type(body, tags)

            # Detectar herramientas necesarias
            required_tools = detect_required_tools(body)

            # Hash del contenido para versioning
            content_hash = hashlib.sha256(content.encode()).hexdigest()[:12]

            skill_entry = {
                "id": f"{category}/{name}",
                "name": name,
                "description": description[:200],
                "version": version,
                "author": author,
                "category": category,
                "tags": tags if isinstance(tags, list) else [tags],
                "related_skills": related if isinstance(related, list) else [],
                "type": skill_type,
                "required_tools": required_tools,
                "content_hash": content_hash,
                "path": str(rel_path),
                "updated": datetime.fromtimestamp(skill_md.stat().st_mtime).isoformat(),
                "lines": len(content.split("\n")),
                "has_ascii_art": "```\n" in body and ("╔" in body or "┌" in body),
                "has_examples": "## Example" in body or "## Uso" in body or "## Usage" in body,
            }

            skills.append(skill_entry)

        except Exception as e:
            print(f"  ⚠️  Error parsing {skill_md}: {e}")

    return skills


def parse_frontmatter(content: str) -> dict:
    """Parsear frontmatter YAML (formato: ---\nkey: value\n---)."""
    meta = {}
    match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
    if not match:
        return meta

    yaml_text = match.group(1)
    current_key = None
    current_list = []

    for line in yaml_text.split("\n"):
        # List item
        if line.startswith("  - ") or line.startswith("  -"):
            item = line.strip().lstrip("- ").strip("\"'")
            if current_key:
                if current_key not in meta:
                    meta[current_key] = []
                meta[current_key].append(item)
            continue

        # Key: value
        if ":" in line:
            key, _, value = line.partition(":")
            key = key.strip()
            value = value.strip().strip("\"'")

            if not value:  # podría ser una lista multilinea
                current_key = key
                meta[key] = []
            else:
                meta[key] = value
                current_key = None

    return meta


def extract_body(content: str) -> str:
    """Extraer el body después del frontmatter."""
    match = re.match(r"^---\n.*?\n---\n(.*)", content, re.DOTALL)
    return match.group(1) if match else content


def detect_skill_type(body: str, tags: list) -> str:
    """Detectar tipo de skill basado en contenido y tags."""
    tags_lower = [t.lower() for t in (tags if isinstance(tags, list) else [tags])]

    if any(t in tags_lower for t in ["api", "rest", "integration"]):
        return "integration"
    if any(t in tags_lower for t in ["cli", "terminal", "shell"]):
        return "cli"
    if any(t in tags_lower for t in ["web", "browser", "automation"]):
        return "automation"
    if any(t in tags_lower for t in ["data", "analysis", "analytics"]):
        return "data"
    if "creative" in tags_lower or "design" in tags_lower:
        return "creative"
    if "research" in tags_lower:
        return "research"
    if any(t in tags_lower for t in ["devops", "deploy", "ci/cd"]):
        return "devops"
    if any(t in tags_lower for t in ["ml", "ai", "llm", "model"]):
        return "ml"
    if any(t in tags_lower for t in ["security", "pentest", "auth"]):
        return "security"

    return "general"


def detect_required_tools(body: str) -> list[str]:
    """Detectar herramientas necesarias por el skill."""
    tools = set()
    patterns = {
        "curl": r"curl\s+",
        "git": r"\bgit\s+",
        "docker": r"\bdocker\b",
        "python": r"\bpython3?\b",
        "node": r"\bnode\b|\bnpm\b",
        "aws": r"\baws\s+",
        "gcloud": r"\bgcloud\b",
        "kubectl": r"\bkubectl\b",
        "gh": r"\bgh\s+",
        "jq": r"\bjq\b",
        "psql": r"\bpsql\b",
        "ffmpeg": r"\bffmpeg\b",
        "pip": r"\bpip\s+",
        "npx": r"\bnpx\b",
    }

    for tool, pattern in patterns.items():
        if re.search(pattern, body, re.IGNORECASE):
            tools.add(tool)

    return sorted(tools)


def build_embeddings_index(skills: list[dict], output_path: str):
    """Generar archivo de embeddings a partir de descripciones + tags."""
    entries = []
    for skill in skills:
        text = f"{skill['name']}: {skill['description']} {' '.join(skill['tags'])}"
        entries.append({
            "id": skill["id"],
            "text": text,
            "name": skill["name"],
        })

    # Embeddings simulados (placeholder para integración real con modelo)
    # En producción, reemplazar con vectores reales de un modelo de embeddings
    index = {
        "version": "1.0",
        "model": "text-embedding-3-small (simulado)",
        "total_skills": len(entries),
        "entries": entries,
    }

    with open(output_path, "w") as f:
        json.dump(index, f, indent=2, ensure_ascii=False)

    print(f"  📊 Embeddings index: {len(entries)} skills")


def build_skill_tree(skills: list[dict], output_path: str):
    """Generar árbol de categorías para navegación."""
    tree = {}
    for skill in skills:
        cat = skill["category"]
        if cat not in tree:
            tree[cat] = {
                "name": cat,
                "count": 0,
                "skills": [],
            }
        tree[cat]["count"] += 1
        tree[cat]["skills"].append({
            "id": skill["id"],
            "name": skill["name"],
            "description": skill["description"][:100],
            "type": skill["type"],
        })

    # Ordenar skills dentro de cada categoría
    for cat in tree:
        tree[cat]["skills"].sort(key=lambda s: s["name"])

    with open(output_path, "w") as f:
        json.dump({
            "version": "1.0",
            "total_categories": len(tree),
            "total_skills": len(skills),
            "categories": tree,
        }, f, indent=2, ensure_ascii=False)

    print(f"  🌳 Skill tree: {len(tree)} categorías, {len(skills)} skills")


def build_mcp_manifest(skills: list[dict], output_path: str):
    """
    Generar manifest compatible con MCP (Model Context Protocol)
    para que los skills sean descubribles por clientes MCP.
    """
    tools = []
    for skill in skills:
        tools.append({
            "name": skill["id"].replace("/", "."),
            "description": skill["description"],
            "inputSchema": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": f"Query for {skill['name']}"
                    }
                },
                "required": ["query"]
            },
            "tags": skill["tags"],
            "category": skill["category"],
        })

    manifest = {
        "schemaVersion": "1.0",
        "name": "BMB Skills Hub",
        "description": "Catálogo de skills agénticos para BMB Encover Agent",
        "version": "1.0.0",
        "tools": tools,
        "totalTools": len(tools),
    }

    with open(output_path, "w") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    print(f"  🔧 MCP manifest: {len(tools)} tools registradas")


def generate_hub_readme(skills: list[dict], output_path: str):
    """Generar README.md del skills hub."""
    by_category = {}
    for skill in skills:
        cat = skill["category"]
        if cat not in by_category:
            by_category[cat] = []
        by_category[cat].append(skill)

    lines = [
        "# BMB Skills Hub",
        "",
        "Catálogo de skills agénticos para BMB Encover Agent.",
        "",
        f"**Total: {len(skills)} skills** | **Categorías: {len(by_category)}**",
        "",
        "## 📋 Índice",
        "",
    ]

    for cat in sorted(by_category.keys()):
        cat_skills = by_category[cat]
        lines.append(f"- **{cat}** ({len(cat_skills)} skills)")
        for s in cat_skills:
            tags = " ".join(f"`{t}`" for t in s["tags"][:3])
            lines.append(f"  - [{s['name']}]({s['path']}) — {s['description'][:100]} {tags}")
        lines.append("")

    lines.extend([
        "---",
        "",
        "## 🤖 Para usar con BMB",
        "",
        "Cargar un skill específico:",
        "```",
        "skill_view(name='<skill-id>')",
        "```",
        "",
        "Buscar skills por categoría:",
        "```",
        "skills_list(category='<category>')",
        "```",
        "",
        "## 📦 Formato",
        "",
        "Cada skill es un `SKILL.md` con frontmatter YAML:",
        "```yaml",
        "---",
        "name: nombre-del-skill",
        "description: Breve descripción",
        "version: 1.0.0",
        "tags: [tag1, tag2]",
        "---",
        "```",
        "",
        "## 🔌 MCP Compatible",
        "",
        "Skills expuestos como MCP tools en `mcp-manifest.json`.",
        "",
        "---",
        f"*Generado automáticamente el {datetime.now().strftime('%Y-%m-%d %H:%M')}*",
    ])

    with open(output_path, "w") as f:
        f.write("\n".join(lines))

    print(f"  📖 README: {output_path}")


def main():
    import argparse

    parser = argparse.ArgumentParser(description="BMB Skills Index")
    parser.add_argument("--scan", default="/opt/bmb-encover/skills", help="Directorio de skills")
    parser.add_argument("--output", default="/opt/bmb-encover/skills/index.json", help="Archivo de salida")
    args = parser.parse_args()

    skills_dir = args.scan
    output_path = Path(args.output)
    output_dir = output_path.parent

    print(f"🔍 Escaneando: {skills_dir}")
    print("")

    skills = scan_skills(skills_dir)
    skills.sort(key=lambda s: s["id"])

    print(f"📦 Skills encontrados: {len(skills)}")
    print("")

    # Mostrar resumen por categoría
    by_cat = {}
    for s in skills:
        by_cat.setdefault(s["category"], []).append(s)
    for cat in sorted(by_cat.keys()):
        print(f"  📁 {cat}: {len(by_cat[cat])} skills")

    print("")

    # Generar archivos
    os.makedirs(output_dir, exist_ok=True)

    # 1. Index principal
    with open(output_path, "w") as f:
        json.dump({
            "version": "2.0",
            "generated": datetime.now().isoformat(),
            "total": len(skills),
            "skills": skills,
        }, f, indent=2, ensure_ascii=False)
    print(f"  ✅ Index: {output_path}")

    # 2. Embeddings
    build_embeddings_index(skills, str(output_dir / "index.embeddings.json"))

    # 3. Skill tree
    build_skill_tree(skills, str(output_dir / "skill-tree.json"))

    # 4. MCP manifest
    build_mcp_manifest(skills, str(output_dir / "mcp-manifest.json"))

    # 5. README
    generate_hub_readme(skills, str(output_dir / "README.md"))

    print("")
    print("🎉 Skills index generado!")


if __name__ == "__main__":
    main()
