#!/bin/bash
# Script pour vider tous les backups en toute sécurité

# Résolution du dossier backup (échappe les crochets)
BACKUP_FOLDER=$(ls -d ./"backup") || { echo "Dossier backup introuvable"; exit 1; }

echo "ATTENTION !"
echo "Ce script va supprimer **tous les fichiers** dans : $BACKUP_FOLDER"
echo "Les sous-dossiers FULL, INC et DIFF seront également vidés."
echo
read -p "Êtes-vous sûr de vouloir continuer ? (oui/non) : " CONFIRM

if [[ "$CONFIRM" != "oui" ]]; then
    echo "Annulation de l'opération."
    exit 0
fi

# Suppression des fichiers dans FULL, INC et DIFF
for SUB in FULL INC DIFF; do
    TARGET="$BACKUP_FOLDER/$SUB"
    if [[ -d "$TARGET" ]]; then
        echo "Vidage de $TARGET..."
        rm -rf "$TARGET"/*
    else
        echo "Sous-dossier $TARGET introuvable, création..."
        mkdir -p "$TARGET"
    fi
done

echo "Tous les backups ont été vidés avec succès."
