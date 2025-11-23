#!/bin/bash
set -euo pipefail

# =====================
# Récupération d'une config YAML
# =====================
get_config() {
    local profile="$1"
    local key="$2"
    local file="profiles/$profile.yaml"

    if [[ ! -f "$file" ]]; then
        echo "Erreur : config introuvable : $file"
        exit 1
    fi

    # Extraction simple YAML : clé: valeur
    grep -E "^$key:" "$file" | awk -F': ' '{print $2}'
}
