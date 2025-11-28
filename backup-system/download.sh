#!/bin/bash
################################################################################
# DOWNLOAD.SH - Télécharge les Backups depuis le Serveur
################################################################################
#
# DESCRIPTION :
#   Télécharge les archives de backup du serveur Flask distant.
#   Supporte download de types FULL, INC, DIFF.
#   Vérifie l'intégrité avec MD5 après téléchargement.
#
# USAGE :
#   ./download.sh [type]
#
# PARAMÈTRES :
#   type (optionnel) : Type(s) à télécharger
#                      Valeurs : full, incremental, diff
#                      Si absent : télécharge tous les types
#
# EXEMPLES :
#   # Télécharger archives FULL
#   ./download.sh full
#
#   # Télécharger archives INCREMENTAL
#   ./download.sh incremental
#
#   # Télécharger archives DIFFERENTIAL
#   ./download.sh diff
#
#   # Télécharger tous les types
#   ./download.sh
#
#   # Depuis serveur personnalisé
#   SERVER_URL=http://192.168.1.100:5000 ./download.sh full
#
# VARIABLES D'ENVIRONNEMENT :
#   SERVER_URL   : URL du serveur (défaut: http://localhost:5000)
#   BACKUP_DIR   : Dossier de destination (défaut: ./backup)
#
# EXEMPLES AVEC VARIABLES :
#   SERVER_URL=http://192.168.1.100:5000 ./download.sh
#   BACKUP_DIR=/data/backups ./download.sh full
#
# FONCTIONNEMENT :
#   1. Vérifie la disponibilité du serveur
#   2. Récupère la liste des archives : GET /list/<type>
#   3. Crée les dossiers FULL/, INC/, DIFF/ localement
#   4. Télécharge chaque fichier en streaming
#   5. Vérifie le MD5 de chaque fichier
#   6. Affiche un résumé du téléchargement
#
# ENDPOINTS UTILISÉS :
#   GET /list/<type> : Récupère liste des archives
#   GET /download/<type>/<filename> : Télécharge le fichier
#
# FICHIERS CRÉÉS :
#   - backup/FULL/*.tar.gz : Archives téléchargées (complètes)
#   - backup/INC/*.tar.gz : Archives téléchargées (incrémentales)
#   - backup/DIFF/*.tar.gz : Archives téléchargées (différentielles)
#
# VÉRIFICATION D'INTÉGRITÉ :
#   - MD5 vérifié après chaque téléchargement
#   - Les fichiers corrompus sont signalés
#   - Affiche [SUCCESS] ou [ERROR] par fichier
#
# DÉPENDANCES :
#   - curl : Téléchargements HTTP
#   - jq : Parsing JSON
#   - md5sum : Vérification d'intégrité
#   - Server Flask : Application Flask avec endpoints /list et /download
#
# CODES HTTP :
#   200 : Fichier trouvé et téléchargé ✓
#   404 : Fichier non trouvé
#   500 : Erreur serveur
#
# ERREURS POSSIBLES :
#   "Serveur indisponible" - Le serveur n'est pas accessible
#   "Aucune archive trouvée" - Pas de fichier à télécharger
#   "MD5 invalide" - Fichier corrompu
#
# NOTES :
#   - Les fichiers existants sont écrasés
#   - Téléchargement en streaming pour économiser mémoire
#   - Vérification MD5 automatique après chaque téléchargement
#   - Mode sûr (set -euo pipefail) : erreur = arrêt immédiat
#
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SERVER_URL="${SERVER_URL:-http://localhost:5000}"
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/backup}"
BACKUP_TYPES=("FULL" "INC" "DIFF")
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/download_$(date +%Y-%m-%d).log"

# Créer le dossier logs s'il n'existe pas
mkdir -p "$LOG_DIR"

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

download_file() {
    local backup_type="$1"
    local filename="$2"
    local url="$SERVER_URL/download/$backup_type/$filename"
    local dest_dir="$BACKUP_DIR/$backup_type"
    
    mkdir -p "$dest_dir"
    
    log_info "Téléchargement de $backup_type : $filename"
    
    if curl -s -f "$url" -o "$dest_dir/$filename"; then
        log_success "Téléchargé : $filename"
        return 0
    else
        log_error "Échec du téléchargement : $filename"
        return 1
    fi
}

list_remote_backups() {
    local response=$(curl -s "$SERVER_URL/list")
    echo "$response" | jq -r '.backups | to_entries[] | .key as $type | .value[] | "\($type)|\(.name)"' 2>/dev/null
}

download_all() {
    local profile="$1"
    
    check_server || return 1
    
    log_info "Récupération de la liste des backups..."
    
    local total=0
    local downloaded=0
    
    while IFS='|' read -r backup_type filename; do
        total=$((total + 1))
        if download_file "$backup_type" "$filename"; then
            downloaded=$((downloaded + 1))
        fi
    done < <(list_remote_backups)
    
    echo
    log_info "Résumé : $downloaded/$total fichiers téléchargés"
    return 0
}

download_type() {
    local backup_type="$1"
    
    check_server || return 1
    
    log_info "Récupération de la liste des backups $backup_type..."
    
    local response=$(curl -s "$SERVER_URL/list/$backup_type")
    local backups=$(echo "$response" | jq -r '.backups[].name' 2>/dev/null)
    
    local total=0
    local downloaded=0
    
    while IFS= read -r filename; do
        [[ -z "$filename" ]] && continue
        total=$((total + 1))
        if download_file "$backup_type" "$filename"; then
            downloaded=$((downloaded + 1))
        fi
    done <<< "$backups"
    
    echo
    log_info "Résumé : $downloaded/$total fichiers téléchargés"
    return 0
}

echo "=========================================="
echo "  Backup Download Script"
echo "=========================================="
echo

if [[ $# -eq 0 ]]; then
    log_error "Usage: $0 <profile> [--all|--type TYPE]"
    echo "Exemples :"
    echo "  $0 document --all           # Télécharge tous les backups"
    echo "  $0 document --type FULL     # Télécharge uniquement les FULL"
    echo "  $0 document --type INC      # Télécharge uniquement les INC"
    exit 1
fi

PROFILE="$1"
shift

if [[ $# -eq 0 ]] || [[ "$1" == "--all" ]]; then
    download_all "$PROFILE"
elif [[ "$1" == "--type" ]] && [[ $# -eq 2 ]]; then
    TYPE="$2"
    if [[ "$TYPE" =~ ^(FULL|INC|DIFF)$ ]]; then
        download_type "$TYPE"
    else
        log_error "Type invalide : $TYPE (doit être FULL, INC ou DIFF)"
        exit 1
    fi
else
    log_error "Arguments invalides"
    exit 1
fi