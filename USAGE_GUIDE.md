# 📚 Guide d'utilisation - Système de Backup avec Synchronisation

## 🎯 Objectif global

Ce système permet de :
1. **Créer des backups** (FULL, INCREMENTAL, DIFFERENTIAL)
2. **Uploader les backups** vers un serveur web distant
3. **Vérifier la synchronisation** entre vos fichiers locaux et distants

---

## 📁 Structure du projet

```
save-shell-project/
├── backup-system/              Scripts de backup/restore shell
│   ├── backup.sh               Créer des backups
│   ├── restore.sh              Restaurer depuis une archive
│   ├── upload.sh               Uploader vers le serveur
│   ├── verify_sync.sh          Vérifier la synchronisation
│   ├── demo_backup.sh          Démonstration complète
│   ├── profiles/               Profils YAML
│   ├── document/               Dossier source (exemple)
│   ├── backup/                 Archives locales
│   │   ├── FULL/
│   │   ├── INC/
│   │   └── DIFF/
│   └── logs/                   Logs des opérations

└── serv/backup-server/         Serveur web Python Flask
    ├── app.py                  Application principale
    ├── requirements.txt        Dépendances Python
    ├── remote_backups/         Backups reçus du serveur
    │   ├── FULL/
    │   ├── INC/
    │   └── DIFF/
    └── README.md
```

---

## 🚀 Installation

### Étape 1 : Préparer l'environnement

```bash
cd backup-system
chmod +x backup.sh restore.sh upload.sh verify_sync.sh demo_backup.sh
mkdir -p document logs
```

### Étape 2 : Installer Python (serveur)

**Ubuntu/Debian :**
```bash
sudo apt update
sudo apt install python3 python3-pip
```

**macOS :**
```bash
brew install python3
```

### Étape 3 : Installer Flask

```bash
cd serv/backup-server
pip3 install -r requirements.txt
```

---

## 📝 Utilisation

### PARTIE 1 : Créer des backups (local)

#### 1a. Ajouter des fichiers à sauvegarder

```bash
cd backup-system
echo "Important document" > document/file1.txt
echo "Another file" > document/file2.txt
mkdir -p document/subdir
echo "Nested file" > document/subdir/file3.txt
```

#### 1b. Créer un backup complet

```bash
./backup.sh --profile document --type full
```

**Résultat :**
```
[INFO]  2025-11-21 10:00:00 - Démarrage du backup...
[SUCCESS] 2025-11-21 10:00:01 - Backup FULL terminé : full_2025-11-21_10-00-01.tar.gz
--- État du stockage ---
FULL : 1 archives, 12K
```

#### 1c. Créer un backup incrémental

Modifier un fichier et créer un backup incrémental :

```bash
echo "Updated content" > document/file1.txt
./backup.sh --profile document --type incremental
```

#### 1d. Créer un backup différentiel

```bash
echo "New file" > document/newfile.txt
./backup.sh --profile document --type diff
```

### PARTIE 2 : Lancer le serveur web

```bash
cd serv/backup-server
python3 app.py
```

**Sortie :**
```
============================================================
Backup Server - Flask Application
============================================================
Remote backups directory: .../remote_backups
Starting server on http://localhost:5000
============================================================
```

Le serveur est maintenant actif sur `http://localhost:5000`

### PARTIE 3 : Uploader les backups

**Dans un autre terminal :**

```bash
cd backup-system

# Uploader tous les backups
./upload.sh document --all
```

**Résultat :**
```
[SUCCESS] Serveur disponible : http://localhost:5000
[INFO]  Upload de FULL : full_2025-11-21_10-00-01.tar.gz
[SUCCESS] Upload réussi : full_2025-11-21_10-00-01.tar.gz
[INFO]  Résumé : 3/3 fichiers uploadés
```

### PARTIE 4 : Vérifier la synchronisation

#### 4a. Vérification rapide

```bash
./verify_sync.sh
```

**Résultat :**
```
=========== Backup Sync Verification ===========

[INFO]  Vérification de la synchronisation...

FULL
  Local:  1 backups
  Remote: 1 backups
  Synced: 1 fichiers

INC
  Local:  1 backups
  Remote: 1 backups
  Synced: 1 fichiers

DIFF
  Local:  1 backups
  Remote: 1 backups
  Synced: 1 fichiers

[SUCCESS] Synchronisation OK ✓
```

#### 4b. Afficher les statistiques du serveur

```bash
./verify_sync.sh --stats
```

**Résultat :**
```
[INFO]  Statistiques du serveur...

FULL
  Fichiers: 1
  Taille:   12.0 KB

INC
  Fichiers: 1
  Taille:   12.0 KB

DIFF
  Fichiers: 1
  Taille:   12.0 KB

Total: 3 fichiers, 36.0 KB
```

---

## 🔍 Vérification API du serveur

### Tester l'API directement

#### Lister tous les backups

```bash
curl http://localhost:5000/list | jq .
```

#### Lister les backups FULL

```bash
curl http://localhost:5000/list/FULL | jq .
```

#### Obtenir les stats

```bash
curl http://localhost:5000/stats | jq .
```

---

## 📊 Logs et Debugging

### Regarder les logs des backups

```bash
tail -f backup-system/logs/backup_2025-11-21.log
```

### Regarder les logs des restaurations

```bash
tail -f backup-system/logs/restore_2025-11-21.log
```

### Afficher les fichiers uploadés sur le serveur

```bash
ls -lah serv/backup-server/remote_backups/FULL/
ls -lah serv/backup-server/remote_backups/INC/
ls -lah serv/backup-server/remote_backups/DIFF/
```

---

## ⚡ Workflow complet en 5 étapes

```bash
# 1. Terminal 1 - Lancer le serveur
cd serv/backup-server
python3 app.py

# 2. Terminal 2 - Créer des backups
cd backup-system
./backup.sh --profile document --type full

# 3. Terminal 2 - Uploader les backups
./upload.sh document --all

# 4. Terminal 2 - Vérifier la synchro
./verify_sync.sh

# 5. Terminal 2 - Voir les statistiques
./verify_sync.sh --stats
```

---

## 🔧 Configuration

### Changer l'URL du serveur

```bash
# Pour les scripts shell
export SERVER_URL="http://192.168.1.100:5000"

# Ou éditer directement dans les scripts
```

### Changer le dossier des backups

```bash
export BACKUP_DIR="/chemin/vers/backups"
```

---

## 🎯 Cas d'usage

### Cas 1 : Sauvegarde quotidienne automatique

```bash
# Ajouter au crontab
0 2 * * * cd /home/user/backup-system && ./backup.sh --profile document --type full
0 3 * * * cd /home/user/backup-system && ./upload.sh document --all
0 4 * * * cd /home/user/backup-system && ./verify_sync.sh
```

### Cas 2 : Restaurer un fichier

```bash
cd backup-system
./restore.sh --profile document --file document/file1.txt --dry-run  # Test
./restore.sh --profile document --file document/file1.txt           # Réel
```

### Cas 3 : Vérifier l'intégrité

Le serveur calcule automatiquement les hash MD5 pour chaque fichier, permettant de vérifier l'intégrité.

---

## 📖 Fichiers importants

- **`backup.sh`** : Crée les archives (FULL/INC/DIFF)
- **`restore.sh`** : Restaure depuis les archives
- **`upload.sh`** : Envoie les archives au serveur
- **`verify_sync.sh`** : Vérifie la synchronisation
- **`app.py`** : Serveur Flask qui reçoit les archives
- **`profiles/document.yaml`** : Configuration du profil

---

## ✅ Checklist d'utilisation

- [ ] Créer des fichiers à sauvegarder
- [ ] Lancer le serveur Flask (`python3 app.py`)
- [ ] Créer un backup FULL (`backup.sh ... --type full`)
- [ ] Uploader les backups (`upload.sh ... --all`)
- [ ] Vérifier la synchronisation (`verify_sync.sh`)
- [ ] Vérifier les logs (`tail logs/backup_*.log`)
- [ ] Consulter les statistiques (`verify_sync.sh --stats`)

---

## 🐛 Troubleshooting

### Le serveur ne démarre pas

```bash
# Vérifier que Flask est installé
python3 -c "import flask; print(flask.__version__)"

# Sinon installer
pip3 install Flask Werkzeug
```

### L'upload échoue

```bash
# Vérifier que le serveur écoute
curl http://localhost:5000/

# Vérifier les permissions
chmod 755 backup-system/upload.sh
```

### Les fichiers ne sont pas synchronisés

```bash
# Vérifier les logs du serveur
# Vérifier les métadonnées JSON
ls -la serv/backup-server/remote_backups/FULL/*.json

# Vérifier les hash MD5
cat serv/backup-server/remote_backups/FULL/*.json | jq '.md5'
```

---

Créé par **MrKazar** - 2025
