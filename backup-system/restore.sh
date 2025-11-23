#!/bin/bash
# =============================================================================
# RESTORE.SH - Script de restauration de backups
# =============================================================================
# Description:
#   Restaure des fichiers depuis les archives de backup
#   Supporte la restauration complète ou sélective
#
# Usage:
#   ./restore.sh --profile <nom_profil> [OPTIONS]
#
# Options:
#   --profile <nom>   : Profil à utiliser (obligatoire)
#   --file <nom>      : Restaurer un fichier spécifique
#   --dry-run         : Mode test (affiche ce qui serait restauré)
#
# Exemples:
#   ./restore.sh --profile document
#   ./restore.sh --profile document --dry-run
#   ./restore.sh --profile document --file readme.txt
#
# Restauration complète:
#   1. Restaure le dernier backup FULL
#   2. Applique tous les INC créés après ce FULL
#   3. Applique tous les DIFF créés après ce FULL
#   → Résultat : état complet des données au moment du dernier backup
#
# Restauration sélective:
#   Recherche le fichier dans les archives (DIFF → INC → FULL)
#   Restaure la version la plus récente trouvée
#
# Notes:
#   - Le dossier destination sera écrasé lors d'une restauration complète
#   - Utilisez --dry-run pour prévisualiser sans modifier les fichiers
#   - Les logs de restauration sont dans logs/restore_YYYY-MM-DD.log
# =============================================================================

set -euo pipefail
source lib/utils.sh

init_logs "restore"
log_session_start

PROFILE=""
FILE_TO_RESTORE=""
DRY_RUN=false

# =============================================================================
# Parsing des arguments
# =============================================================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --file)
            FILE_TO_RESTORE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            log ERROR "Argument inconnu : $1"
            exit 1
            ;;
    esac
done

# Validation
if [[ -z "$PROFILE" ]]; then
    log ERROR "--profile obligatoire"
    exit 1
fi

log INFO "Démarrage de la restauration - Profil: $PROFILE"

# Lecture de la configuration
SRC_DIR=$(get_config "$PROFILE" "source") || { log ERROR "Impossible de lire la configuration"; exit 1; }
DST_DIR=$(get_config "$PROFILE" "destination") || { log ERROR "Impossible de lire la configuration"; exit 1; }

log INFO "Source: $SRC_DIR, Archives: $DST_DIR"

# =============================================================================
# GET_LAST_FULL - Trouve le dernier backup FULL
# =============================================================================
# Retourne le chemin complet du backup FULL le plus récent
# Les fichiers sont triés par date de modification (ls -1t)
#
# Retour:
#   Chemin de l'archive FULL ou chaîne vide si aucune trouvée
# =============================================================================
get_last_full() {
    local last_full
    last_full=$(ls -1t "$DST_DIR/FULL"/*.tar.gz 2>/dev/null | head -n1 || true)
    echo "$last_full"
}

# =============================================================================
# GET_INCREMENTALS_AFTER_FULL - Liste les INC créés après un FULL
# =============================================================================
# Trouve tous les backups incrémentaux créés après le FULL spécifié
# Compare les timestamps des fichiers pour déterminer l'ordre
#
# Arguments:
#   $1 : Chemin du backup FULL de référence
#
# Retour:
#   Liste des chemins des archives INC, triée par date
# =============================================================================
get_incrementals_after_full() {
    local full_archive="$1"
    # Obtenir le timestamp du FULL (portable Linux/BSD)
    local full_time=$(stat -c %Y "$full_archive" 2>/dev/null || stat -f %m "$full_archive" 2>/dev/null)
    
    # Trouver tous les INC plus récents que le FULL
    find "$DST_DIR/INC" -name "*.tar.gz" -type f 2>/dev/null | while read inc; do
        local inc_time=$(stat -c %Y "$inc" 2>/dev/null || stat -f %m "$inc" 2>/dev/null)
        if [[ $inc_time -gt $full_time ]]; then
            echo "$inc"
        fi
    done | sort
}

# =============================================================================
# GET_DIFFS_AFTER_FULL - Liste les DIFF créés après un FULL
# =============================================================================
# Trouve tous les backups différentiels créés après le FULL spécifié
# Même logique que get_incrementals_after_full
#
# Arguments:
#   $1 : Chemin du backup FULL de référence
#
# Retour:
#   Liste des chemins des archives DIFF, triée par date
# =============================================================================
get_diffs_after_full() {
    local full_archive="$1"
    local full_time=$(stat -c %Y "$full_archive" 2>/dev/null || stat -f %m "$full_archive" 2>/dev/null)
    
    find "$DST_DIR/DIFF" -name "*.tar.gz" -type f 2>/dev/null | while read diff; do
        local diff_time=$(stat -c %Y "$diff" 2>/dev/null || stat -f %m "$diff" 2>/dev/null)
        if [[ $diff_time -gt $full_time ]]; then
            echo "$diff"
        fi
    done | sort
}

# =============================================================================
# RESTORE_COMPLETE - Restauration complète
# =============================================================================
# Processus de restauration complète:
#   1. Trouve le dernier backup FULL
#   2. Restaure le FULL (écrase le dossier destination)
#   3. Applique tous les INC créés après ce FULL (écrase les fichiers modifiés)
#   4. Applique tous les DIFF créés après ce FULL (écrase les fichiers modifiés)
#
# Résultat:
#   Le dossier source contient l'état exact au moment du dernier backup
#
# Mode dry-run:
#   Affiche ce qui serait restauré sans modifier les fichiers
# =============================================================================
restore_complete() {
    local archive
    archive=$(get_last_full)
    
    if [[ -z "$archive" ]]; then
        log ERROR "Aucune archive FULL trouvée dans $DST_DIR/FULL"
        exit 1
    fi
    
    log INFO "Restauration complète depuis $(basename "$archive")"
    
    if [[ "$DRY_RUN" = true ]]; then
        log WARN "[DRY-RUN] Mode de test activé"
        log INFO "[DRY-RUN] Contenu du FULL:"
        tar -tzf "$archive" | head -20
        
        log INFO "[DRY-RUN] Incrementals à appliquer:"
        get_incrementals_after_full "$archive" | while read inc; do
            log INFO "  - $(basename "$inc")"
        done
        
        log INFO "[DRY-RUN] Diffs à appliquer:"
        get_diffs_after_full "$archive" | while read diff; do
            log INFO "  - $(basename "$diff")"
        done
        
        log INFO "[DRY-RUN] Aucun fichier n'a été restauré."
    else
        # Créer le dossier parent si nécessaire
        mkdir_safe "$(dirname "$SRC_DIR")"
        
        # Étape 1: Restaurer le FULL
        log INFO "Restauration du FULL..."
        if tar -xzf "$archive" -C "$(dirname "$SRC_DIR")" 2>/dev/null; then
            log SUCCESS "FULL restauré"
        else
            log ERROR "Échec de la restauration du FULL"
            return 1
        fi
        
        # Étape 2: Appliquer les incrementals
        log INFO "Application des incrementals..."
        get_incrementals_after_full "$archive" | while read inc; do
            log INFO "Application de $(basename "$inc")"
            if tar -xzf "$inc" -C "$SRC_DIR" 2>/dev/null; then
                log SUCCESS "$(basename "$inc") appliqué"
            else
                log WARN "Échec de l'application de $(basename "$inc")"
            fi
        done
        
        # Étape 3: Appliquer les diffs
        log INFO "Application des diffs..."
        get_diffs_after_full "$archive" | while read diff; do
            log INFO "Application de $(basename "$diff")"
            if tar -xzf "$diff" -C "$SRC_DIR" 2>/dev/null; then
                log SUCCESS "$(basename "$diff") appliqué"
            else
                log WARN "Échec de l'application de $(basename "$diff")"
            fi
        done
        
        log SUCCESS "Restauration complète terminée."
    fi
}

# =============================================================================
# RESTORE_FILE - Restauration sélective d'un fichier
# =============================================================================
# Recherche un fichier spécifique dans les archives et restaure la version
# la plus récente trouvée
#
# Ordre de recherche (du plus récent au plus ancien):
#   1. DIFF (versions les plus récentes)
#   2. INC  (versions intermédiaires)
#   3. FULL (version de base)
#
# Arguments:
#   $1 : Nom du fichier à restaurer
#
# Notes:
#   - Seul le fichier spécifié est extrait de l'archive
#   - Le fichier est restauré dans le dossier source
#   - Si le fichier existe déjà, il sera écrasé
# =============================================================================
restore_file() {
    local file="$1"
    
    log INFO "Recherche du fichier $file dans les archives"
    
    for type in DIFF INC FULL; do
        [[ ! -d "$DST_DIR/$type" ]] && continue
        
        for archive in $(ls -1t "$DST_DIR/$type"/*.tar.gz 2>/dev/null || true); do
            [[ -f "$archive" ]] || continue
            
            if tar -tzf "$archive" 2>/dev/null | grep -q "$(basename "$file")$"; then
                log INFO "Fichier trouvé dans $type : $(basename "$archive")"
                
                if [[ "$DRY_RUN" = true ]]; then
                    log WARN "[DRY-RUN] $file serait restauré depuis $archive"
                    return 0
                else
                    mkdir_safe "$SRC_DIR"
                    
                    # Extraire dans un dossier temporaire pour gérer les chemins complexes
                    local temp_dir=$(mktemp -d)
                    if tar -xzf "$archive" -C "$temp_dir" 2>/dev/null; then
                        # Trouver le fichier dans le dossier temporaire
                        local found_file=$(find "$temp_dir" -name "$(basename "$file")" -type f | head -n1)
                        if [[ -n "$found_file" ]]; then
                            cp "$found_file" "$SRC_DIR/$(basename "$file")"
                            rm -rf "$temp_dir"
                            log SUCCESS "Fichier $file restauré avec succès"
                            return 0
                        else
                            rm -rf "$temp_dir"
                            log WARN "Fichier trouvé dans l'archive mais extraction échouée"
                        fi
                    else
                        rm -rf "$temp_dir"
                    fi
                fi
            fi
        done
    done
    
    log ERROR "Fichier $file introuvable dans les archives"
    exit 1
}
# =============================================================================
# Exécution
# =============================================================================
if [[ -n "$FILE_TO_RESTORE" ]]; then
    restore_file "$FILE_TO_RESTORE"
else
    restore_complete
fi

log SUCCESS "Restauration terminée (logs : $LOG_FILE)"