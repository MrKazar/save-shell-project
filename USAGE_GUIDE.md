# Guide d’utilisation 
## 1. Installation

```bash
cd backup-system
chmod +x *.sh
sudo apt install python3 python3-flask curl jq
```

## 2. Création de sauvegardes

### Backup complet
```bash
./backup.sh --profile document --type full
```

### Backup incrémental
```bash
./backup.sh --profile document --type incremental
```

### Backup différentiel
```bash
./backup.sh --profile document --type diff
```

## 3. Lancer le serveur

```bash
./start-server.sh
```

## 4. Envoyer les sauvegardes vers le serveur

```bash
./upload.sh document --all
```

## 5. Télécharger les sauvegardes depuis le serveur

```bash
./download.sh document --all
```

## 6. Vérifier la synchronisation

```bash
./verify_sync.sh
```

## 7. Restaurer les données

### Restauration complète
```bash
./restore.sh --profile document
```

### Restauration d’un fichier
```bash
./restore.sh --profile document --file nom_du_fichier
```

## 8. Nettoyer

### Nettoyer les sauvegardes locales
```bash
./clear_backups.sh
```

### Nettoyer les sauvegardes du serveur
```bash
./clear_remote_backups.sh
```

## 9. Démonstration complète

```bash
./demo.sh
```

## Auteurs
**MrKazar**, **VikusCode** et **NDesumeur**

