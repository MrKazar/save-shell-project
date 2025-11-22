#!/bin/bash
# =============================================================================
# Sync Verify Script - Vérifie la synchronisation local/distant
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
SERVER_URL="${SERVER_URL:-http://localhost:5000}"
BACKUP_DIR="${BACKUP_DIR:-./backup}"
BACKUP_TYPES=("FULL" "INC" "DIFF")

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# =====================
# Fonctions
# =====================
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

log_detail() {
    echo -e "${CYAN}  ➜${NC} $*"
}

# =====================
# Récupérer les fichiers locaux
# =====================
get_local_backups() {
    local local_json="{"
    local first=true

    for backup_type in "${BACKUP_TYPES[@]}"; do
        local type_dir="$BACKUP_DIR/$backup_type"

        if [[ ! -d "$type_dir" ]]; then
            [[ "$first" == true ]] && first=false || local_json+=","
            local_json+="\"$backup_type\":[]"
            continue
        fi

        local files=()
        for archive in "$type_dir"/*.tar.gz; do
            [[ ! -f "$archive" ]] && continue

            local size=$(stat -f%z "$archive" 2>/dev/null || stat -c%s "$archive" 2>/dev/null)
            local md5=$(md5sum "$archive" 2>/dev/null | awk '{print $1}' || md5 -q "$archive" 2>/dev/null)

            if [[ "$first" == true ]]; then
                local_json+="\"$backup_type\": [{\"name\": \"$(basename "$archive")\", \"size\": $size, \"md5\": \"$md5\"}"
                first=false
            else
                files+=(", {\"name\": \"$(basename "$archive")\", \"size\": $size, \"md5\": \"$md5\"}")
            fi
        done

        for file in "${files[@]}"; do
            local_json+="$file"
        done

        local_json+="]"
    done

    if [[ "$first" == true ]]; then
        local_json="{"
        for i in "${!BACKUP_TYPES[@]}"; do
            [[ $i -gt 0 ]] && local_json+=","
            local_json+="\"${BACKUP_TYPES[$i]}\":[]"
        done
    fi

    local_json+="}"
    echo "$local_json"
}

# =====================
# Vérifier la synchronisation
# =====================
verify_sync() {
    log_info "Vérification de la synchronisation..."
    echo

    # Récupérer les backups locaux
    local local_backups=$(get_local_backups)

    # Envoyer au serveur pour vérification
    response=$(curl -s -X POST "$SERVER_URL/verify" \
        -H "Content-Type: application/json" \
        -d "{\"local_backups\": $local_backups}")

    # Afficher les résultats
    echo "$response" | jq -r '.verification | to_entries[] | 
        "\n\(.value.type)\n" +
        "  Local:  \(.value.local_count) backups\n" +
        "  Remote: \(.value.remote_count) backups\n" +
        "  Synced: \(.value.synced | length) fichiers"' 2>/dev/null

    # Afficher les problèmes
    local issues=$(echo "$response" | jq -r '.issues[]' 2>/dev/null)
    if [[ -n "$issues" ]]; then
        echo
        log_warn "Problèmes détectés :"
        while IFS= read -r issue; do
            log_detail "$issue"
        done <<< "$issues"
    fi

    # Afficher le statut global
    local sync_status=$(echo "$response" | jq -r '.sync_status' 2>/dev/null)
    echo
    if [[ "$sync_status" == "SYNCHRONIZED" ]]; then
        log_success "Synchronisation OK ✓"
    else
        log_warn "Hors de synchronisation ✗"
    fi
}

# =====================
# Afficher les statistiques du serveur
# =====================
show_stats() {
    log_info "Statistiques du serveur..."
    echo

    response=$(curl -s "$SERVER_URL/stats")

    echo "$response" | jq -r '.storage | to_entries[] | 
        "\(.value.type // .key)\n" +
        "  Fichiers: \(.count)\n" +
        "  Taille:   \(.size_human)"' 2>/dev/null || echo "$response" | jq '.'

    echo
    echo "Total: $(echo "$response" | jq -r '.total.files') fichiers, $(echo "$response" | jq -r '.total.size_human')"
}

# =====================
# Main
# =====================
echo "=========================================="
echo "  Backup Sync Verification"
echo "=========================================="
echo

if [[ $# -gt 0 && "$1" == "--stats" ]]; then
    show_stats
else
    verify_sync
fi
