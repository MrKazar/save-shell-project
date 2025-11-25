# 📦 BACKUP SYSTEM - Projet Shell

## 📋 Description 

Système de sauvegarde **professionnel** en Bash avec support de trois types de backups et synchronisation serveur :

### Types de Backups
- ✅ **FULL** - Sauvegarde complète de tous les fichiers
- ✅ **INCREMENTAL** - Fichiers modifiés depuis le dernier FULL
- ✅ **DIFFERENTIAL** - Fichiers modifiés depuis le dernier FULL (sans chainage)

### Fonctionnalités Principales
- ⚙️ Compression automatique (tar.gz avec métadonnées)
- 📊 Logs consolidés par jour et par type de script
- 🔄 Restauration complète ou sélective (fichier spécifique)
- 🛡️ Vérification d'intégrité (MD5/checksums)
- 🌐 Synchronisation avec serveur Flask distant
- 🔐 Gestion sécurisée des fichiers (mkdir_safe, rm_safe)
- 🎯 Configuration flexible avec profils YAML
- 📈 Mode dry-run pour tester les opérations

---

## 📁 Structure du Projet

```
save-shell-project/
│
├── backup-system/                  # Dossier principal du système
│   ├── backup.sh                   # Créer des backups (FULL/INC/DIFF)
│   ├── restore.sh                  # Restaurer depuis archives
│   ├── upload.sh                   # Envoyer vers serveur distant
│   ├── download.sh                 # Télécharger depuis serveur
│   ├── verify_sync.sh              # Vérifier synchronisation local/distant
│   ├── clear_backups.sh            # Nettoyer backups locaux
│   ├── clear_remote_backups.sh     # Nettoyer backups serveur
│   │
│   ├── lib/
│   │   ├── utils.sh                # Fonctions utilitaires (logging, config, etc.)
│   │   └── usage.sh                # Helpers pour configuration YAML
│   │
│   ├── profiles/
│   │   └── document.yaml           # Configuration source/destination
│   │
│   ├── document/                   # Dossier source exemple
│   │   ├── readme.txt
│   │   ├── config.json
│   │   ├── cache/
│   │   ├── subdir1/
│   │   └── subdir2/
│   │
│   ├── backup/                     # Archives créées
│   │   ├── FULL/                   # Archives complètes
│   │   │   ├── full_*.tar.gz
│   │   │   └── full_*.md5
│   │   ├── INC/                    # Archives incrémentales
│   │   │   ├── inc_*.tar.gz
│   │   │   └── inc_*.md5
│   │   └── DIFF/                   # Archives différentielles
│   │       ├── diff_*.tar.gz
│   │       └── diff_*.md5
│   │
│   └── logs/
│       ├── backup_YYYY-MM-DD.log   # Logs consolidés par jour
│       ├── restore_YYYY-MM-DD.log
│       ├── upload_YYYY-MM-DD.log
│       └── download_YYYY-MM-DD.log
│
├── serv/
│   ├── backup-server/              # Serveur Flask
│   │   ├── app.py                  # Application Flask (5000)
│   │   ├── requirements.txt        # Dépendances Python
│   │   └── remote_backups/         # Backups reçus du serveur
│   │       ├── FULL/
│   │       ├── INC/
│   │       └── DIFF/
│   │
│   └── start-server.sh             # Script pour démarrer serveur
│
├── demo.sh                         # Démonstration complète
├── README.md                       # Ce fichier
├── USAGE_GUIDE.md                  # Guide d'utilisation détaillé
└── ARCHITECTURE.sh                 # Notes d'architecture
```

---

## 🔧 Scripts Principaux

### `backup.sh` - Création de Backups
Crée des archives tar.gz compressées avec métadonnées JSON.

**Usage :**
```bash
./backup.sh --profile <nom> --type <type>
```

**Types disponibles :**
- `full` : Backup complet
- `incremental` : Depuis dernier FULL
- `diff` : Différences depuis dernier FULL

**Exemples :**
```bash
./backup.sh --profile document --type full
./backup.sh --profile document --type incremental
./backup.sh --profile document --type diff
```

---

### `restore.sh` - Restauration de Fichiers
Restaure depuis les archives (complet ou sélectif).

**Usage :**
```bash
./restore.sh --profile <nom> [--file <fichier>] [--dry-run]
```

**Exemples :**
```bash
./restore.sh --profile document                    # Restauration complète
./restore.sh --profile document --file readme.txt  # Fichier spécifique
./restore.sh --profile document --dry-run          # Mode test
```

**Recherche intelligente :**
- Cherche le fichier par nom dans toutes les archives
- Supporte chemins partiels ou complets
- Exemple : `--file data.txt` trouve aussi `subdir/data.txt`

---

### `upload.sh` - Envoi au Serveur
Télécharge les archives vers le serveur Flask distant.

**Usage :**
```bash
./upload.sh [full|incremental|diff]
```

**Exemples :**
```bash
./upload.sh full              # Upload archives FULL
./upload.sh incremental       # Upload archives INC
./upload.sh                   # Upload tous les types
SERVER_URL=http://192.168.1.100:5000 ./upload.sh
```

---

### `verify_sync.sh` - Vérification de Synchronisation
Compare les backups locaux avec ceux du serveur distant.

**Usage :**
```bash
./verify_sync.sh [--stats] [--report]
```

**Exemples :**
```bash
./verify_sync.sh                    # Rapport synthétique
./verify_sync.sh --stats            # Statistiques serveur
./verify_sync.sh --report           # Rapport détaillé
```

---

### `clear_backups.sh` - Nettoyage Local
Supprime tous les backups locaux (avec confirmation).

**Usage :**
```bash
./clear_backups.sh
```

---

### `clear_remote_backups.sh` - Nettoyage Serveur
Supprime tous les backups sur le serveur distant (avec confirmation).

**Usage :**
```bash
./clear_remote_backups.sh
```

---

### `download.sh` - Téléchargement depuis Serveur
Récupère les archives depuis le serveur distant.

**Usage :**
```bash
./download.sh [full|incremental|diff]
```

**Exemples :**
```bash
./download.sh full           # Télécharge archives FULL
./download.sh                # Télécharge tous les types
SERVER_URL=http://192.168.1.100:5000 ./download.sh
```

---

## 🚀 Démarrage Rapide

### 1. Préparation de l'environnement
```bash
cd backup-system
chmod +x *.sh lib/*.sh
mkdir -p document
echo "Test content" > document/readme.txt
```

### 2. Créer des backups
```bash
# Backup FULL (premier)
./backup.sh --profile document --type full

# Modifier un fichier
echo "New data" >> document/readme.txt

# Backup INCREMENTAL
./backup.sh --profile document --type incremental

# Backup DIFFERENTIAL
./backup.sh --profile document --type diff
```

### 3. Restaurer les données
```bash
# Restauration complète
./restore.sh --profile document

# Restauration sélective
./restore.sh --profile document --file readme.txt

# Mode test (dry-run)
./restore.sh --profile document --dry-run
```

### 4. Synchroniser avec serveur (optionnel)
```bash
# Terminal 1 : Lancer le serveur
cd ..
./start-server.sh

# Terminal 2 : Uploader les backups
cd backup-system
./upload.sh full
./upload.sh incremental

# Vérifier la synchronisation
./verify_sync.sh
./verify_sync.sh --stats
```

### 5. Lancer la démonstration complète
```bash
./demo.sh
```

---

## 📚 Bibliothèques Utilitaires

### `lib/utils.sh`

Fournit les fonctions partagées par tous les scripts :

| Fonction | Description |
|----------|-------------|
| `init_logs(script_name)` | Initialise le fichier log du jour |
| `log(level, message)` | Écrit dans console + fichier (COLOR) |
| `log_session_start()` | Marque le début d'une session |
| `mkdir_safe(dir1, dir2...)` | Crée dossiers de manière sûre |
| `rm_safe(file1, file2...)` | Supprime fichiers de manière sûre |
| `get_config(profile, key)` | Lit paramètres YAML |
| `generate_metadata(archive, profile, type)` | Crée metadonnées JSON |
| `show_storage_state(dst_dir)` | Affiche état du stockage |
| `verify_checksum(archive)` | Vérifie intégrité MD5 |
| `check_tar_contents(archive)` | Liste contenu archive |
| `find_in_archive(archive, filename)` | Cherche fichier dans archive |

### `lib/usage.sh`

Fonctions de configuration YAML simple :

| Fonction | Description |
|----------|-------------|
| `get_config(profile, key)` | Lit clé du profil YAML |

---

## 📊 Système de Logs

### Organisation des Logs

Les logs sont organisés **par jour** et **par script** :

```
logs/
├── backup_2025-11-25.log       ← Tous les backups du 25 nov
├── restore_2025-11-25.log      ← Toutes les restaurations
├── upload_2025-11-25.log       ← Uploads vers serveur
├── download_2025-11-25.log     ← Downloads depuis serveur
└── verify_sync_2025-11-25.log  ← Vérifications sync
```

**Rotation automatique :** À minuit, un nouveau fichier est créé pour la journée.

### Format des Logs

```
═══════════════════════════════════════════════════════════
[SESSION] 2025-11-25 14:32:45 - Nouvelle session
═══════════════════════════════════════════════════════════
[INFO] 2025-11-25 14:32:45 - Préparation du backup FULL
[INFO] 2025-11-25 14:32:46 - Compression en cours...
[SUCCESS] 2025-11-25 14:32:48 - Backup FULL créé : 2.4M
[INFO] 2025-11-25 14:32:48 - Métadonnées générées
[SUCCESS] 2025-11-25 14:32:48 - Session terminée
```

### Niveaux de Log

| Niveau | Couleur | Usage |
|--------|---------|-------|
| `[INFO]` | Bleu | Informations générales |
| `[WARN]` | Jaune | Avertissements |
| `[ERROR]` | Rouge | Erreurs |
| `[SUCCESS]` | Vert | Opérations réussies |
| `[SESSION]` | Blanc | Début/fin de session |

---

## ⚙️ Configuration avec Profils YAML

Les profils YAML définissent la source et la destination des backups.

### Exemple : `profiles/document.yaml`
```yaml
source: ./document
destination: ./backup
```

- `source` : Dossier contenant les fichiers à sauvegarder
- `destination` : Dossier où créer les archives (FULL/, INC/, DIFF/)

### Créer un nouveau profil

```bash
# Créer un profil pour un autre dossier
cat > profiles/autre.yaml << EOF
source: ./autre_dossier
destination: ./backup
EOF

# Utiliser le nouveau profil
./backup.sh --profile autre --type full
```

---

## 📋 Structure des Archives

### Métadonnées Générées

Chaque archive génère trois fichiers :

1. **Archive compressée** : `full_2025-11-25_14-32-45.tar.gz`
   - Contient tous les fichiers + répertoires

2. **Checksum MD5** : `full_2025-11-25_14-32-45.md5`
   - Hash pour vérifier l'intégrité
   - Format : `hash  filename`

3. **Métadonnées JSON** : `full_2025-11-25_14-32-45.json` (optionnel)
   - Informations sur l'archive (ancien format)

### Nommage des Archives

Format : `{type}_{YYYY-MM-DD}_{HH-MM-SS}.tar.gz`

Exemples :
- `full_2025-11-25_14-32-45.tar.gz` - Archive FULL
- `inc_2025-11-25_15-10-22.tar.gz` - Archive INCREMENTAL
- `diff_2025-11-25_16-45-18.tar.gz` - Archive DIFFERENTIAL

---

## ✅ Fonctionnalités Implémentées

### Système de Backup
- ✅ Backup FULL (complet)
- ✅ Backup INCREMENTAL (depuis dernier FULL)
- ✅ Backup DIFFERENTIAL (changes depuis dernier FULL)
- ✅ Compression tar.gz automatique
- ✅ Métadonnées JSON pour suivi
- ✅ Checksums MD5 pour intégrité

### Système de Restore
- ✅ Restauration complète
- ✅ Restauration sélective (fichier spécifique)
- ✅ Recherche intelligente dans archives
- ✅ Mode dry-run (test sans modifier)
- ✅ Gestion des chemins et répertoires

### Logging
- ✅ Logs consolidés par jour
- ✅ Séparation par type de script
- ✅ Sessions clairement marquées
- ✅ Colorisation console (ANSI colors)
- ✅ Horodatage précis (HH:MM:SS)
- ✅ Niveaux : INFO, WARN, ERROR, SUCCESS

### Synchronisation
- ✅ Serveur Flask pour stockage distant
- ✅ Upload vers serveur
- ✅ Download depuis serveur
- ✅ Vérification de synchronisation local/distant
- ✅ Comparaison de checksums
- ✅ Statistiques du serveur

### Configuration
- ✅ Profils YAML flexibles
- ✅ Support multi-sources
- ✅ Variables d'environnement
- ✅ Gestion sécurisée des fichiers

### Autres
- ✅ Démonstration complète (demo.sh)
- ✅ Guide d'utilisation détaillé
- ✅ Nettoyage sécurisé (avec confirmation)
- ✅ Gestion d'erreurs robuste
- ✅ Support Linux/Mac/WSL

---

## � Notes Importantes

### Sécurité
- Tous les scripts vérifient les fichiers/dossiers existants avant suppression
- Les suppressions demandent une confirmation explicite
- Utilisation de `set -euo pipefail` pour gestion d'erreurs stricte

### Performance
- Compression gzip efficient (tar.gz)
- Logs sur disque avec buffering
- Vérification MD5 optimisée

### Compatibilité
- ✅ Linux (bash 4+)
- ✅ macOS (bash 4+)
- ✅ WSL (Windows Subsystem for Linux)
- ⚠️ Nécessite : bash, tar, gzip, md5sum, grep

### Logs
- Les logs s'accumulent dans le même fichier toute la journée
- À minuit (00:00), un nouveau fichier est créé automatiquement
- Les logs sont consolidés par script (backup, restore, upload, etc.)

### Configuration
- Les profils YAML sont simples : `clé: valeur`
- Chaque profil définit source et destination
- Utilisable immédiatement après création

---

## 🚀 Commandes Git

```bash
git add .
git commit -m "restore and backup update"
git push origin main
```

---

## 🌐 Serveur Flask - Synchronisation Distante

### Démarrage du Serveur

```bash
# Démarrage simple
./start-server.sh

# Ou manuellement
cd serv/backup-server
python3 app.py
```

Le serveur démarre sur `http://localhost:5000` par défaut.

### Endpoints API

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `GET` | `/` | Informations API |
| `POST` | `/upload` | Recevoir un backup |
| `GET` | `/list` | Lister tous les backups |
| `GET` | `/list/<type>` | Lister par type (FULL/INC/DIFF) |
| `GET` | `/stats` | Statistiques du serveur |
| `POST` | `/verify` | Vérifier synchronisation |

### Exemple d'Utilisation

```bash
# Terminal 1 : Démarrer le serveur
./start-server.sh

# Terminal 2 : Créer et uploader
cd backup-system
./backup.sh --profile document --type full
./upload.sh full

# Vérifier la synchronisation
./verify_sync.sh
./verify_sync.sh --stats

# Nettoyer les backups locaux
./clear_backups.sh

# Télécharger depuis serveur
./download.sh full
```

### Structure des Données Serveur

```
serv/backup-server/remote_backups/
├── FULL/
│   ├── full_2025-11-25_14-32-45.tar.gz
│   └── full_2025-11-25_14-32-45.tar.json
├── INC/
│   ├── inc_2025-11-25_15-10-22.tar.gz
│   └── inc_2025-11-25_15-10-22.tar.json
└── DIFF/
    ├── diff_2025-11-25_16-45-18.tar.gz
    └── diff_2025-11-25_16-45-18.tar.json
```

Le serveur stocke les archives avec métadonnées JSON.

---

## � Notes Importantes

### Sécurité
- Tous les scripts vérifient les fichiers/dossiers existants avant suppression
- Les suppressions demandent une confirmation explicite
- Utilisation de `set -euo pipefail` pour gestion d'erreurs stricte

### Performance
- Compression gzip efficient (tar.gz)
- Logs sur disque avec buffering
- Vérification MD5 optimisée

### Compatibilité
- ✅ Linux (bash 4+)
- ✅ macOS (bash 4+)
- ✅ WSL (Windows Subsystem for Linux)
- ⚠️ Nécessite : bash, tar, gzip, md5sum, grep

### Logs
- Les logs s'accumulent dans le même fichier toute la journée
- À minuit (00:00), un nouveau fichier est créé automatiquement
- Les logs sont consolidés par script (backup, restore, upload, etc.)

### Configuration
- Les profils YAML sont simples : `clé: valeur`
- Chaque profil définit source et destination
- Utilisable immédiatement après création

---

## ✅ Fonctionnalités Implémentées

### Système de Backup
- ✅ Backup FULL (complet)
- ✅ Backup INCREMENTAL (depuis dernier FULL)
- ✅ Backup DIFFERENTIAL (changes depuis dernier FULL)
- ✅ Compression tar.gz automatique
- ✅ Métadonnées JSON pour suivi
- ✅ Checksums MD5 pour intégrité

### Système de Restore
- ✅ Restauration complète
- ✅ Restauration sélective (fichier spécifique)
- ✅ Recherche intelligente dans archives
- ✅ Mode dry-run (test sans modifier)
- ✅ Gestion des chemins et répertoires

### Logging
- ✅ Logs consolidés par jour
- ✅ Séparation par type de script
- ✅ Sessions clairement marquées
- ✅ Colorisation console (ANSI colors)
- ✅ Horodatage précis (HH:MM:SS)
- ✅ Niveaux : INFO, WARN, ERROR, SUCCESS

### Synchronisation
- ✅ Serveur Flask pour stockage distant
- ✅ Upload vers serveur
- ✅ Download depuis serveur
- ✅ Vérification de synchronisation local/distant
- ✅ Comparaison de checksums
- ✅ Statistiques du serveur

### Configuration
- ✅ Profils YAML flexibles
- ✅ Support multi-sources
- ✅ Variables d'environnement
- ✅ Gestion sécurisée des fichiers

### Autres
- ✅ Démonstration complète (demo.sh)
- ✅ Guide d'utilisation détaillé
- ✅ Nettoyage sécurisé (avec confirmation)
- ✅ Gestion d'erreurs robuste
- ✅ Support Linux/Mac/WSL

---

## 📖 Documentation

Consulter les fichiers de documentation :

- **[USAGE_GUIDE.md](USAGE_GUIDE.md)** - Guide d'utilisation complet avec exemples détaillés
- **[ARCHITECTURE.sh](ARCHITECTURE.sh)** - Notes d'architecture et design decisions
- **En-têtes des scripts** - Documentation intégrée dans chaque fichier bash

### Commandes Git

```bash
# Voir l'historique
git log --oneline

# Voir les modifications
git diff

# Créer une branche
git checkout -b feature/nom

# Commiter les changements
git add -A
git commit -m "Description claire de la modification"
git push origin main
```

---

## 🐛 Troubleshooting

### Le serveur ne démarre pas

```bash
# Vérifier que Python 3 est installé
python3 --version

# Vérifier les dépendances Flask
pip3 install -r serv/backup-server/requirements.txt

# Relancer le serveur avec logs
cd serv/backup-server
python3 app.py
```

### Les logs ne s'affichent pas

```bash
# Vérifier que le dossier logs existe
mkdir -p backup-system/logs

# Vérifier les permissions
chmod +x backup-system/lib/*.sh
```

### Fichiers non trouvés lors d'une restauration

```bash
# Vérifier le contenu d'une archive
tar -tzf backup/FULL/full_*.tar.gz | head

# Lister les fichiers disponibles
./backup-system/lib/utils.sh
# (voir fonction check_tar_contents)
```

---

## Auteurs
Crée par **MrKazar**, **VikusCode** et **NDesumeur**
