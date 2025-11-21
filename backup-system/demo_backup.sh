#!/bin/bash
set -euo pipefail

source lib/utils.sh

PROFILE="document"

echo "===== Début de la démo ====="

SRC_DIR=$(get_config "$PROFILE" "source")
DST_DIR=$(get_config "$PROFILE" "destination")

echo "Profil utilisé : $PROFILE"
echo "Dossier document : $SRC_DIR"
echo "Dossier backup : $DST_DIR"
echo

# Création fichiers de test
mkdir_safe "$SRC_DIR"
echo "TEST FULL - $(date)" > "$SRC_DIR/demo_full.txt"
echo "TEST INCR - $(date)" > "$SRC_DIR/demo_incr.txt"
echo "TEST DIFF - $(date)" > "$SRC_DIR/demo_diff.txt"

mkdir_safe "$SRC_DIR/subdir1" "$SRC_DIR/subdir2"
echo "File A" > "$SRC_DIR/subdir1/fileA.txt"
echo "File B" > "$SRC_DIR/subdir1/fileB.tmp"
echo "File C" > "$SRC_DIR/subdir2/fileC.txt"

mkdir_safe "$SRC_DIR/cache"
echo "Cached" > "$SRC_DIR/cache/cached_file.txt"

# Vidage anciens backups
read -p "Vider les anciens backups ? (oui/non) " RESP
if [[ "$RESP" == "oui" ]]; then
    for sub in FULL INC DIFF; do
        for file in "$DST_DIR/$sub"/*.tar.gz "$DST_DIR/$sub"/*.meta.json; do
            [[ -f "$file" ]] && rm_safe "$file"
        done
    done
    echo "Backups vidés (snapshot conservé)."
fi

# Backups
./backup.sh --profile "$PROFILE" --type full
./backup.sh --profile "$PROFILE" --type incremental
./backup.sh --profile "$PROFILE" --type diff

# Vérification archives
for type in FULL INC DIFF; do
    echo "--- $type ---"
    for arc in "$DST_DIR/$type"/*.tar.gz; do
        [[ -f "$arc" ]] || continue
        echo "Archive : $arc"
        tar -tzf "$arc"
        verify_checksum "$arc"
    done
done

echo "===== Démo terminée ====="
