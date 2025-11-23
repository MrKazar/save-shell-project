#!/bin/bash
# =============================================================================
# VERIFY_SYNC.SH - Script de vérification de synchronisation
# =============================================================================
# Description:
#   Compare les backups locaux avec ceux présents sur le serveur distant
#   Détecte les fichiers manquants, les différences de hash, etc.
#
# Usage:
#   ./verify_sync.sh           : Vérifie la synchronisation
#   ./verify_sync.sh --stats   : Affiche les statistiques du serveur
#
# Variables d'environnement:
#   SERVER_URL  : URL du serveur (défaut: http://localhost:5000)
#   BACKUP_DIR  : Dossier des backups locaux (défaut: ./backup)
#
# Exemples:
#   ./verify_sync.sh
#   ./verify_sync.sh --stats
#   SERVER_URL=http://192.168.1.100:5000 ./verify_sync.sh
#
# Vérifications effectuées:
#   - Nombre de fichiers local vs distant
#   - Hash MD5 de chaque fichier
#   - Fichiers manquants sur le serveur
#   - Fichiers en trop sur le serveur
#
# Statuts possibles:
#   SYNCHRONIZED    : Tout est synchronisé
#   OUT_OF_SYNC     : Des différences ont été détectées
#
# Dépendances:
#   - curl   : Pour les requêtes HTTP
#   - jq     : Pour le parsing JSON
#   - md5sum : Pour calculer les hash (ou md5 sur Mac)
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

# =============================================================================
# Fonctions de logging
# =============================================================================
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

# =============================================================================
# GET_LOCAL_BACKUPS - Liste tous les backups locaux
# =============================================================================
# Parcourt les dossiers FULL, INC et DIFF locaux et construit un objet JSON
# contenant les informations de chaque archive
#
# Retour:
#   Objet JSON au format:
#   {
#     "FULL": [
#       {"name": "full_2025-11-22.tar.gz", "size": 12345, "md5": "abc123..."},
#       ...
#     ],
#     "INC": [...],
#     "DIFF": [...]
#   }
#
# Notes:
#   - Utilise stat pour la taille (portable Linux/BSD)
#   - Calcule le MD5 de chaque archive
#   - Ignore les fichiers qui ne sont pas des .tar.gz
# =============================================================================
get_local_backups() {
    local result="{"
    local first=true

    for backup_type in "${BACKUP_TYPES[@]}"; do
        if [[ "$first" == false ]]; then
            result+=","
        fi
        first=false
        
        result+="\"$backup_type\":["
        
        local type_dir="$BACKUP_DIR/$backup_type"
        if [[ -d "$type_dir" ]]; then
            local file_first=true
            for archive in "$type_dir"/*.tar.gz; do
                [[ ! -f "$archive" ]] && continue

                if [[ "$file_first" == false ]]; then
                    result+=","
                fi
                file_first=false

                local size=$(stat -c%s "$archive" 2>/dev/null || stat -f%z "$archive" 2>/dev/null)
                local md5=$(md5sum "$archive" 2>/dev/null | awk '{print $1}' || md5 -q "$archive" 2>/dev/null)
                
                result+="{\"name\":\"$(basename "$archive")\",\"size\":$size,\"md5\":\"$md5\"}"
            done
        fi
        
        result+="]"
    done

    result+="}"
    echo "$result"
}

# =============================================================================
# VERIFY_SYNC - Vérifie la synchronisation local <-> distant
# =============================================================================
# Compare les backups locaux avec ceux du serveur distant
#
# Processus:
#   1. Récupère la liste des backups locaux
#   2. Envoie cette liste au serveur via POST /verify
#   3. Le serveur compare avec ses propres backups
#   4. Affiche les résultats de la comparaison
#
# Informations affichées:
#   - Nombre de backups local vs distant par type
#   - Nombre de fichiers synchronisés
#   - Liste des problèmes (fichiers manquants, différences MD5, etc.)
#   - Statut global (SYNCHRONIZED ou OUT_OF_SYNC)
#
# Retour:
#   0 : Vérification effectuée (synchronisé ou non)
#   1 : Erreur de communication avec le serveur
# =============================================================================
verify_sync() {
    log_info "Vérification de la synchronisation..."
    echo

    # Récupérer les backups locaux
    local local_backups=$(get_local_backups)

    # Envoyer au serveur pour vérification
    response=$(curl -s -X POST "$SERVER_URL/verify" \
        -H "Content-Type: application/json" \
        -d "{\"local_backups\": $local_backups}")

    # Afficher les résultats par type
    echo "$response" | jq -r '.verification | to_entries[] | 
        "\n\(.value.type)\n" +
        "  Local:  \(.value.local_count) backups\n" +
        "  Remote: \(.value.remote_count) backups\n" +
        "  Synced: \(.value.synced | length) fichiers"' 2>/dev/null

    # Afficher les problèmes détectés
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

# =============================================================================
# SHOW_STATS - Affiche les statistiques du serveur
# =============================================================================
# Récupère et affiche les statistiques du serveur distant
#
# Informations affichées:
#   - Nombre de fichiers par type (FULL, INC, DIFF)
#   - Taille de stockage par type
#   - Totaux (nombre total de fichiers et taille totale)
#
# Endpoint utilisé:
#   GET /stats
#
# Retour:
#   0 : Statistiques récupérées et affichées
#   1 : Erreur de communication avec le serveur
# =============================================================================
show_stats() {
    log_info "Statistiques du serveur..."
    echo

    # Récupérer les statistiques depuis le serveur
    response=$(curl -s "$SERVER_URL/stats")

    # Afficher les statistiques par type
    echo "$response" | jq -r '.storage | to_entries[] | 
        "\(.value.type // .key)\n" +
        "  Fichiers: \(.value.count)\n" +
        "  Taille:   \(.value.size_human)"' 2>/dev/null || echo "$response" | jq '.'

    # Afficher les totaux
    echo
    echo "Total: $(echo "$response" | jq -r '.total.files') fichiers, $(echo "$response" | jq -r '.total.size_human')"
}

# =============================================================================
# Main
# =============================================================================
echo "=========================================="
echo "  Backup Sync Verification"
echo "=========================================="
echo

# Exécuter l'action demandée
if [[ $# -gt 0 && "$1" == "--stats" ]]; then
    show_stats
else
    verify_sync
fi