#!/bin/bash
# =============================================================================
# Upload Script - Envoie les backups vers le serveur distant
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
SERVER_URL="${SERVER_URL:-http://localhost:5000}"
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/backup}"
BACKUP_TYPES=("FULL" "INC" "DIFF")

# Couleurs
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
