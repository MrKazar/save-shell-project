# 🚀 Backup Server - Flask

Serveur web pour la synchronisation et la gestion des backups distants.

## 📋 Features

✅ **Upload** de backups (FULL, INC, DIFF)
✅ **Liste** les backups reçus
✅ **Vérification** de la synchronisation local/distant
✅ **Statistiques** du serveur
✅ **Métadonnées JSON** pour chaque archive
✅ **Calcul MD5** pour l'intégrité

## 🔧 Installation

```bash
# Installer les dépendances
pip install -r requirements.txt

# Lancer le serveur
python app.py
```

Le serveur démarre sur : `http://localhost:5000`

## 📡 Endpoints API

### `GET /`
Informations sur l'API

```bash
curl http://localhost:5000/
```

### `POST /upload`
Uploader un fichier de backup

```bash
curl -F "file=@backup.tar.gz" \
     -F "type=FULL" \
     -F "profile=document" \
     http://localhost:5000/upload
```

### `GET /list`
Lister tous les backups

```bash
curl http://localhost:5000/list
```

### `GET /list/<type>`
Lister les backups d'un type spécifique

```bash
curl http://localhost:5000/list/FULL
curl http://localhost:5000/list/INC
curl http://localhost:5000/list/DIFF
```

### `POST /verify`
Vérifier la synchronisation

```bash
curl -X POST http://localhost:5000/verify \
     -H "Content-Type: application/json" \
     -d '{
       "local_backups": {
         "FULL": [{"name": "file.tar.gz", "size": 1024, "md5": "..."}],
         "INC": [],
         "DIFF": []
       }
     }'
```

### `GET /stats`
Obtenir les statistiques

```bash
curl http://localhost:5000/stats
```

## 🔄 Utilisation avec les scripts shell

### 1. Lancer le serveur

```bash
cd backup-server
python app.py
```

### 2. Uploader les backups

```bash
cd backup-system
./upload.sh document --all
```

### 3. Vérifier la synchronisation

```bash
./verify_sync.sh
```

### 4. Voir les statistiques

```bash
./verify_sync.sh --stats
```

## 📁 Structure

```
backup-server/
├── app.py                 Application Flask principale
├── requirements.txt       Dépendances Python
├── remote_backups/        Dossier de stockage des backups
│   ├── FULL/             Archives complètes
│   ├── INC/              Archives incrémentales
│   └── DIFF/             Archives différentielles
└── README.md
```

## 🛠️ Configuration

Variables d'environnement :

```bash
# URL du serveur (utilisé par les scripts shell)
export SERVER_URL="http://localhost:5000"

# Dossier local des backups (utilisé par les scripts shell)
export BACKUP_DIR="./backup"
```

## 📊 Exemple de réponse /list

```json
{
  "status": "success",
  "backups": {
    "FULL": [
      {
        "name": "full_2025-11-21_09-07-19.tar.gz",
        "size": 12288,
        "size_human": "12.0 KB",
        "modified": "2025-11-21T09:07:19",
        "md5": "a1b2c3d4e5f6..."
      }
    ],
    "INC": [],
    "DIFF": []
  },
  "total_count": 1
}
```

## ✅ Vérification de synchronisation

Le serveur compare les backups locaux et distants et rapporte :

- **Synced** : Fichiers présents et identiques (même MD5)
- **Missing on remote** : Fichiers locaux absents sur le serveur
- **Extra remote** : Fichiers distants non présents localement

## 🔒 Limitations

- Taille max d'upload : 500 MB
- Formats supportés : `.tar.gz` uniquement
- Types de backup : FULL, INC, DIFF

## 🚀 Déploiement en production

Pour déployer en production :

```bash
# Avec Gunicorn
pip install gunicorn
gunicorn -w 4 -b 0.0.0.0:5000 app:app
```

---

Créé par **MrKazar** - 2025
