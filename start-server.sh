#!/bin/bash
# =============================================================================
# Start Script - Démarre le serveur Flask facilement
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/serv/backup-server"

# Couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}  Backup Server - Démarrage${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Vérifier que Flask est installé
echo -n "Vérification de Flask... "
if python3 -c "import flask" 2>/dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}KO${NC}"
    echo "Installation de Flask..."
    pip3 install Flask Werkzeug
fi

# Vérifier les répertoires
echo -n "Création des répertoires... "
mkdir -p "$SERVER_DIR/remote_backups"/{FULL,INC,DIFF}
echo -e "${GREEN}OK${NC}"

# Lancer le serveur
echo
echo -e "${GREEN}Démarrage du serveur sur http://localhost:5000${NC}"
echo

cd "$SERVER_DIR"
python3 app.py
