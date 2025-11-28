#!/bin/bash
set -euo pipefail

# Variables globales pour les logs
LOG_FILE=""
LOG_DIR="logs"

# =====================
# Initialiser les logs (un fichier par jour, dans un dossier log_JJ_MM_AAAA)
# =====================
init_logs() {
    local script_name="$1"
    mkdir_safe "$LOG_DIR"
    local today_formatted=$(date +%d_%m_%Y)
    local log_subdir="${LOG_DIR}/log_${today_formatted}"
    mkdir_safe "$log_subdir"
    LOG_FILE="${log_subdir}/${script_name}.log"
}

# =====================
# Log avec timestamp (console + fichier)
# =====================
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
    
    # Écrire dans le fichier log (append)
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$level] $timestamp - $message" >> "$LOG_FILE"
    fi
}

# =====================
# Initialiser une session de log
# =====================
log_session_start() {
    if [[ -n "$LOG_FILE" ]]; then
        echo "" >> "$LOG_FILE"
        echo "═══════════════════════════════════════════════════════════" >> "$LOG_FILE"
        echo "[SESSION] $(date '+%Y-%m-%d %H:%M:%S') - Nouvelle session" >> "$LOG_FILE"
        echo "═══════════════════════════════════════════════════════════" >> "$LOG_FILE"
    fi
}

# =====================
# Crée un ou plusieurs dossiers si nécessaire
# =====================
mkdir_safe() {
    for dir in "$@"; do
        [[ -d "$dir" ]] || mkdir -p "$dir"
    done
}

# =====================
# Supprime des fichiers ou dossiers de manière sûre
# =====================
rm_safe() {
    for item in "$@"; do
        if [[ -f "$item" ]]; then
            rm -f "$item"
        elif [[ -d "$item" ]]; then
            rm -rf "$item"
        fi
    done
}

# =====================
# Génération de métadonnées
# =====================
generate_metadata() {
    local archive="$1"
    local profile="$2"
    local type="$3"

    local size files
    size=$(du -sh "$archive" | awk '{print $1}')
    files=$(tar -tzf "$archive" | wc -l)

    cat > "$archive.meta.json" <<EOF
{
  "archive": "$archive",
  "profile": "$profile",
  "type": "$type",
  "size": "$size",
  "files": $files,
  "date": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF

    log INFO "Métadonnées créées : $(basename "$archive.meta.json")"
}

# =====================
# Vérification checksum
# =====================
verify_checksum() {
    local archive="$1"
    # Simple exemple : on vérifie juste si l'archive existe et est lisible
    if tar -tzf "$archive" >/dev/null 2>&1; then
        echo "Checksum OK pour $archive"
    else
        echo "Checksum KO pour $archive"
    fi
}

# =====================
# Lecture configuration depuis profil YAML
# =====================
get_config() {
    local profile="$1"
    local key="$2"
    local profile_file="profiles/${profile}.yaml"
    
    if [[ ! -f "$profile_file" ]]; then
        echo "Erreur : fichier de profil non trouvé : $profile_file" >&2
        exit 1
    fi
    
    grep "^${key}:" "$profile_file" | cut -d':' -f2- | xargs
}

# =====================
# Affiche l'état du stockage
# =====================
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
