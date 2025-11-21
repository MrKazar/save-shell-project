# 📦 BACKUP SYSTEM - Projet Shell

## 📋 Description

Système de sauvegarde complet en Bash avec support de trois types de backups :
  - ✅ **FULL** (complet) - Sauvegarde complète de tous les fichiers
  - ✅ **INCREMENTAL** - Sauvegarde des fichiers modifiés depuis le dernier FULL
  - ✅ **DIFFERENTIAL** - Sauvegarde des fichiers modifiés depuis le dernier FULL

### Fonctionnalités principales :
  - Compression automatique (gzip/tar.gz)
  - Métadonnées JSON pour chaque archive
  - Restauration complète ou sélective
  - Logs consolidés par jour (un fichier par type de script)
  - Gestion des sessions de backup/restauration
  - Vérification d'intégrité des archives

---

## 📁 Structure du projet

```
backup-system/
│
├── backup.sh                     Script principal pour les backups
├── restore.sh                    Script pour les restaurations
├── demo_backup.sh                Démonstration complète du système
│
├── config/
│   └── default.yaml              Configuration des profils
│
├── lib/
│   ├── utils.sh                  Fonctions utilitaires
│   └── usage.sh                  (Optionnel)
│
├── document/                     Dossier source (exemple)
├── backup/                       Dossier contenant les archives
│   ├── FULL/                     Archives complètes
│   ├── INC/                      Archives incrémentales
│   └── DIFF/                     Archives différentielles
│
├── logs/
│   ├── backup_YYYY-MM-DD.log     Logs de tous les backups
│   └── restore_YYYY-MM-DD.log    Logs de toutes les restaurations
│
└── profiles/
    └── document.yaml             Profil de configuration
```

---

## 🔧 Fichiers principaux

### `backup.sh`
Crée des archives tar.gz des dossiers source.
```bash
./backup.sh --profile document --type full
./backup.sh --profile document --type incremental
./backup.sh --profile document --type diff
```

### `restore.sh`
Restaure fichiers ou dossiers depuis les archives.
```bash
./restore.sh --profile document              # Restauration complète
./restore.sh --profile document --dry-run    # Mode test
./restore.sh --profile document --file nom   # Fichier spécifique
```

### `lib/utils.sh`
Fonctions utilitaires :
  - `init_logs(script_name)` - Initialise les logs du jour
  - `log_session_start()` - Marque une nouvelle session
  - `log(level, message)` - Écrit dans console + fichier
  - `mkdir_safe(...)` - Crée des dossiers de manière sûre
  - `rm_safe(...)` - Supprime fichiers/dossiers de manière sûre
  - `get_config(profile, key)` - Lit les profils YAML
  - `generate_metadata(...)` - Crée les métadonnées JSON
  - `show_storage_state(...)` - Affiche l'état du stockage
  - `verify_checksum(...)` - Vérifie l'intégrité

---

## ⚡ Utilisation rapide

### 1. Préparation
```bash
cd backup-system
chmod +x backup.sh restore.sh demo_backup.sh
mkdir -p document
```

### 2. Créer un backup
```bash
./backup.sh --profile document --type full        # Backup complet
./backup.sh --profile document --type incremental # Incremental
./backup.sh --profile document --type diff        # Différentiel
```

### 3. Restaurer
```bash
./restore.sh --profile document                   # Restauration complète
./restore.sh --profile document --dry-run         # Test sans modifier
./restore.sh --profile document --file fichier.txt # Fichier spécifique
```

### 4. Lancer la démo
```bash
./demo_backup.sh
```

---

## 📊 Système de logs

Les logs sont organisés **par jour** et **par type** :

```
logs/backup_2025-11-21.log      ← Tous les backups du 21 novembre
logs/restore_2025-11-21.log     ← Toutes les restaurations du 21 novembre
```

### Structure d'un log

```
═══════════════════════════════════════════════════════════
[SESSION] 2025-11-21 09:07:19 - Nouvelle session
═══════════════════════════════════════════════════════════
[INFO] 2025-11-21 09:07:19 - Démarrage du backup...
[SUCCESS] 2025-11-21 09:07:19 - Backup FULL terminé...

═══════════════════════════════════════════════════════════
[SESSION] 2025-11-21 10:15:42 - Nouvelle session
═══════════════════════════════════════════════════════════
[INFO] 2025-11-21 10:15:42 - Démarrage du backup...
```

### Niveaux de log
- `[INFO]` - Informations générales
- `[WARN]` - Avertissements
- `[ERROR]` - Erreurs (affichées en rouge)
- `[SUCCESS]` - Opérations réussies
- `[SESSION]` - Marque le début d'une nouvelle session

---

## 📋 Exemple de profil YAML

`profiles/document.yaml` :
```yaml
source: ./document
destination: ./backup
```

Cela signifie :
- Les fichiers à sauvegarder se trouvent dans `./document`
- Les archives sont créées dans `./backup/[FULL|INC|DIFF]`

---

## 🎯 Métadonnées des archives

Chaque archive génère un fichier `.meta.json` :

```json
{
  "archive": "./backup/FULL/full_2025-11-21_09-07-19.tar.gz",
  "profile": "document",
  "type": "full",
  "size": "12K",
  "files": 5,
  "date": "2025-11-21 09:07:19"
}
```

---

## ✅ Features implémentées

- ✅ Backup FULL, INCREMENTAL, DIFFERENTIAL
- ✅ Logs par jour (un fichier pour backup, un pour restore)
- ✅ Sessions clairement séparées dans les logs
- ✅ Métadonnées JSON pour chaque archive
- ✅ Vérification d'intégrité des archives
- ✅ Restauration complète avec gestion des dossiers
- ✅ Restauration sélective de fichiers
- ✅ Mode dry-run pour les restaurations
- ✅ Gestion des profils YAML
- ✅ Horodatage précis des opérations
- ✅ Couleurs dans la console
- ✅ Gestion sécurisée des fichiers

---

## 📝 Notes importantes

- Les logs s'accumulent dans le même fichier toute la journée
- À minuit (changement de jour), un nouveau fichier de log est créé
- Les snapshots (`snap_*.dat`) permettent de tracer le dernier backup
- Les métadonnées JSON facilitent le suivi des archives
- Le système est entièrement portable (Linux/Mac/WSL)

---

## 🚀 Commandes Git

```bash
git add .
git commit -m "restore and backup update"
git push origin main
```

---

Créé par **MrKazar** - 2025
