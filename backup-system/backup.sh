#!/bin/bash

# =====================
# Script principal de backup
# =====================

# Import des modules
source lib/utils.sh
source lib/usage.sh

# =====================
# Parsing des arguments
# =====================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --profile)
                PROFILE="$2"
                shift 2
                ;;
            --type)
                BACKUP_TYPE="$2"
                shift 2
                ;;
            *)
                echo "Argument inconnu : $1"
                exit 1
                ;;
        esac
    done

    if [[ -z "$PROFILE" ]]; then
        echo "Erreur : --profile obligatoire"
        exit 1
    fi

    if [[ -z "$BACKUP_TYPE" ]]; then
        echo "Erreur : --type obligatoire (full | incremental | diff)"
        exit 1
    fi
}

# =====================
# Backup complet
# =====================
backup_full() {
    log "Démarrage du backup FULL pour le profil $PROFILE"

    src=$(get_config "$PROFILE" "source")
    dst=$(get_config "$PROFILE" "destination")

    mkdir -p "$dst"

    filename="full_$(date +%Y-%m-%d_%H-%M-%S).tar.gz"
    tar -czf "$dst/$filename" "$src"

    log "Backup FULL terminé : $filename"
}

# =====================
# Backup incrémental (squelette)
# =====================
backup_incremental() {
    log "Backup INCREMENTAL pour $PROFILE (fonction à compléter)"
    # TODO : comparer avec dernier backup et ne sauvegarder que les changements
}

# =====================
# Backup différentiel (squelette)
# =====================
backup_diff() {
    log "Backup DIFFERENTIEL pour $PROFILE (fonction à compléter)"
    # TODO : comparer avec dernier backup complet et ne sauvegarder que les changements
}

# =====================
# Main
# =====================
main() {
    parse_args "$@"

    case "$BACKUP_TYPE" in
        full)
            backup_full
            ;;
        incremental)
            backup_incremental
            ;;
        diff)
            backup_diff
            ;;
        *)
            echo "Type inconnu : $BACKUP_TYPE"
            exit 1
            ;;
    esac

    # Mise à jour automatique des noms des dossiers selon % occupation
    apply_usage_labels

    log "Backup terminé avec succès."
}

main "$@"
