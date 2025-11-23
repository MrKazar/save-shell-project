#!/bin/bash
# =============================================================================
# Clear Remote Backups - Nettoie les backups sur le serveur distant
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_DIR="$SCRIPT_DIR/../serv/backup-server/remote_backups"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}ATTENTION !${NC}"
echo "Ce script va supprimer TOUS les backups du serveur distant"
echo "Dossier : $REMOTE_DIR"
echo

read -p "Êtes-vous sûr de vouloir continuer ? (oui/non) : " CONFIRM

if [[ "$CONFIRM" != "oui" ]]; then
    echo "Annulation de l'opération."
    exit 0
fi

echo
echo "Nettoyage en cours..."

for TYPE in FULL INC DIFF; do
    TYPE_DIR="$REMOTE_DIR/$TYPE"
    if [[ -d "$TYPE_DIR" ]]; then
        COUNT=$(find "$TYPE_DIR" -type f | wc -l)
        rm -rf "$TYPE_DIR"/*
        echo -e "${GREEN}✓${NC} $TYPE : $COUNT fichier(s) supprimé(s)"
    else
        echo -e "${YELLOW}⚠${NC} $TYPE : dossier introuvable"
    fi
done

echo
echo -e "${GREEN}Nettoyage terminé !${NC}"