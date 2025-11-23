#!/bin/bash
# =============================================================================
# BACKUP.SH - Script de création de backups
# =============================================================================
# Description:
#   Crée des archives de sauvegarde de types FULL, INCREMENTAL ou DIFFERENTIAL
#
# Usage:
#   ./backup.sh --profile <nom_profil> --type <full|incremental|diff>
#
# Exemples:
#   ./backup.sh --profile document --type full
#   ./backup.sh --profile document --type incremental
#   ./backup.sh --profile document --type diff
#
# Types de backup:
#   FULL         : Sauvegarde complète de tous les fichiers
#   INCREMENTAL  : Fichiers modifiés depuis le dernier FULL
#   DIFFERENTIAL : Fichiers modifiés depuis le dernier FULL (identique à INC)
#
# Fichiers générés:
#   - backup/FULL/*.tar.gz       : Archives complètes
#   - backup/INC/*.tar.gz        : Archives incrémentales
#   - backup/DIFF/*.tar.gz       : Archives différentielles
#   - *.meta.json                : Métadonnées (taille, nombre de fichiers, checksum)
#   - snap_<profil>.dat          : Référence au dernier FULL (pour INC/DIFF)
#
# Notes importantes:
#   - Le snapshot pointe TOUJOURS vers le dernier FULL, jamais vers un INC
#   - Les INC et DIFF comparent avec le dernier FULL, pas entre eux
#   - Si aucun FULL n'existe, un FULL est automatiquement créé
# =============================================================================

set -euo pipefail
source lib/utils.sh

init_logs "backup"
log_session_start

PROFILE=""
BACKUP_TYPE=""

# =============================================================================
# Parsing des arguments
# =============================================================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile) PROFILE="$2"; shift 2 ;;
        --type) BACKUP_TYPE="$2"; shift 2 ;;
        *) log ERROR "Argument inconnu : $1"; exit 1 ;;
    esac
done

# Validation des paramètres
if [[ -z "$PROFILE" ]]; then
    log ERROR "--profile obligatoire"
    exit 1
fi

if [[ -z "$BACKUP_TYPE" ]]; then
    log ERROR "--type obligatoire (full|incremental|diff)"
    exit 1
fi

log INFO "Démarrage du backup - Profil: $PROFILE, Type: $BACKUP_TYPE"

# Lecture de la configuration depuis le profil YAML
SRC_DIR=$(get_config "$PROFILE" "source") || { log ERROR "Impossible de lire la configuration"; exit 1; }
DST_DIR=$(get_config "$PROFILE" "destination") || { log ERROR "Impossible de lire la configuration"; exit 1; }

log INFO "Source: $SRC_DIR, Destination: $DST_DIR"

if [[ ! -d "$SRC_DIR" ]]; then
    log WARN "Le dossier source n'existe pas : $SRC_DIR"
fi

# Création des dossiers de destination
mkdir_safe "$DST_DIR/FULL" "$DST_DIR/INC" "$DST_DIR/DIFF"

# =============================================================================
# BACKUP FULL
# =============================================================================
# Crée une archive complète de tous les fichiers du dossier source
# Le nom de l'archive FULL est sauvegardé dans snap_<profil>.dat
# Ce snapshot est utilisé par les backups INC et DIFF pour la comparaison
# =============================================================================
backup_full() {
    log INFO "Démarrage du backup FULL pour le profil $PROFILE"
    local filename="full_$(date +%Y-%m-%d_%H-%M-%S).tar.gz"
    
    # Création de l'archive tar.gz
    if tar -czf "$DST_DIR/FULL/$filename" -C "$(dirname "$SRC_DIR")" "$(basename "$SRC_DIR")" 2>/dev/null; then
        log SUCCESS "Backup FULL terminé : $filename"
        
        # Génération des métadonnées (taille, nombre de fichiers, checksum)
        generate_metadata "$DST_DIR/FULL/$filename" "$PROFILE" "full"
        
        # Sauvegarde du nom du FULL dans le snapshot
        # Ce fichier est utilisé par incremental et diff pour savoir quel FULL utiliser
        echo "$filename" > "snap_${PROFILE}.dat"
        
        show_storage_state "$DST_DIR"
    else
        log ERROR "Échec de création du backup FULL"
        return 1
    fi
}

# =============================================================================
# BACKUP INCREMENTAL
# =============================================================================
# Sauvegarde uniquement les fichiers modifiés depuis le dernier FULL
# Utilise le snapshot pour trouver le FULL de référence
# NE MODIFIE PAS le snapshot (il doit toujours pointer vers le dernier FULL)
# =============================================================================
backup_incremental() {
    log INFO "Démarrage du backup INCREMENTAL pour le profil $PROFILE"
    local SNAP="snap_${PROFILE}.dat"
    
    # Vérifier qu'un snapshot existe
    if [[ ! -f "$SNAP" ]]; then
        log WARN "Aucun snapshot → FULL forcé"
        backup_full
        return
    fi
    
    # Lire le nom du dernier FULL depuis le snapshot
    local LAST_FULL
    LAST_FULL=$(cat "$SNAP")
    local FULL_PATH="$DST_DIR/FULL/$LAST_FULL"
    
    # Vérifier que le FULL existe toujours
    if [[ ! -f "$FULL_PATH" ]]; then
        log ERROR "Le FULL référencé n'existe plus : $LAST_FULL"
        log WARN "Création d'un nouveau FULL"
        backup_full
        return
    fi
    
    local filename="inc_$(date +%Y-%m-%d_%H-%M-%S).tar.gz"
    local changed_files=$(mktemp)
    
    # Trouver tous les fichiers modifiés depuis le FULL
    # -newer : portable (fonctionne sur Linux et BSD/Mac)
    find "$SRC_DIR" -type f -newer "$FULL_PATH" > "$changed_files"
    
    # Vérifier s'il y a des fichiers modifiés
    if [[ ! -s "$changed_files" ]]; then
        log WARN "Aucun fichier modifié depuis le dernier FULL → rien à sauvegarder"
        rm -f "$changed_files"
        return 0
    fi
    
    # Créer l'archive avec uniquement les fichiers modifiés
    # sed retire le chemin source pour avoir des chemins relatifs dans l'archive
    if tar -czf "$DST_DIR/INC/$filename" -C "$SRC_DIR" -T <(sed "s|^$SRC_DIR/||" "$changed_files") 2>/dev/null; then
        log SUCCESS "Backup INCREMENTAL terminé : $filename"
        
        # Générer les métadonnées avec référence au FULL parent
        generate_metadata "$DST_DIR/INC/$filename" "$PROFILE" "incremental" "$LAST_FULL"
        
        # IMPORTANT: NE PAS modifier le snapshot
        # Le snapshot doit TOUJOURS pointer vers le dernier FULL
        
        show_storage_state "$DST_DIR"
        rm -f "$changed_files"
    else
        log ERROR "Échec de création du backup INCREMENTAL"
        rm -f "$changed_files"
        return 1
    fi
}

# =============================================================================
# BACKUP DIFFERENTIAL
# =============================================================================
# Sauvegarde les fichiers modifiés depuis le dernier FULL
# Identique à incremental dans cette implémentation
# La différence classique : DIFF compare toujours avec le dernier FULL,
# alors que INC compare avec le dernier backup (FULL ou INC)
# Ici, les deux comparent avec le dernier FULL
# =============================================================================
backup_diff() {
    log INFO "Démarrage du backup DIFFERENTIEL pour le profil $PROFILE"
    local SNAP="snap_${PROFILE}.dat"
    
    if [[ ! -f "$SNAP" ]]; then
        log WARN "Aucun snapshot → FULL forcé"
        backup_full
        return
    fi
    
    local LAST_FULL
    LAST_FULL=$(cat "$SNAP")
    local FULL_PATH="$DST_DIR/FULL/$LAST_FULL"
    
    if [[ ! -f "$FULL_PATH" ]]; then
        log ERROR "Le FULL référencé n'existe plus : $LAST_FULL"
        log WARN "Création d'un nouveau FULL"
        backup_full
        return
    fi
    
    local filename="diff_$(date +%Y-%m-%d_%H-%M-%S).tar.gz"
    local changed_files=$(mktemp)
    
    find "$SRC_DIR" -type f -newer "$FULL_PATH" > "$changed_files"
    
    if [[ ! -s "$changed_files" ]]; then
        log WARN "Aucun fichier modifié depuis le dernier FULL → rien à sauvegarder"
        rm -f "$changed_files"
        return 0
    fi
    
    if tar -czf "$DST_DIR/DIFF/$filename" -C "$SRC_DIR" -T <(sed "s|^$SRC_DIR/||" "$changed_files") 2>/dev/null; then
        log SUCCESS "Backup DIFF terminé : $filename"
        generate_metadata "$DST_DIR/DIFF/$filename" "$PROFILE" "diff" "$LAST_FULL"
        show_storage_state "$DST_DIR"
        rm -f "$changed_files"
    else
        log ERROR "Échec de création du backup DIFF"
        rm -f "$changed_files"
        return 1
    fi
}

# =============================================================================
# Exécution du type de backup demandé
# =============================================================================
case "$BACKUP_TYPE" in
    full) backup_full ;;
    incremental) backup_incremental ;;
    diff) backup_diff ;;
    *) log ERROR "Type de backup inconnu : $BACKUP_TYPE"; exit 1 ;;
esac

log SUCCESS "Backup terminé avec succès (logs : $LOG_FILE)"