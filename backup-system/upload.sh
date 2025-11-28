#!/bin/bash
################################################################################
# UPLOAD.SH - Envoie les Backups vers le Serveur Distant
################################################################################
#
# DESCRIPTION :
#   Télécharge les archives de backup vers le serveur Flask distant.
#   Supporte upload de types FULL, INC, DIFF.
#   Vérifie disponibilité du serveur avant upload.
#   Récupère et sauvegarde les checksums distants.
#
# USAGE :
#   ./upload.sh [type]
#
# PARAMÈTRES :
#   type (optionnel) : Type(s) à uploader
#                      Valeurs : full, incremental, diff
#                      Si absent : upload tous les types
#
# EXEMPLES :
#   # Upload archives FULL
#   ./upload.sh full
#
#   # Upload archives INCREMENTAL
#   ./upload.sh incremental
#
#   # Upload archives DIFFERENTIAL
#   ./upload.sh diff
#
#   # Upload tous les types
#   ./upload.sh
#
#   # Depuis serveur personnalisé
#   SERVER_URL=http://192.168.1.100:5000 ./upload.sh full
#
# VARIABLES D'ENVIRONNEMENT :
#   SERVER_URL   : URL du serveur (défaut: http://localhost:5000)
#   BACKUP_DIR   : Dossier des backups (défaut: ./backup)
#
# EXEMPLES AVEC VARIABLES :
#   SERVER_URL=http://192.168.1.100:5000 ./upload.sh full
#   BACKUP_DIR=/data/backups ./upload.sh
#
# FONCTIONNEMENT :
#   1. Vérifie la disponibilité du serveur
#   2. Parcourt le dossier backup/[FULL|INC|DIFF]/
#   3. Envoie chaque fichier .tar.gz via HTTP multipart
#   4. Paramètres envoyés à /upload :
#      - file : Contenu du fichier
#      - type : Type de backup (FULL|INC|DIFF)
#      - profile : Nom du profil (extrait du .tar.gz)
#   5. Récupère le MD5 du serveur (JSON response)
#   6. Sauvegarde dans backup/*/< timestamp>.md5 local
#
# CODES HTTP :
#   201 : Upload réussi ✓
#   400 : Erreur paramètres
#   413 : Fichier trop gros
#   500 : Erreur serveur
#
# FICHIERS LUS :
#   - backup/FULL/*.tar.gz : Archives FULL
#   - backup/INC/*.tar.gz : Archives INC
#   - backup/DIFF/*.tar.gz : Archives DIFF
#
# FICHIERS CRÉÉS/MODIFIÉS :
#   - backup/FULL/*.md5 : Hash distant sauvegardé localement
#   - backup/INC/*.md5 : Hash distant sauvegardé localement
#   - backup/DIFF/*.md5 : Hash distant sauvegardé localement
#
# DÉPENDANCES :
#   - curl : Requêtes HTTP multipart
#   - jq : Parsing JSON (optionnel pour affichage)
#   - Server Flask : Application Flask avec endpoint /upload
#
# ERREURS POSSIBLES :
#   "Serveur indisponible" - Le serveur n'est pas accessible
#   "Pas d'archives trouvées" - Aucun fichier .tar.gz dans backup/
#   "Erreur lors de l'upload" - Problème lors du POST
#
# NOTES :
#   - L'upload utilise multipart/form-data pour les gros fichiers
#   - Les checksums distants sont sauvegardés localement pour vérification
#   - Mode sûr (set -euo pipefail) : erreur = arrêt immédiat
#
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
SERVER_URL="${SERVER_URL:-http://localhost:5000}"
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/backup}"
BACKUP_TYPES=("FULL" "INC" "DIFF")
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/upload_$(date +%Y-%m-%d).log"

# Créer le dossier logs s'il n'existe pas
mkdir -p "$LOG_DIR"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    local msg="$*"
    echo -e "${BLUE}[INFO]${NC}  $msg"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $msg" >> "$LOG_FILE"
}

log_success() {
    local msg="$*"
    echo -e "${GREEN}[SUCCESS]${NC} $msg"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $msg" >> "$LOG_FILE"
}

log_error() {
    local msg="$*"
    echo -e "${RED}[ERROR]${NC} $msg" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $msg" >> "$LOG_FILE"
}

log_warn() {
    local msg="$*"
    echo -e "${YELLOW}[WARN]${NC}  $msg"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $msg" >> "$LOG_FILE"
}

check_server() {
    if curl -s "$SERVER_URL/" > /dev/null 2>&1; then
        log_success "Serveur disponible : $SERVER_URL"
        return 0
    else
        log_error "Serveur indisponible : $SERVER_URL"
        return 1
    fi
}

upload_file() {
    local filepath="$1"
    local backup_type="$2"
    local profile="$3"
    
    if [[ ! -f "$filepath" ]]; then
        log_error "Fichier non trouvé : $filepath"
        return 1
    fi
    
    log_info "Upload de $backup_type : $(basename "$filepath")"
    
    response=$(curl -s -w "\n%{http_code}" -F "file=@$filepath" \
        -F "type=$backup_type" \
        -F "profile=$profile" \
        "$SERVER_URL/upload")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [[ "$http_code" == "201" ]]; then
        log_success "Upload réussi : $(basename "$filepath")"
        echo "$body" | jq -r '.md5' > "$(dirname "$filepath")/$(basename "$filepath" .tar.gz).md5" 2>/dev/null || true
        return 0
    else
        log_error "Erreur upload (HTTP $http_code) : $(basename "$filepath")"
        echo "$body" | jq -r '.error // .message' 2>/dev/null || echo "$body"
        return 1
    fi
}

upload_all() {
    local profile="$1"
    
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_error "Dossier de backup non trouvé : $BACKUP_DIR"
        return 1
    fi
    
    check_server || return 1
    
    
    local total=0
    local uploaded=0
    
    for backup_type in "${BACKUP_TYPES[@]}"; do
        local type_dir="$BACKUP_DIR/$backup_type"
        
        if [[ ! -d "$type_dir" ]]; then
            continue
        fi
        
        
        for archive in "$type_dir"/*.tar.gz; do
            
            if [[ ! -f "$archive" ]]; then
                continue
            fi
            
            total=$((total + 1))
            if upload_file "$archive" "$backup_type" "$profile"; then
                uploaded=$((uploaded + 1))
            fi
        done
    done
    
    echo
    log_info "Résumé : $uploaded/$total fichiers uploadés"
    return 0
}

echo "=========================================="
echo "  Backup Upload Script"
echo "=========================================="
echo

if [[ $# -eq 0 ]]; then
    log_error "Usage: $0 <profile> [--all]"
    echo "Exemples :"
    echo "  $0 document              # Upload le dernier backup"
    echo "  $0 document --all        # Upload tous les backups"
    exit 1
fi

PROFILE="$1"

upload_all "$PROFILE"
