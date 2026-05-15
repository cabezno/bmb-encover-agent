---
name: bmb-skills-hub
description: "Skills Hub agéntico para BMB Encover — index.json, skill-tree, MCP manifest, embeddings index, README auto-generado. Inspirado en clawhub-skills (hanabi-jpn)."
version: 1.0.0
tags:
  - skills
  - index
  - mcp
  - catalog
  - agentic
  - discovery
---

# BMB Skills Hub

Index agéntico de skills para BMB Encover Agent. Genera catálogos parseables por agentes (BMB, Claude Code, Cursor, cualquier cliente MCP).

## Referencia

Inspirado en [clawhub-skills](https://github.com/hanabi-jpn/clawhub-skills) — 43 skills premium en 5 packs (EC, Finance, Marketing, Business Ops, Security) con formato SKILL.md + frontmatter YAML.

## Archivos Generados

| Archivo | Formato | Propósito |
|---------|---------|-----------|
| `index.json` | JSON | Catálogo completo de todos los skills |
| `index.embeddings.json` | JSON | Embeddings para búsqueda semántica |
| `skill-tree.json` | JSON | Árbol de categorías navegable |
| `mcp-manifest.json` | JSON MCP | Skills expuestos como MCP tools |
| `README.md` | Markdown | Documentación legible del hub |

## Uso

```bash
python3 scripts/skills_index.py --scan skills/ --output skills/index.json
```

## Formato de cada skill en el index

```json
{
  "id": "category/skill-name",
  "name": "Skill Name",
  "description": "Breve descripción del skill",
  "version": "1.0.0",
  "author": "",
  "category": "category",
  "tags": ["tag1", "tag2"],
  "related_skills": [],
  "type": "integration|cli|automation|data|creative|research|ml|security|general",
  "required_tools": ["curl", "python", "git"],
  "content_hash": "a1b2c3d4e5f6",
  "path": "category/skill-name/SKILL.md",
  "updated": "2026-05-15T...",
  "lines": 120,
  "has_ascii_art": true,
  "has_examples": true
}
```

## MCP Manifest (para clientes MCP)

Los skills se exponen como MCP tools en `mcp-manifest.json`. Cualquier cliente MCP puede descubrir skills:

```json
{
  "name": "category.skill-name",
  "description": "...",
  "inputSchema": { "type": "object", "properties": {...} },
  "tags": [...],
  "category": "..."
}
```

## Integración con BMB Agent

Cuando un usuario pide algo, BMB puede:
1. Consultar `index.json` para saber qué skills están disponibles
2. Buscar semánticamente en `index.embeddings.json` el skill más relevante
3. Cargar el skill con `skill_view(name='<id>')`
4. Ejecutar la tarea

## Formato SKILL.md (compatible con clawhub-skills)

```yaml
---
name: nombre-del-skill
description: Qué hace y cuándo usarlo
author: BMB Encover
version: 1.0.0
tags: [tag1, tag2]
license: MIT
---
```

## Pitfalls

- El index se genera con `scripts/skills_index.py`. Si se agregan skills nuevos, hay que regenerarlo.
- `index.embeddings.json` contiene vectores simulados por ahora. En producción, reemplazar con embeddings reales de un modelo.
- El MCP manifest sigue el draft de schema v1.0 de Model Context Protocol.
