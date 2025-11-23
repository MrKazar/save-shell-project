#!/bin/bash
# =============================================================================
# Download Script - Télécharge les backups depuis le serveur distant
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SERVER_URL="${SERVER_URL:-http://localhost:5000}"
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/backup}"
BACKUP_TYPES=("FULL" "INC" "DIFF")

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC}  $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC}  $*"
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