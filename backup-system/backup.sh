#!/bin/bash
################################################################################
# BACKUP.SH - Création de Backups (FULL, INC, DIFF)
################################################################################
#
# DESCRIPTION :
#   Crée des archives tar.gz compressées des fichiers source.
#   Supporte trois types de backup :
#   - FULL (complet) : Archive complète de tous les fichiers
#   - INCREMENTAL (incrémental) : Fichiers modifiés depuis dernier FULL
#   - DIFFERENTIAL (différentiel) : Changes depuis dernier FULL (indépendant)
#
# USAGE :
#   ./backup.sh --profile <nom> --type <type>
#
# PARAMÈTRES :
#   --profile <nom>  : Profil de configuration (obligatoire)
#                      Lit depuis profiles/<nom>.yaml
#   --type <type>    : Type de backup (obligatoire)
#                      Valeurs : full, incremental, diff
#
# EXEMPLES :
#   # Backup complet
#   ./backup.sh --profile document --type full
#
#   # Backup incrémental (modifs depuis dernier FULL)
#   ./backup.sh --profile document --type incremental
#
#   # Backup différentiel (changes depuis FULL)
#   ./backup.sh --profile document --type diff
#
# FONCTIONNEMENT :
#   1. Lit la configuration depuis profiles/<profil>.yaml
#   2. Vérifie que le dossier source existe
#   3. Crée l'archive selon le type demandé
#   4. Génère le checksum MD5
#   5. Crée un fichier snapshot pour suivi
#   6. Enregistre l'opération dans les logs
#
# FICHIERS LUS :
#   - profiles/<profil>.yaml : Configuration source/destination
#   - snap_<profil>.dat : Snapshot du dernier backup FULL (pour INC/DIFF)
#
# FICHIERS CRÉÉS :
#   - backup/FULL/<timestamp>.tar.gz : Archive complète
#   - backup/INC/<timestamp>.tar.gz : Archive incrémentale
#   - backup/DIFF/<timestamp>.tar.gz : Archive différentielle
#   - backup/*/< timestamp>.md5 : Checksum MD5
#   - snap_<profil>.dat : Snapshot (pour suivi INC/DIFF)
#   - logs/backup_YYYY-MM-DD.log : Fichier de log quotidien
#
# FORMAT DES ARCHIVES :
#   Nom : <type>_YYYY-MM-DD_HH-MM-SS.tar.gz
#   Exemples :
#   - full_2025-11-26_14-32-45.tar.gz
#   - inc_2025-11-26_15-10-22.tar.gz
#   - diff_2025-11-26_16-45-18.tar.gz
#
# STRATÉGIE RECOMMANDÉE :
#   Lundi    : ./backup.sh --profile document --type full
#   Mar-Dim  : ./backup.sh --profile document --type incremental
#
# DÉPENDANCES :
#   - tar : Création d'archives
#   - gzip : Compression
#   - md5sum : Calcul de checksum
#   - lib/utils.sh : Fonctions utilitaires (logging, config, etc.)
#
# VARIABLES D'ENVIRONNEMENT :
#   (aucune)
#
# CODES DE SORTIE :
#   0 : Succès
#   1 : Erreur (profil/type manquant, chemin invalide, etc.)
#
# NOTES :
#   - Les logs sont consolidés par jour dans logs/backup_YYYY-MM-DD.log
#   - Chaque backup génère un checksum MD5 pour vérification
#   - Le fichier snap_<profil>.dat trace le dernier FULL (pour INC/DIFF)
#   - Mode sûr (set -euo pipefail) : erreur = arrêt immédiat
#
################################################################################

set -euo pipefail

source lib/utils.sh

# Initialiser les logs
init_logs "backup"
log_session_start

PROFILE=""
BACKUP_TYPE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile) PROFILE="$2"; shift 2 ;;
        --type) BACKUP_TYPE="$2"; shift 2 ;;
        *) log ERROR "Argument inconnu : $1"; exit 1 ;;
    esac
done

if [[ -z "$PROFILE" ]]; then
    log ERROR "--profile obligatoire"
    exit 1
fi

if [[ -z "$BACKUP_TYPE" ]]; then
    log ERROR "--type obligatoire (full|incremental|diff)"
    exit 1
fi

log INFO "Démarrage du backup - Profil: $PROFILE, Type: $BACKUP_TYPE"

SRC_DIR=$(get_config "$PROFILE" "source") || { log ERROR "Impossible de lire la configuration"; exit 1; }
DST_DIR=$(get_config "$PROFILE" "destination") || { log ERROR "Impossible de lire la configuration"; exit 1; }

log INFO "Source: $SRC_DIR, Destination: $DST_DIR"

if [[ ! -d "$SRC_DIR" ]]; then
    log WARN "Le dossier source n'existe pas : $SRC_DIR"
fi

mkdir_safe "$DST_DIR/FULL" "$DST_DIR/INC" "$DST_DIR/DIFF"

# ===== FULL =====
backup_full() {
    log INFO "Démarrage du backup FULL pour le profil $PROFILE"
    local filename="full_$(date +%Y-%m-%d_%H-%M-%S).tar.gz"
    
    if tar -czf "$DST_DIR/FULL/$filename" -C "$(dirname "$SRC_DIR")" "$(basename "$SRC_DIR")" 2>/dev/null; then
        log SUCCESS "Backup FULL terminé : $filename"
        generate_metadata "$DST_DIR/FULL/$filename" "$PROFILE" "full"
        echo "$filename" > "snap_${PROFILE}.dat"
        show_storage_state "$DST_DIR"
    else
        log ERROR "Échec de création du backup FULL"
        return 1
    fi
}

# ===== INCREMENTAL =====
backup_incremental() {
    log INFO "Démarrage du backup INCREMENTAL pour le profil $PROFILE"
    local SNAP="snap_${PROFILE}.dat"
    if [[ ! -f "$SNAP" ]]; then
        log WARN "Aucun snapshot → FULL forcé"
        backup_full
        return
    fi
    local LAST_FULL
    LAST_FULL=$(cat "$SNAP")
    local filename="inc_$(date +%Y-%m-%d_%H-%M-%S).tar.gz"
    
    if tar -czf "$DST_DIR/INC/$filename" -C "$(dirname "$SRC_DIR")" --newer-mtime "$(date -r "$DST_DIR/FULL/$LAST_FULL" +%Y-%m-%d\ %H:%M:%S)" "$(basename "$SRC_DIR")" 2>/dev/null; then
        log SUCCESS "Backup INCREMENTAL terminé : $filename"
        generate_metadata "$DST_DIR/INC/$filename" "$PROFILE" "incremental"
        echo "$filename" > "$SNAP"
        show_storage_state "$DST_DIR"
    else
        log ERROR "Échec de création du backup INCREMENTAL"
        return 1
    fi
}

# ===== DIFF =====
backup_diff() {
    log INFO "Démarrage du backup DIFFERENTIEL pour le profil $PROFILE"
    local LAST_FULL
    LAST_FULL=$(ls -1t "$DST_DIR/FULL"/*.tar.gz 2>/dev/null | head -n1 || true)
    if [[ -z "$LAST_FULL" ]]; then
        log WARN "Aucun FULL → FULL forcé"
        backup_full
        return
    fi

    local SNAP="snap_${PROFILE}.dat"
    [[ ! -f "$SNAP" ]] && tar -tzf "$LAST_FULL" | sed 's|^\./||' > "$SNAP"

    local CHANGED
    CHANGED=$(find "$SRC_DIR" -type f | sed "s|^$SRC_DIR/||" | while read f; do
        ! grep -qxF "$f" "$SNAP" && echo "$f"
    done)

    if [[ -z "$CHANGED" ]]; then
        log WARN "Aucun fichier modifié depuis le dernier FULL → rien à sauvegarder"
        return 0
    fi

    local DATE=$(date +%Y-%m-%d_%H-%M-%S)
    local ARCH="$DST_DIR/DIFF/diff_$DATE.tar.gz"
    
    if tar -czf "$ARCH" -C "$SRC_DIR" $CHANGED 2>/dev/null; then
        find "$SRC_DIR" -type f | sed "s|^$SRC_DIR/||" > "$SNAP"
        generate_metadata "$ARCH" "$PROFILE" "diff"
        show_storage_state "$DST_DIR"
        log SUCCESS "Backup DIFF terminé : $(basename "$ARCH")"
    else
        log ERROR "Échec de création du backup DIFF"
        return 1
    fi
}

case "$BACKUP_TYPE" in
    full) backup_full ;;
    incremental) backup_incremental ;;
    diff) backup_diff ;;
    *) log ERROR "Type de backup inconnu : $BACKUP_TYPE"; exit 1 ;;
esac

log SUCCESS "Backup terminé avec succès (logs : $LOG_FILE)"
