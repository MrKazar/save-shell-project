#!/bin/bash

# ===== LOGGING =====
log() {
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $1"
    echo "[$timestamp] $1" >> logs/backup.log
}

# ===== PARSE SIMPLE YAML (clé: valeur) =====
get_config() {
    profile="$1"
    key="$2"
    file="config/${profile}.yaml"

    if [[ ! -f "$file" ]]; then
        echo "Erreur : config introuvable : $file"
        exit 1
    fi

    value=$(grep "^$key:" "$file" | sed "s/$key: //")
    echo "$value"
}
