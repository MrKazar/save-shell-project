#!/bin/bash
################################################################################
# START-SERVER.SH - Démarrage du serveur Flask
################################################################################
#
# DESCRIPTION :
#   Lance le serveur Flask qui gère la synchronisation des backups.
#   Vérifie automatiquement les dépendances (Flask).
#   Crée les répertoires distants s'ils n'existent pas.
#
# USAGE :
#   ./start-server.sh
#
# PARAMÈTRES :
#   (aucun)
#
# EXEMPLES :
#   ./start-server.sh
#   # Le serveur démarre sur http://localhost:5000
#
# FONCTIONNEMENT :
#   1. Vérifie que Python 3 est disponible
#   2. Vérifie que Flask est installé
#   3. Crée la structure des dossiers distants
#   4. Lance l'application Flask (app.py)
#   5. Serveur écoute sur localhost:5000
#
# ENDPOINTS DISPONIBLES :
#   GET  /              - Informations API
#   POST /upload        - Recevoir un backup
#   GET  /list          - Lister tous les backups
#   GET  /list/<type>   - Lister par type (FULL/INC/DIFF)
#   GET  /stats         - Statistiques du serveur
#   POST /verify        - Vérifier synchronisation
#
# ARRÊT DU SERVEUR :
#   Ctrl+C dans le terminal
#
# DÉPENDANCES :
#   - Python 3.6+
#   - Flask
#   - Werkzeug
#
# FICHIERS CRÉÉS :
#   - serv/backup-server/remote_backups/FULL/
#   - serv/backup-server/remote_backups/INC/
#   - serv/backup-server/remote_backups/DIFF/
#
# NOTES :
#   - Le serveur stocke les backups dans serv/backup-server/remote_backups/
#   - Accès via http://localhost:5000 (local uniquement par défaut)
#   - Pour accès distant, modifier app.py : app.run(host='0.0.0.0', ...)
#
################################################################################

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
