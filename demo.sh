#!/bin/bash
################################################################################
# DEMO.SH - Démonstration Complète du Système de Backup
################################################################################
#
# DESCRIPTION :
#   Script de démonstration interactif montrant toutes les fonctionnalités :
#   - Création de backups (FULL, INC, DIFF)
#   - Upload vers serveur distant
#   - Vérification de synchronisation
#   - Restauration complète et sélective
#   - Affichage de l'état du stockage
#
# USAGE :
#   ./demo.sh
#
# ÉTAPES DE LA DÉMO :
#   1. Vérification de l'environnement
#   2. Préparation des données de test
#   3. Affichage de l'état initial
#   4. Création d'un backup FULL
#   5. Modification des données
#   6. Création de backups INC et DIFF
#   7. Affichage de l'état après backups
#   8. Upload au serveur (si disponible)
#   9. Vérification de synchronisation
#   10. Restauration complète
#   11. Restauration sélective
#   12. Affichage de l'état final
#
# EXÉCUTION DEPUIS :
#   - Racine du projet : ./demo.sh
#   - Dossier backup-system : ../demo.sh
#
# DURÉE ESTIMÉE :
#   ~2 minutes avec serveur
#   ~1 minute sans serveur
#
# FICHIERS CRÉÉS :
#   - backup/FULL/*.tar.gz : Archives FULL
#   - backup/INC/*.tar.gz : Archives INCREMENTAL
#   - backup/DIFF/*.tar.gz : Archives DIFFERENTIAL
#   - logs/demo_YYYY-MM-DD.log : Logs de la démo
#
# DÉPENDANCES :
#   - ./backup.sh : Script de backup
#   - ./restore.sh : Script de restauration
#   - ./upload.sh : Script d'upload (optionnel)
#   - ./verify_sync.sh : Script de vérification (optionnel)
#   - lib/utils.sh : Bibliothèque utilitaire
#
# NOTE :
#   - La démo peut s'exécuter sans serveur (étapes 1-7, 10-12)
#   - Pour les étapes 8-9, le serveur doit être démarré
#   - Les données de test sont automatiquement créées
#
################################################################################

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log_step() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}$*${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
}

log_info() {
    echo -e "${GREEN}✓${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*"
}

pause() {
    echo -e "\n${YELLOW}[Appuyez sur Entrée pour continuer...]${NC}"
    read -r
}

clear
echo -e "${BLUE}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║          SYSTÈME DE BACKUP COMPLET - DÉMONSTRATION           ║
║                                                              ║
║  Cette démo va vous montrer toutes les fonctionnalités :     ║
║  • Création de backups (FULL, INC, DIFF)                     ║
║  • Upload vers le serveur distant                            ║
║  • Vérification de la synchronisation                        ║
║  • Restauration complète et sélective                        ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

pause

# Déterminer si on est à la racine ou dans backup-system
if [[ -d "backup-system" ]]; then
    WORK_DIR="backup-system"
    log_info "Exécution depuis la racine du projet"
else
    WORK_DIR="."
    log_info "Exécution depuis backup-system/"
fi

log_step "ÉTAPE 1 : Vérification de l'environnement"

cd "$WORK_DIR"

if [[ ! -f "lib/utils.sh" ]]; then
    log_error "Fichier lib/utils.sh introuvable"
    exit 1
fi
log_info "Fichiers du système présents"

PROFILE="document"
log_info "Profil utilisé : $PROFILE"

pause

log_step "ÉTAPE 2 : Préparation des données de test"

SRC_DIR="./document"
DST_DIR="./backup"

mkdir -p "$SRC_DIR"/{subdir1,subdir2,cache}

cat > "$SRC_DIR/readme.txt" << 'EOF'
Système de backup automatique
Version 1.0
EOF

cat > "$SRC_DIR/config.json" << 'EOF'
{
  "version": "1.0",
  "enabled": true
}
EOF

echo "Données importantes" > "$SRC_DIR/subdir1/data.txt"
echo "Fichier temporaire" > "$SRC_DIR/subdir1/temp.tmp"
echo "Logs applicatifs" > "$SRC_DIR/subdir2/app.log"
echo "Cache navigateur" > "$SRC_DIR/cache/browser.cache"

log_info "Structure créée :"
tree "$SRC_DIR" || find "$SRC_DIR" -type f

pause

log_step "ÉTAPE 3 : Nettoyage des anciens backups"

read -p "Voulez-vous vider les anciens backups ? (oui/non) : " CLEAN
if [[ "$CLEAN" == "oui" ]]; then
    for sub in FULL INC DIFF; do
        if [[ -d "$DST_DIR/$sub" ]]; then
            rm -f "$DST_DIR/$sub"/*.tar.gz "$DST_DIR/$sub"/*.meta.json 2>/dev/null || true
        fi
    done
    rm -f snap_*.dat 2>/dev/null || true
    log_info "Backups nettoyés"
else
    log_warn "Conservation des backups existants"
fi

pause

log_step "ÉTAPE 4 : Création du backup FULL"

log_info "Lancement du backup complet..."
./backup.sh --profile "$PROFILE" --type full

log_info "Contenu de l'archive FULL :"
FULL_ARCHIVE=$(ls -1t "$DST_DIR/FULL"/*.tar.gz | head -n1)
tar -tzf "$FULL_ARCHIVE" | head -10

pause

log_step "ÉTAPE 5 : Modification de fichiers (simulation)"

sleep 2

echo "Modification 1" >> "$SRC_DIR/readme.txt"
echo "Nouveau fichier" > "$SRC_DIR/subdir1/nouveau.txt"

log_info "Fichiers modifiés :"
log_info "  - readme.txt (modifié)"
log_info "  - subdir1/nouveau.txt (créé)"

pause

log_step "ÉTAPE 6 : Création du backup INCREMENTAL"

log_info "Lancement du backup incrémental..."
./backup.sh --profile "$PROFILE" --type incremental

if [[ -f "$DST_DIR/INC"/*.tar.gz ]]; then
    log_info "Contenu de l'archive INCREMENTAL :"
    INC_ARCHIVE=$(ls -1t "$DST_DIR/INC"/*.tar.gz | head -n1)
    tar -tzf "$INC_ARCHIVE"
else
    log_warn "Aucun fichier modifié détecté"
fi

pause

log_step "ÉTAPE 7 : Nouvelles modifications"

sleep 2

if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' 's/"enabled": true/"enabled": false/' "$SRC_DIR/config.json"
else
    sed -i 's/"enabled": true/"enabled": false/' "$SRC_DIR/config.json"
fi
echo "Logs supplémentaires" >> "$SRC_DIR/subdir2/app.log"

log_info "Fichiers modifiés :"
log_info "  - config.json (modifié)"
log_info "  - subdir2/app.log (modifié)"

pause

log_step "ÉTAPE 8 : Création du backup DIFFERENTIAL"

log_info "Lancement du backup différentiel..."
./backup.sh --profile "$PROFILE" --type diff

if [[ -f "$DST_DIR/DIFF"/*.tar.gz ]]; then
    log_info "Contenu de l'archive DIFF :"
    DIFF_ARCHIVE=$(ls -1t "$DST_DIR/DIFF"/*.tar.gz | head -n1)
    tar -tzf "$DIFF_ARCHIVE"
else
    log_warn "Aucun fichier modifié détecté"
fi

pause

log_step "ÉTAPE 9 : Vérification des métadonnées"

for type in FULL INC DIFF; do
    if [[ -d "$DST_DIR/$type" ]]; then
        for meta in "$DST_DIR/$type"/*.meta.json; do
            [[ -f "$meta" ]] || continue
            echo -e "\n${CYAN}$(basename "$meta"):${NC}"
            cat "$meta" | jq '.'
        done
    fi
done

pause

log_step "ÉTAPE 10 : État du stockage"

echo "--- Récapitulatif des backups ---"
for type in FULL INC DIFF; do
    if [[ -d "$DST_DIR/$type" ]]; then
        count=$(ls -1 "$DST_DIR/$type"/*.tar.gz 2>/dev/null | wc -l)
        size=$(du -sh "$DST_DIR/$type" 2>/dev/null | awk '{print $1}')
        echo "$type : $count archive(s), $size"
    fi
done

pause

log_step "ÉTAPE 11 : Test de restauration (dry-run)"

log_info "Simulation de restauration complète..."
./restore.sh --profile "$PROFILE" --dry-run

pause

log_step "ÉTAPE 12 : Sauvegarde et suppression des données"

TEMP_BACKUP="/tmp/demo_backup_$$"
cp -r "$SRC_DIR" "$TEMP_BACKUP"
log_info "Données sauvegardées dans $TEMP_BACKUP"

rm -rf "$SRC_DIR"
log_warn "Dossier $SRC_DIR supprimé"

ls -la "$(dirname "$SRC_DIR")" | grep -v "$SRC_DIR" || log_error "Le dossier a bien été supprimé"

pause

log_step "ÉTAPE 13 : Restauration complète"

log_info "Restauration depuis les backups..."
./restore.sh --profile "$PROFILE"

if [[ -d "$SRC_DIR" ]]; then
    log_info "Restauration réussie !"
    log_info "Fichiers restaurés :"
    tree "$SRC_DIR" || find "$SRC_DIR" -type f
else
    log_error "Échec de la restauration"
fi

pause

log_step "ÉTAPE 14 : Vérification de l'intégrité"

log_info "Comparaison avant/après restauration..."
diff -r "$TEMP_BACKUP" "$SRC_DIR" && log_info "Les données sont identiques !" || log_warn "Différences détectées"

rm -rf "$TEMP_BACKUP"

pause

log_step "ÉTAPE 15 : Test de restauration sélective"

rm -f "$SRC_DIR/readme.txt"
log_warn "Fichier readme.txt supprimé"

log_info "Restauration du fichier readme.txt uniquement..."
./restore.sh --profile "$PROFILE" --file readme.txt

if [[ -f "$SRC_DIR/readme.txt" ]]; then
    log_info "Fichier readme.txt restauré avec succès"
    cat "$SRC_DIR/readme.txt"
else
    log_error "Échec de la restauration du fichier"
fi

pause

log_step "ÉTAPE 16 : Upload vers le serveur (optionnel)"

read -p "Le serveur Flask est-il démarré ? (oui/non) : " SERVER_RUNNING

if [[ "$SERVER_RUNNING" == "oui" ]]; then
    log_info "Nettoyage des anciens backups du serveur..."
    ./clear_remote_backups.sh <<< "oui"
    
    pause
    
    log_info "Upload des backups vers le serveur..."
    ./upload.sh "$PROFILE" --all
    
    pause
    
    log_step "ÉTAPE 17 : Vérification de la synchronisation"
    
    log_info "Vérification local <-> distant..."
    ./verify_sync.sh
    
    pause
    
    log_step "ÉTAPE 18 : Statistiques du serveur"
    
    log_info "Récupération des statistiques..."
    ./verify_sync.sh --stats
    
    pause
    
    log_step "ÉTAPE 19 : Test de téléchargement depuis le serveur"
    
    log_info "Sauvegarde des backups locaux..."
    TEMP_BACKUP_DIR="/tmp/local_backups_$"
    cp -r "$DST_DIR" "$TEMP_BACKUP_DIR"
    
    log_info "Suppression des backups locaux..."
    for sub in FULL INC DIFF; do
        if [[ -d "$DST_DIR/$sub" ]]; then
            rm -f "$DST_DIR/$sub"/*.tar.gz "$DST_DIR/$sub"/*.meta.json 2>/dev/null || true
        fi
    done
    
    log_warn "Backups locaux supprimés"
    echo "--- État actuel du stockage local ---"
    for type in FULL INC DIFF; do
        if [[ -d "$DST_DIR/$type" ]]; then
            count=$(ls -1 "$DST_DIR/$type"/*.tar.gz 2>/dev/null | wc -l || echo 0)
            echo "$type : $count archive(s)"
        fi
    done
    
    pause
    
    log_info "Téléchargement depuis le serveur..."
    ./download.sh "$PROFILE" --all
    
    log_info "Vérification des fichiers téléchargés..."
    echo "--- État après téléchargement ---"
    for type in FULL INC DIFF; do
        if [[ -d "$DST_DIR/$type" ]]; then
            count=$(ls -1 "$DST_DIR/$type"/*.tar.gz 2>/dev/null | wc -l || echo 0)
            size=$(du -sh "$DST_DIR/$type" 2>/dev/null | awk '{print $1}')
            echo "$type : $count archive(s), $size"
        fi
    done
    
    log_info "Backups téléchargés avec succès !"
    
    log_info "Vérification de synchronisation finale..."
    ./verify_sync.sh
    
    rm -rf "$TEMP_BACKUP_DIR"
else
    log_warn "Étapes serveur ignorées (serveur non démarré)"
    log_info "Pour démarrer le serveur : ./start-server.sh"
fi

pause

log_step "ÉTAPE 20 : Logs générés"

echo "Les logs ont été enregistrés dans :"
ls -lh logs/

echo -e "\n${CYAN}Contenu du dernier log de backup :${NC}"
tail -20 logs/backup_$(date +%Y-%m-%d).log

pause

log_step "FIN DE LA DÉMONSTRATION"

echo -e "${GREEN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║                  DÉMONSTRATION TERMINÉE !                    ║
║                                                              ║
║  Vous avez vu :                                              ║
║  ✓ Création de backups FULL, INCREMENTAL, DIFFERENTIAL       ║
║  ✓ Génération de métadonnées                                 ║
║  ✓ Restauration complète avec application des INC/DIFF       ║
║  ✓ Restauration sélective d'un fichier                       ║
║  ✓ Upload vers serveur distant (optionnel)                   ║
║  ✓ Vérification de synchronisation (optionnel)               ║
║  ✓ Téléchargement depuis le serveur (optionnel)              ║
║                                                              ║
║  Le système est prêt à l'emploi !                            ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "\n${CYAN}Commandes utiles :${NC}"
echo "  ./backup.sh --profile document --type full"
echo "  ./backup.sh --profile document --type incremental"
echo "  ./restore.sh --profile document"
echo "  ./restore.sh --profile document --file fichier.txt"
echo "  ./upload.sh document --all"
echo "  ./download.sh document --all"
echo "  ./verify_sync.sh"
echo "  ./clear_backups.sh"
echo "  ./clear_remote_backups.sh"
echo ""