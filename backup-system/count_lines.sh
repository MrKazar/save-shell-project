#!/bin/bash
# Script pour compter le nombre de lignes de code du projet

# Extensions à inclure
EXTENSIONS="sh yaml"

echo "=== Nombre de lignes de code dans le projet ==="

TOTAL=0

for EXT in $EXTENSIONS; do
    # Trouver tous les fichiers de cette extension
    FILES=$(find . -type f -name "*.$EXT")
    
    if [[ -n "$FILES" ]]; then
        LINES=$(cat $FILES | wc -l)
        echo "$EXT : $LINES lignes"
        TOTAL=$((TOTAL + LINES))
    fi
done

echo "----------------------------"
echo "Total : $TOTAL lignes de code"
