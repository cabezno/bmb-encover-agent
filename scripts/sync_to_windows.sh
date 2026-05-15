#!/bin/bash
# sync_to_windows.sh — Copia BMB Encover a Windows via SCP
# USO: ./scripts/sync_to_windows.sh [usuario@ip-windows:/ruta/destino]
# Ejemplo: ./scripts/sync_to_windows.sh santi@192.168.1.2:/mnt/c/bmb-encover

set -e

SRC="/opt/bmb-encover"
DEST="${1:-santi@192.168.1.2:/mnt/c/bmb-encover}"

echo "📦 Sincronizando BMB Encover a Windows..."
echo "   Origen:  $SRC"
echo "   Destino: $DEST"
echo ""

# Excluir lo que no se necesita en Windows
RSYNC_EXCLUDE="--exclude=venv --exclude=node_modules --exclude=__pycache__ --exclude=.git --exclude=*.pyc --exclude=build/ --exclude=dist/"

# Usar rsync si está disponible, sino scp
if which rsync &>/dev/null; then
    echo "🔁 Usando rsync (rápido, solo cambios)..."
    rsync -avz --progress $RSYNC_EXCLUDE -e ssh "$SRC/" "$DEST/"
else
    echo "🔁 Usando scp (completo)..."
    scp -r "$SRC" "${DEST%:*}"
fi

echo ""
echo "✅ Sincronización completada"
echo ""
echo "En Windows:"
echo "  1. cd C:\\bmb-encover"
echo "  2. python -m venv venv"
echo "  3. .\\venv\\Scripts\\Activate.ps1"
echo "  4. pip install -e .[pty,cli,mcp,cron,acp]"
echo "  5. python app_server.py --port 8643"
