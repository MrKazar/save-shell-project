# Système de Backup Automatique

Système complet de sauvegarde en Bash avec synchronisation via serveur Flask.

## Description

Ce projet offre une solution complète de sauvegarde avec trois stratégies différentes :
- **FULL** : Sauvegarde complète de tous les fichiers
- **INCREMENTAL** : Sauvegarde des fichiers modifiés depuis le dernier FULL
- **DIFFERENTIAL** : Sauvegarde des fichiers modifiés depuis le dernier FULL

Le système inclut également un serveur Flask permettant la synchronisation des backups vers un serveur distant.

## Fonctionnalités

### Backups Locaux
- Création de backups FULL, INCREMENTAL et DIFFERENTIAL
- Compression automatique (tar.gz)
- Génération de métadonnées JSON avec checksums MD5
- Logs quotidiens consolidés par type d'opération
- Gestion de sessions pour le traçage des opérations
- Vérification d'intégrité des archives

### Restauration
- Restauration complète avec application automatique des INC/DIFF
- Restauration sélective d'un fichier spécifique
- Mode dry-run pour tester sans modifier les fichiers
- Recherche intelligente dans toutes les archives

### Synchronisation Distante
- Upload des backups vers un serveur Flask
- Download des backups depuis le serveur
- Vérification de synchronisation avec comparaison MD5
- Statistiques détaillées du serveur
- Nettoyage des backups locaux et distants

## Architecture

```
.
├── backup-system/              # Scripts de backup locaux
│   ├── backup.sh              # Création des backups
│   ├── restore.sh             # Restauration
│   ├── upload.sh              # Upload vers serveur
│   ├── download.sh            # Download depuis serveur
│   ├── verify_sync.sh         # Vérification de synchro
│   ├── clear_backups.sh       # Nettoyage local
│   ├── clear_remote_backups.sh # Nettoyage distant
│   ├── lib/
│   │   ├── utils.sh           # Fonctions utilitaires
│   │   └── usage.sh           # Fonctions de configuration
│   ├── profiles/
│   │   └── document.yaml      # Configuration profil
│   ├── backup/                # Archives locales
│   │   ├── FULL/
│   │   ├── INC/
│   │   └── DIFF/
│   └── logs/                  # Logs quotidiens
│
├── serv/
│   └── backup-server/
│       ├── app.py             # Serveur Flask
│       ├── requirements.txt
│       └── remote_backups/    # Archives distantes
│
├── demo.sh                    # Démonstration interactive
└── start-server.sh            # Démarrage du serveur
```

## Installation

### Prérequis

**Système :**
- Linux, macOS ou WSL
- Bash 4.0 ou supérieur
- Python 3.6 ou supérieur

**Outils requis :**
```bash
# Sur Ubuntu/Debian
sudo apt install curl jq python3-flask

# Sur macOS
brew install curl jq
pip3 install Flask
```

### Installation rapide

```bash
# Cloner le projet
git clone <repository-url>
cd save-shell-project

# Rendre les scripts exécutables
chmod +x backup-system/*.sh
chmod +x *.sh

# Démarrer le serveur (optionnel)
./start-server.sh
```

## Utilisation

### 1. Création de Backups

```bash
cd backup-system

# Backup FULL (complet)
./backup.sh --profile document --type full

# Backup INCREMENTAL (depuis dernier FULL)
./backup.sh --profile document --type incremental

# Backup DIFFERENTIAL (depuis dernier FULL)
./backup.sh --profile document --type diff
```

### 2. Restauration

```bash
# Restauration complète (FULL + tous les INC/DIFF)
./restore.sh --profile document

# Mode test (sans modifier les fichiers)
./restore.sh --profile document --dry-run

# Restauration d'un fichier spécifique
./restore.sh --profile document --file readme.txt
```

### 3. Synchronisation avec le Serveur

```bash
# Démarrer le serveur (terminal séparé)
./start-server.sh

# Upload tous les backups
cd backup-system
./upload.sh document --all

# Download tous les backups
./download.sh document --all

# Vérifier la synchronisation
./verify_sync.sh

# Statistiques du serveur
./verify_sync.sh --stats
```

### 4. Nettoyage

```bash
# Nettoyer les backups locaux
cd backup-system
./clear_backups.sh

# Nettoyer les backups du serveur
./clear_remote_backups.sh
```

### 5. Démonstration Complète

```bash
# Lancer la démo interactive
./demo.sh
```

La démo montre toutes les fonctionnalités du système avec des explications détaillées à chaque étape.

## Configuration

### Profils

Les profils sont définis dans `backup-system/profiles/` au format YAML :

```yaml
source: ./document
destination: ./backup
```

Créez autant de profils que nécessaire pour différents dossiers à sauvegarder.

### Variables d'Environnement

```bash
# URL du serveur (défaut: http://localhost:5000)
export SERVER_URL="http://mon-serveur:5000"

# Dossier de backup (défaut: ./backup)
export BACKUP_DIR="/chemin/vers/backup"
```

## Fonctionnement Détaillé

### Stratégies de Backup

**FULL (Complet)**
- Archive complète du dossier source
- Crée un fichier snapshot pointant vers cette archive
- Base pour les backups incrémentaux et différentiels

**INCREMENTAL**
- Compare avec le dernier FULL via snapshot
- Utilise `find -newer` pour détecter les fichiers modifiés
- Le snapshot reste sur le FULL (correction du bug original)
- Plus rapide et moins volumineux que FULL

**DIFFERENTIAL**
- Même principe qu'INCREMENTAL
- Compare toujours avec le dernier FULL
- Contrairement à INCREMENTAL, inclut tous les changements depuis le FULL

### Processus de Restauration

1. Trouve le dernier backup FULL
2. Restaure le FULL complètement
3. Liste tous les INC créés après ce FULL
4. Applique les INC dans l'ordre chronologique
5. Liste tous les DIFF créés après ce FULL
6. Applique les DIFF dans l'ordre chronologique

Résultat : État exact des données au moment du dernier backup.

### Métadonnées

Chaque archive génère un fichier `.meta.json` contenant :

```json
{
  "archive": "./backup/FULL/full_2025-11-23_10-00-00.tar.gz",
  "profile": "document",
  "type": "full",
  "size": "12.5 KB",
  "files": 42,
  "checksum": "a1b2c3d4e5f6...",
  "parent": "",
  "date": "2025-11-23 10:00:00"
}
```

### Logs

Les logs sont organisés par jour et par type :
- `logs/backup_YYYY-MM-DD.log` : Tous les backups du jour
- `logs/restore_YYYY-MM-DD.log` : Toutes les restaurations du jour

Format des logs :
```
═══════════════════════════════════════════════════════════
[SESSION] 2025-11-23 10:00:00 - Nouvelle session
═══════════════════════════════════════════════════════════
[INFO]  2025-11-23 10:00:01 - Démarrage du backup...
[SUCCESS] 2025-11-23 10:00:05 - Backup FULL terminé
```

## API du Serveur Flask

### Endpoints Disponibles

**GET /** - Informations sur l'API

**POST /upload** - Upload un backup
```bash
curl -F "file=@backup.tar.gz" -F "type=FULL" -F "profile=document" \
  http://localhost:5000/upload
```

**GET /list** - Liste tous les backups
```bash
curl http://localhost:5000/list
```

**GET /list/TYPE** - Liste par type (FULL, INC, DIFF)
```bash
curl http://localhost:5000/list/FULL
```

**GET /download/TYPE/filename** - Télécharge un backup
```bash
curl -O http://localhost:5000/download/FULL/full_2025-11-23_10-00-00.tar.gz
```

**POST /verify** - Vérifie la synchronisation
```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"local_backups": {...}}' \
  http://localhost:5000/verify
```

**GET /stats** - Statistiques du serveur
```bash
curl http://localhost:5000/stats
```

## Automatisation avec Cron

Exemple de configuration crontab :

```bash
# Éditer le crontab
crontab -e

# Ajouter ces lignes :
# Backup FULL quotidien à 2h du matin
0 2 * * * cd /chemin/vers/backup-system && ./backup.sh --profile document --type full

# Backup INCREMENTAL toutes les 6 heures
0 */6 * * * cd /chemin/vers/backup-system && ./backup.sh --profile document --type incremental

# Upload quotidien à 3h du matin
0 3 * * * cd /chemin/vers/backup-system && ./upload.sh document --all

# Vérification de synchro à 4h du matin
0 4 * * * cd /chemin/vers/backup-system && ./verify_sync.sh >> /tmp/backup_verify.log 2>&1
```

## Auteurs

**MrKazar**, **VikusCode** et **NDesumeur**