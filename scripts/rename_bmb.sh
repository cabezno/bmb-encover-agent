#!/bin/bash
# ============================================================
# BlackMagicBox Encover Agent — Rename Script
# BlackMagicBox Encover Agent → BMB Encover Agent
# ============================================================
set -e

BMB_DIR="/opt/bmb-encover"
cd "$BMB_DIR"

echo "🧙 BMB Encover Agent — Rename v1.0"
echo "======================================"

# ---- FASE 1: Renombrar archivos y directorios ----
echo ""
echo "📁 FASE 1: Renombrando archivos y directorios..."

# Archivos con "hermes" en el nombre
find . -depth -name "*hermes*" -not -path "./.git/*" -not -path "./venv/*" | while read f; do
    newname=$(echo "$f" | sed 's/hermes/bmb/g')
    if [ "$f" != "$newname" ]; then
        mkdir -p "$(dirname "$newname")" 2>/dev/null
        mv "$f" "$newname" 2>/dev/null && echo "  📄 $f → $(basename $newname)"
    fi
done

# Archivos con "Hermes" en el nombre (con mayúscula)
find . -depth -name "*Hermes*" -not -path "./.git/*" -not -path "./venv/*" | while read f; do
    newname=$(echo "$f" | sed 's/BMB/Encover/g')
    if [ "$f" != "$newname" ]; then
        mkdir -p "$(dirname "$newname")" 2>/dev/null
        mv "$f" "$newname" 2>/dev/null && echo "  📄 $f → $(basename $newname)"
    fi
done

# Archivos con "HERMES" en el nombre
find . -depth -name "*HERMES*" -not -path "./.git/*" -not -path "./venv/*" | while read f; do
    newname=$(echo "$f" | sed 's/HERMES/BMB_ENCOVER/g')
    if [ "$f" != "$newname" ]; then
        mkdir -p "$(dirname "$newname")" 2>/dev/null
        mv "$f" "$newname" 2>/dev/null && echo "  📄 $f → $(basename $newname)"
    fi
done

echo "✅ FASE 1 completa"

# ---- FASE 2: Renombrar dentro de los archivos ----
echo ""
echo "📝 FASE 2: Renombrando contenido de archivos..."

# Reemplazar en archivos Python, JS, TS, TSX, JSON, YAML, MD, SH, TXT, HTML, CSS
FILE_TYPES="-name '*.py' -o -name '*.js' -o -name '*.ts' -o -name '*.tsx' -o -name '*.json' -o -name '*.yaml' -o -name '*.yml' -o -name '*.md' -o -name '*.sh' -o -name '*.txt' -o -name '*.html' -o -name '*.css' -o -name '*.cfg' -o -name '*.ini' -o -name '*.toml' -o -name '*.cfg'"

TARGET_FILES=$(eval "find . $FILE_TYPES -not -path './.git/*' -not -path './venv/*' -not -path './node_modules/*' -not -path './ui-tui/node_modules/*' -not -path './.hermes/*' 2>/dev/null")

echo "  Archivos a procesar: $(echo "$TARGET_FILES" | wc -l)"

# Replacements (ordenados de más específico a menos específico)
replaces=(
    # Constantes y env vars
    "BMB_ENCOVER_HOME:BMB_ENCOVER_HOME"
    "BMB_ENCOVER_CONFIG:BMB_ENCOVER_CONFIG"
    "HERMES_VERSION:BMB_ENCOVER_VERSION"
    
    # Paquete Python
    "from bmb_agent:from bmb_agent"
    "import bmb_agent:import bmb_agent"
    "bmb_agent::bmb_agent:"
    
    # CLI y comandos
    "bmb gateway:bmb gateway"
    "bmb skill:bmb skill"
    "bmb tool:bmb tool"
    "bmb profile:bmb profile"
    "bmb logs:bmb logs"
    "bmb config:bmb config"
    "bmb update:bmb update"
    "bmb setup:bmb setup"
    "bmb whatsapp:bmb whatsapp"
    "bmb webhook:bmb webhook"
    "bmb cron:bmb cron"
    "bmb tui:bmb tui"
    "bmb help:bmb help"
    "bmb version:bmb version"
    "<hermes:<bmb:"
    "bmb_cli:bmb_cli"
    
    # Nombre del proyecto en general
    "bmb-encover:bmb-encover"
    "bmb_agent:bmb_agent"
    
    # Clases Python
    "class EncoverCLI:class EncoverCLI"
    "class Hermes:class Encover"
    "def hermes_:def bmb_"
    "self.hermes_:self.bmb_"
    
    # Strings y branding
    "BlackMagicBox Encover Agent:BlackMagicBox Encover Agent"
    "Hermes AI:Encover AI"
    "Encover:Encover"
    "Encover:Encover"
    "bmb_agent_logo:bmb_agent_logo"
    "bmb_agent_ascii:bmb_agent_ascii"
    
    # Paths y directorios
    "/hermes/:/bmb/"
    "~/.bmb:~/.bmb"
    "\$HOME/.bmb:\$HOME/.bmb"
    ".hermes/skills:.bmb/skills"
    ".hermes/config.yaml:.bmb/config.yaml"
    ".hermes/.env:.bmb/.env"
    ".hermes/logs:.bmb/logs"
    
    # Comandos de sistema y npm
    "npx hermes:npx bmb"
    "bmb CLI:bmb CLI"
    
    # Urls (sin cambiar el repo real)
    "blackmagicbox/bmb-encover:blackmagicbox/bmb-encover"
)

for replace in "${replaces[@]}"; do
    old="${replace%%:*}"
    new="${replace##*:}"
    echo -n "  🔄 '$old' → '$new': "
    count=$((0))
    while IFS= read -r file; do
        if grep -l "$old" "$file" 2>/dev/null; then
            sed -i "s/$old/$new/g" "$file" 2>/dev/null
            ((count++))
        fi
    done <<< "$TARGET_FILES"
    echo "$count archivos modificados"
done

echo "✅ FASE 2 completa"

# ---- FASE 3: Limpiar y verificar ----
echo ""
echo "🧹 FASE 3: Limpieza final..."
find . -name "*.bak" -delete 2>/dev/null
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
echo "✅ Limpieza completa"

echo ""
echo "======================================"
echo "🎉 Rename completado!"
echo "Quedan referencias a 'hermes':"
grep -r "hermes" --include="*.py" --include="*.js" --include="*.ts" --include="*.tsx" \
  --include="*.json" --include="*.yaml" --include="*.yml" --include="*.md" --include="*.sh" \
  . 2>/dev/null | grep -v "venv/" | grep -v "node_modules/" | grep -v "binary" | \
  grep -iv "hermesito\|bmb_tools\|bmb_agent" | head -30

echo ""
echo "📌 Recordatorio: regenerar venv con:"
echo "   cd /opt/bmb-encover"
echo "   rm -rf venv"
echo "   python3 -m venv venv"
echo "   source venv/bin/activate"
echo "   pip install -e ."
