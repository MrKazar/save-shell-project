#!/bin/bash
# =============================================================================
# UTILS.SH - Bibliothèque de fonctions utilitaires
# =============================================================================
# Description:
#   Contient toutes les fonctions réutilisables du système de backup
#   Inclus par les autres scripts via : source lib/utils.sh
#
# Fonctions disponibles:
#   - init_logs(script_name)           : Initialise les logs
#   - log(level, message)              : Écrit un message dans les logs
#   - log_session_start()              : Marque le début d'une session
#   - mkdir_safe(dirs...)              : Crée des dossiers de manière sûre
#   - rm_safe(paths...)                : Supprime des fichiers/dossiers
#   - generate_metadata(...)           : Génère les métadonnées JSON
#   - verify_checksum(archive)         : Vérifie l'intégrité d'une archive
#   - get_config(profile, key)         : Lit la configuration YAML
#   - show_storage_state(dst_dir)      : Affiche l'état du stockage
# =============================================================================

set -euo pipefail

# Variables globales
LOG_FILE=""
LOG_DIR="logs"

# =============================================================================
# INIT_LOGS - Initialise le système de logs
# =============================================================================
# Crée un fichier de log par jour et par type de script
# Format: logs/backup_2025-11-22.log, logs/restore_2025-11-22.log
#
# Arguments:
#   $1 : Nom du script (backup, restore, etc.)
#
# Exemple:
#   init_logs "backup"
#   → Crée logs/backup_2025-11-22.log
# =============================================================================
init_logs() {
    local script_name="$1"
    mkdir_safe "$LOG_DIR"
    local today=$(date +%Y-%m-%d)
    LOG_FILE="${LOG_DIR}/${script_name}_${today}.log"
}

# =============================================================================
# LOG - Écrit un message dans les logs et la console
# =============================================================================
# Affiche un message avec couleur dans la console et l'enregistre dans le log
#
# Arguments:
#   $1 : Niveau (INFO, WARN, ERROR, SUCCESS)
#   $@ : Message à logger
#
# Niveaux:
#   INFO    : Message informatif (bleu)
#   WARN    : Avertissement (jaune)
#   ERROR   : Erreur (rouge, écrit sur stderr)
#   SUCCESS : Opération réussie (vert)
#
# Exemple:
#   log INFO "Démarrage du backup"
#   log ERROR "Fichier introuvable"
# =============================================================================
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        ERROR)
            echo -e "\033[0;31m[ERROR]\033[0m $timestamp - $message" >&2
            ;;
        WARN)
            echo -e "\033[1;33m[WARN]\033[0m  $timestamp - $message"
            ;;
        SUCCESS)
            echo -e "\033[0;32m[SUCCESS]\033[0m $timestamp - $message"
            ;;
        *)
            echo -e "\033[0;34m[INFO]\033[0m  $timestamp - $message"
            ;;
    esac
    
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$level] $timestamp - $message" >> "$LOG_FILE"
    fi
}

# =============================================================================
# LOG_SESSION_START - Marque le début d'une nouvelle session
# =============================================================================
# Ajoute un séparateur visuel dans le fichier de log pour distinguer
# les différentes exécutions du script
#
# Exemple dans le log:
#   ═══════════════════════════════════════════════════════════
#   [SESSION] 2025-11-22 14:30:15 - Nouvelle session
#   ═══════════════════════════════════════════════════════════
# =============================================================================
log_session_start() {
    if [[ -n "$LOG_FILE" ]]; then
        echo "" >> "$LOG_FILE"
        echo "═══════════════════════════════════════════════════════════" >> "$LOG_FILE"
        echo "[SESSION] $(date '+%Y-%m-%d %H:%M:%S') - Nouvelle session" >> "$LOG_FILE"
        echo "═══════════════════════════════════════════════════════════" >> "$LOG_FILE"
    fi
}

# =============================================================================
# MKDIR_SAFE - Crée des dossiers de manière sûre
# =============================================================================
# Crée un ou plusieurs dossiers uniquement s'ils n'existent pas déjà
# Équivalent à: mkdir -p
#
# Arguments:
#   $@ : Liste de chemins de dossiers à créer
#
# Exemple:
#   mkdir_safe "backup/FULL" "backup/INC" "backup/DIFF"
# =============================================================================
mkdir_safe() {
    for dir in "$@"; do
        [[ -d "$dir" ]] || mkdir -p "$dir"
    done
}

# =============================================================================
# RM_SAFE - Supprime des fichiers ou dossiers de manière sûre
# =============================================================================
# Supprime des fichiers ou dossiers uniquement s'ils existent
# Ne génère pas d'erreur si l'élément n'existe pas
#
# Arguments:
#   $@ : Liste de chemins à supprimer
#
# Exemple:
#   rm_safe "temp.txt" "cache/"
# =============================================================================
rm_safe() {
    for item in "$@"; do
        if [[ -f "$item" ]]; then
            rm -f "$item"
        elif [[ -d "$item" ]]; then
            rm -rf "$item"
        fi
    done
}

# =============================================================================
# GENERATE_METADATA - Génère un fichier JSON de métadonnées
# =============================================================================
# Crée un fichier .meta.json contenant les informations sur l'archive
#
# Arguments:
#   $1 : Chemin de l'archive
#   $2 : Nom du profil
#   $3 : Type de backup (full, incremental, diff)
#   $4 : (Optionnel) Nom du backup parent (pour INC/DIFF)
#
# Métadonnées générées:
#   - archive   : Chemin complet de l'archive
#   - profile   : Nom du profil utilisé
#   - type      : Type de backup
#   - size      : Taille lisible (ex: 12.5 MB)
#   - files     : Nombre de fichiers dans l'archive
#   - checksum  : Hash MD5 de l'archive
#   - parent    : Archive FULL de référence (pour INC/DIFF)
#   - date      : Date de création
#
# Exemple:
#   generate_metadata "backup/FULL/full_2025-11-22.tar.gz" "document" "full"
#   → Crée backup/FULL/full_2025-11-22.tar.gz.meta.json
# =============================================================================
generate_metadata() {
    local archive="$1"
    local profile="$2"
    local type="$3"
    local parent="${4:-}"

    local size files checksum
    size=$(du -sh "$archive" | awk '{print $1}')
    files=$(tar -tzf "$archive" 2>/dev/null | wc -l)
    
    # Calcul du checksum MD5 (portable Linux/Mac)
    checksum=$(md5sum "$archive" 2>/dev/null | awk '{print $1}' || md5 -q "$archive" 2>/dev/null)

    cat > "$archive.meta.json" <<EOF
{
  "archive": "$archive",
  "profile": "$profile",
  "type": "$type",
  "size": "$size",
  "files": $files,
  "checksum": "$checksum",
  "parent": "$parent",
  "date": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF

    log INFO "Métadonnées créées : $(basename "$archive.meta.json")"
}

# =============================================================================
# VERIFY_CHECKSUM - Vérifie l'intégrité d'une archive
# =============================================================================
# Compare le checksum MD5 actuel avec celui stocké dans les métadonnées
# Permet de détecter une corruption de fichier
#
# Arguments:
#   $1 : Chemin de l'archive
#
# Retour:
#   0 : Checksum OK (fichier intègre)
#   1 : Checksum KO (fichier corrompu) ou métadonnées introuvables
#
# Exemple:
#   if verify_checksum "backup/FULL/full_2025-11-22.tar.gz"; then
#       echo "Fichier OK"
#   else
#       echo "Fichier corrompu"
#   fi
# =============================================================================
verify_checksum() {
    local archive="$1"
    local meta_file="${archive}.meta.json"
    
    if [[ ! -f "$meta_file" ]]; then
        echo "Métadonnées introuvables pour $archive"
        return 1
    fi
    
    # Extraction du checksum stocké dans les métadonnées
    local stored_checksum=$(grep '"checksum"' "$meta_file" | cut -d'"' -f4)
    
    # Calcul du checksum actuel
    local current_checksum=$(md5sum "$archive" 2>/dev/null | awk '{print $1}' || md5 -q "$archive" 2>/dev/null)
    
    if [[ "$stored_checksum" == "$current_checksum" ]]; then
        echo "Checksum OK pour $(basename "$archive")"
        return 0
    else
        echo "Checksum KO pour $(basename "$archive")"
        return 1
    fi
}

# =============================================================================
# GET_CONFIG - Lit une valeur depuis un fichier de profil YAML
# =============================================================================
# Extrait une valeur de configuration depuis profiles/<profil>.yaml
#
# Arguments:
#   $1 : Nom du profil
#   $2 : Clé à extraire
#
# Format YAML attendu:
#   source: ./document
#   destination: ./backup
#
# Exemple:
#   SRC=$(get_config "document" "source")
#   → Retourne "./document"
# =============================================================================
get_config() {
    local profile="$1"
    local key="$2"
    local profile_file="profiles/${profile}.yaml"
    
    if [[ ! -f "$profile_file" ]]; then
        echo "Erreur : fichier de profil non trouvé : $profile_file" >&2
        exit 1
    fi
    
    # Extraction simple : trouve la ligne "key:" et extrait la valeur
    grep "^${key}:" "$profile_file" | cut -d':' -f2- | xargs
}

# =============================================================================
# SHOW_STORAGE_STATE - Affiche l'état actuel du stockage
# =============================================================================
# Liste le nombre d'archives et l'espace utilisé pour chaque type de backup
#
# Arguments:
#   $1 : Dossier de destination (ex: ./backup)
#
# Affichage:
#   --- État du stockage ---
#   FULL : 2 archives, 45.2 MB
#   INC  : 5 archives, 12.8 MB
#   DIFF : 3 archives, 8.5 MB
#
# Exemple:
#   show_storage_state "./backup"
# =============================================================================
show_storage_state() {
    local dst_dir="$1"
    
    if [[ ! -d "$dst_dir" ]]; then
        echo "Dossier destination inexistant : $dst_dir"
        return
    fi
    
    echo "--- État du stockage ---"
    for type in FULL INC DIFF; do
        local type_dir="$dst_dir/$type"
        if [[ -d "$type_dir" ]]; then
            local count=$(find "$type_dir" -maxdepth 1 -type f -name "*.tar.gz" 2>/dev/null | wc -l)
            local size=$(du -sh "$type_dir" 2>/dev/null | awk '{print $1}')
            echo "$type : $count archives, $size"
        fi
    done
}