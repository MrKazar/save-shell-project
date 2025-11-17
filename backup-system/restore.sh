#!/bin/bash

# =====================
# Script de restauration
# =====================

source lib/utils.sh

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
            --file)
                FILE_TO_RESTORE="$2"
                shift 2
                ;;
            --date)
                DATE="$2"
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
}

# =====================
# Restauration d’un fichier ou d’un dossier
# =====================
restore_file() {
    log "Début de la restauration pour profil $PROFILE"

    src=$(get_config "$PROFILE" "destination")

    if [[ -n "$DATE" ]]; then
        archive=$(ls "$src" | grep "$DATE")
        if [[ -z "$archive" ]]; then
            echo "Aucune archive trouvée pour la date $DATE"
            exit 1
        fi
    else
        # Dernière archive
        archive=$(ls -1 "$src" | sort | tail -n1)
    fi

    if [[ -n "$FILE_TO_RESTORE" ]]; then
        tar -xzf "$src/$archive" -C ./restored "$FILE_TO_RESTORE"
        log "Fichier restauré : $FILE_TO_RESTORE"
    else
        mkdir -p ./restored
        tar -xzf "$src/$archive" -C ./restored
        log "Restauration complète effectuée"
    fi
}

# =====================
# Main
# =====================
main() {
    parse_args "$@"
    restore_file
}

main "$@"
