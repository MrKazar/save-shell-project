#!/bin/bash
set -euo pipefail

source lib/utils.sh
source lib/usage.sh

# Initialiser les logs
init_logs "restore"
log_session_start

# =====================
# Parsing des arguments
# =====================
PROFILE=""
FILE_TO_RESTORE=""
RESTORE_DATE=""
DRY_RUN=false

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
        --date)
            RESTORE_DATE="$2"
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

if [[ -z "$PROFILE" ]]; then
    log ERROR "--profile obligatoire"
    exit 1
fi

log INFO "Démarrage de la restauration - Profil: $PROFILE"

SRC_DIR=$(get_config "$PROFILE" "source") || { log ERROR "Impossible de lire la configuration"; exit 1; }
DST_DIR=$(get_config "$PROFILE" "destination") || { log ERROR "Impossible de lire la configuration"; exit 1; }

log INFO "Source: $SRC_DIR, Archives: $DST_DIR"

# =====================
# Trouver la dernière archive FULL
# =====================
get_last_full() {
    local last_full
    last_full=$(ls -1t "$DST_DIR/FULL"/*.tar.gz 2>/dev/null | head -n1 || true)
    echo "$last_full"
}

# =====================
# Restauration complète
# =====================
restore_full() {
    local archive
    archive=$(get_last_full)

    if [[ -z "$archive" ]]; then
        log ERROR "Aucune archive FULL trouvée dans $DST_DIR/FULL"
        exit 1
    fi

    log INFO "Restauration complète depuis $(basename "$archive")"

    if [[ "$DRY_RUN" = true ]]; then
        log WARN "[DRY-RUN] Mode de test activé"
        tar -tzf "$archive" | head -20
        log INFO "[DRY-RUN] Aucun fichier n'a été restauré."
    else
        # Créer le dossier parent si nécessaire
        mkdir_safe "$(dirname "$SRC_DIR")"
        
        if tar -xzf "$archive" -C "$(dirname "$SRC_DIR")" 2>/dev/null; then
            log SUCCESS "Restauration complète terminée."
        else
            log ERROR "Échec de la restauration"
            return 1
        fi
    fi
}

# =====================
# Restauration sélective
# =====================
restore_file() {
    local file="$1"
    local filename=$(basename "$file")
    local restored=false

    log INFO "Recherche du fichier $filename dans les archives"

    for type in FULL INC DIFF; do
        [[ ! -d "$DST_DIR/$type" ]] && continue
        for archive in "$DST_DIR/$type"/*.tar.gz; do
            [[ -f "$archive" ]] || continue
            
            # Chercher le fichier dans l'archive (peut être dans n'importe quel chemin)
            local matching_file=$(tar -tzf "$archive" | grep -E "(^|/)${filename}$" | head -n1 || true)
            
            if [[ -n "$matching_file" ]]; then
                log INFO "Fichier trouvé dans $type : $(basename "$archive") → $matching_file"
                if [[ "$DRY_RUN" = true ]]; then
                    log WARN "[DRY-RUN] $matching_file serait restauré depuis $archive"
                else
                    # Créer le dossier parent s'il n'existe pas
                    mkdir_safe "$(dirname "$SRC_DIR")"
                    
                    if tar -xzf "$archive" -C "$(dirname "$SRC_DIR")" "$matching_file" 2>/dev/null; then
                        log SUCCESS "Fichier $matching_file restauré avec succès"
                        restored=true
                    else
                        log ERROR "Échec de restauration du fichier $matching_file"
                        return 1
                    fi
                fi
                return
            fi
        done
    done

    if [[ "$restored" = false ]]; then
        log ERROR "Fichier $filename introuvable dans les archives"
        exit 1
    fi
}

# =====================
# Restauration depuis une date spécifique
# =====================
restore_from_date() {
    local target_date="$1"
    local archive=""
    
    # Convertir la date en format YYYY-MM-DD_HH-MM-SS pour comparaison
    # Format accepté : YYYY-MM-DD ou YYYY-MM-DD_HH-MM-SS
    
    log INFO "Recherche d'archives antérieures ou égales à : $target_date"
    
    # Chercher d'abord la dernière archive FULL antérieure à la date
    for archive in $(ls -1tr "$DST_DIR/FULL"/*.tar.gz 2>/dev/null); do
        [[ ! -f "$archive" ]] && continue
        local archive_date=$(basename "$archive" | sed 's/full_\([^.]*\).*/\1/')
        
        # Comparer les dates (format YYYY-MM-DD_HH-MM-SS)
        if [[ "$archive_date" < "$target_date" || "$archive_date" == "$target_date" ]]; then
            log INFO "Archive FULL sélectionnée : $(basename "$archive") (date: $archive_date)"
            restore_archive "$archive"
            
            # Ensuite appliquer les archives INC/DIFF antérieures à la date
            for type in INC DIFF; do
                [[ ! -d "$DST_DIR/$type" ]] && continue
                for inc_archive in $(ls -1tr "$DST_DIR/$type"/*.tar.gz 2>/dev/null); do
                    [[ ! -f "$inc_archive" ]] && continue
                    local inc_date=$(basename "$inc_archive" | sed "s/${type,,}_\([^.]*\).*/\1/")
                    
                    if [[ "$inc_date" > "$archive_date" && ("$inc_date" < "$target_date" || "$inc_date" == "$target_date") ]]; then
                        log INFO "Appliquer archive $type : $(basename "$inc_archive")"
                        restore_archive "$inc_archive"
                    fi
                done
            done
            return 0
        fi
    done
    
    log ERROR "Aucune archive trouvée pour la date : $target_date"
    exit 1
}

# =====================
# Restaurer depuis une archive
# =====================
restore_archive() {
    local archive="$1"
    
    if [[ "$DRY_RUN" = true ]]; then
        log WARN "[DRY-RUN] Mode de test activé"
        tar -tzf "$archive" | head -20
        log INFO "[DRY-RUN] Aucun fichier n'a été restauré depuis $(basename "$archive")"
    else
        # Créer le dossier parent si nécessaire
        mkdir_safe "$(dirname "$SRC_DIR")"
        
        if tar -xzf "$archive" -C "$(dirname "$SRC_DIR")" 2>/dev/null; then
            log SUCCESS "Archive $(basename "$archive") restaurée avec succès"
        else
            log ERROR "Échec de la restauration depuis $(basename "$archive")"
            return 1
        fi
    fi
}

# =====================
# Main
# =====================
if [[ -n "$RESTORE_DATE" ]]; then
    restore_from_date "$RESTORE_DATE"
elif [[ -n "$FILE_TO_RESTORE" ]]; then
    restore_file "$FILE_TO_RESTORE"
else
    restore_full
fi

log SUCCESS "Restauration terminée (logs : $LOG_FILE)"
