#!/bin/bash

# Capacités max
MAX_BACKUP=$((10 * 1024 * 1024 * 1024))       # 10 Go
MAX_DOCUMENT=$((5 * 1024 * 1024 * 1024))      # 5 Go

# Dossiers à analyser — ADAPTE LES CHEMINS !
DIR_BACKUP="./backup"
DIR_DOCUMENT="./document"

rename_dir_with_percent() {
    local dir="$1"
    local max="$2"

    [ ! -d "$dir" ] && return

    used=$(du -sb "$dir" | awk '{print $1}')
    percent=$(( used * 100 / max ))
    percent=$(printf "%02d" "$percent")

    dirname=$(basename "$dir")
    parent=$(dirname "$dir")

    # Nettoyage si le dossier a déjà un pourcentage
    clean_name=$(echo "$dirname" | sed 's/^\[[0-9]\{2\}%\] //')

    newname="[$percent%] $clean_name"
    newpath="$parent/$newname"

    mv "$dir" "$newpath"
}

apply_usage_labels() {
    rename_dir_with_percent "$DIR_BACKUP" "$MAX_BACKUP"
    rename_dir_with_percent "$DIR_DOCUMENT" "$MAX_DOCUMENT"
}
