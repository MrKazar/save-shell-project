Backup System - Projet Shell
============================

Description
-----------
Système de sauvegarde automatisé en shell avec support des fonctionnalités suivantes :
- Backup complet, incrémental et différentiel
- Compression automatique des archives (tar.gz)
- Calcul et affichage du pourcentage d'occupation des dossiers (backup/ et document/)
- Gestion des versions et rotation
- Restauration complète ou sélective
- Logs détaillés des opérations

Structure du projet
------------------

backup-system/
├── backup.sh             : Script principal pour effectuer les backups
├── restore.sh            : Script pour restaurer des fichiers ou dossiers
├── config/               : Contient les profils YAML
│   ├── backup.yaml
│   └── document.yaml
├── document/             : Dossier contenant les fichiers à sauvegarder
├── backup/               : Dossier contenant les fichiers à sauvegarder pour le profil backup
├── backups/              : Destination des archives
│   ├── backup/
│   └── document/
├── lib/                  : Modules utilitaires
│   ├── utils.sh          : Fonctions utilitaires et logs
│   └── usage.sh          : Calcul du % d'occupation et renommage automatique
└── logs/                 : Contient les logs des backups

Utilité des fichiers principaux
-------------------------------

backup.sh        : Script principal pour créer les sauvegardes (full, incrémental, différentiel)
restore.sh       : Script pour restaurer des fichiers ou dossiers depuis les backups existants
lib/utils.sh     : Fonctions utilitaires : logging, parsing YAML simple, etc.
lib/usage.sh     : Calcul automatique du pourcentage d’occupation et renommage [XX%] dossier
config/*.yaml    : Profils de configuration (source, destination, compression, retention)
document/        : Contient les fichiers à sauvegarder pour le profil document
backup/          : Contient les fichiers à sauvegarder pour le profil backup
backups/*/       : Contient les archives créées après chaque backup
logs/            : Contient les logs des backups pour suivi et debug

Commandes à utiliser
-------------------

1. Créer les dossiers nécessaires (si pas déjà fait)
   mkdir -p backup document backups/backup backups/document logs

2. Ajouter des fichiers de test
   echo "Fichier test backup" > backup/test1.txt
   echo "Fichier test document" > document/test2.txt

3. Rendre les scripts exécutables
   chmod +x backup.sh restore.sh

4. Lancer un backup complet
   ./backup.sh --profile backup --type full
   ./backup.sh --profile document --type full

5. Restaurer un fichier spécifique
   ./restore.sh --profile document --file test2.txt

6. Restaurer une archive complète
   ./restore.sh --profile backup

Notes
-----

- Le pourcentage [XX%] dans le nom des dossiers est mis à jour automatiquement après chaque backup.
- Les backups incrémental et différentiel sont encore à compléter si nécessaire.
- Les logs sont générés dans logs/backup.log et contiennent toutes les opérations effectuées.
