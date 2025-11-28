#!/bin/bash
################################################################################
# ARCHITECTURE.SH - Documentation de l'Architecture Système
################################################################################
#
# DESCRIPTION :
#   Document explicatif montrant :
#   - Flux de données du système complet
#   - Architecture des composants
#   - Types de backups et leur utilisation
#   - Workflow local-serveur
#   - Gestion des logs et métadonnées
#
# USAGE :
#   ./ARCHITECTURE.sh       # Affiche la documentation
#   ./ARCHITECTURE.sh | less # Avec pagination
#
# CONTENU :
#   - Flux de données (backup → upload → serveur → restore)
#   - Structure des composants locaux et distants
#   - Stratégies de backup (FULL/INC/DIFF)
#   - Gestion des sessions et logs
#   - Métadonnées des archives
#
# SECTIONS :
#   1. Flux de données complet
#   2. Composants du système
#   3. Types de backups
#   4. Structure des logs
#   5. Métadonnées et checksums
#   6. Configuration avec profils YAML
#   7. Sécurité et intégrité
#
# FICHIERS RÉFÉRENCÉS :
#   - backup-system/backup.sh
#   - backup-system/restore.sh
#   - backup-system/upload.sh
#   - backup-system/verify_sync.sh
#   - backup-system/lib/utils.sh
#   - serv/backup-server/app.py
#   - backup-system/profiles/*.yaml
#
# POUR PLUS D'INFOS :
#   Voir README.md pour vue complète
#   Voir USAGE_GUIDE.md pour guide pratique
#   Voir en-têtes des scripts bash pour documentation détaillée
#
################################################################################

cat << 'EOF'

================================================================================
                    BACKUP SYSTEM - ARCHITECTURE COMPLÈTE
================================================================================

┌─────────────────────────────────────────────────────────────────────────────┐
│                          FLUX DE DONNÉES                                    │
└─────────────────────────────────────────────────────────────────────────────┘

1. CRÉER LES BACKUPS (local)
   ┌──────────────────────────────────────────────┐
   │  document/                                    │
   │  ├── file1.txt                               │
   │  ├── file2.txt                               │
   │  └── subdir/file3.txt                        │
   └──────────────────────────────────────────────┘
                        ↓
                   backup.sh
                        ↓
   ┌──────────────────────────────────────────────┐
   │  backup/                                      │
   │  ├── FULL/full_*.tar.gz                      │
   │  ├── INC/inc_*.tar.gz                        │
   │  └── DIFF/diff_*.tar.gz                      │
   └──────────────────────────────────────────────┘


2. UPLOADER LES BACKUPS (vers le serveur)
   ┌──────────────────────────────────────────────┐
   │  backup/FULL/full_*.tar.gz                   │
   │  backup/INC/inc_*.tar.gz                     │
   │  backup/DIFF/diff_*.tar.gz                   │
   └──────────────────────────────────────────────┘
                        ↓
                   upload.sh
                   (HTTP POST)
                        ↓
   ┌──────────────────────────────────────────────┐
   │  SERVEUR FLASK (http://localhost:5000)       │
   │  app.py                                       │
   └──────────────────────────────────────────────┘
                        ↓
   ┌──────────────────────────────────────────────┐
   │  remote_backups/                              │
   │  ├── FULL/full_*.tar.gz + .json              │
   │  ├── INC/inc_*.tar.gz + .json                │
   │  └── DIFF/diff_*.tar.gz + .json              │
   └──────────────────────────────────────────────┘


3. VÉRIFIER LA SYNCHRONISATION
   ┌──────────────────────────────────────────────┐
   │  backup/ (LOCAL)                              │
   │  vs                                           │
   │  SERVEUR (DISTANT)                            │
   └──────────────────────────────────────────────┘
                        ↓
                  verify_sync.sh
                        ↓
   ┌──────────────────────────────────────────────┐
   │  Rapport :                                    │
   │  - FULL : 1/1 synced                          │
   │  - INC  : 1/1 synced                          │
   │  - DIFF : 1/1 synced                          │
   │  → SYNCHRONIZED ✓                             │
   └──────────────────────────────────────────────┘


================================================================================
                          COMPOSANTS DU SYSTÈME
================================================================================

LOCAL (backup-system/)
├── backup.sh              → Crée les archives
├── restore.sh             → Restaure depuis une archive
├── upload.sh              → Envoie au serveur
├── verify_sync.sh         → Vérifie la synchro
├── lib/utils.sh           → Fonctions utilitaires
├── profiles/document.yaml → Configuration
├── logs/                  → Logs (backup_YYYY-MM-DD.log, restore_YYYY-MM-DD.log)
└── backup/
    ├── FULL/              → Archives complètes
    ├── INC/               → Archives incrémentales
    └── DIFF/              → Archives différentielles

SERVEUR (serv/backup-server/)
├── app.py                 → Application Flask
├── requirements.txt       → Dépendances (Flask, Werkzeug)
└── remote_backups/
    ├── FULL/              → Backups reçus (complets)
    ├── INC/               → Backups reçus (incrémentaux)
    └── DIFF/              → Backups reçus (différentiels)

AUTRES
├── start-server.sh        → Script de démarrage du serveur
├── USAGE_GUIDE.md         → Guide d'utilisation complet
└── README.md              → Ce fichier


================================================================================
                           COMMANDES PRINCIPALES
================================================================================

DÉMARRAGE DU SERVEUR :
  ./start-server.sh
  ou
  cd serv/backup-server && python3 app.py

CRÉATION DE BACKUPS :
  ./backup-system/backup.sh --profile document --type full
  ./backup-system/backup.sh --profile document --type incremental
  ./backup-system/backup.sh --profile document --type diff

UPLOAD VERS LE SERVEUR :
  ./backup-system/upload.sh document --all

VÉRIFICATION DE LA SYNCHRONISATION :
  ./backup-system/verify_sync.sh
  ./backup-system/verify_sync.sh --stats

RESTAURATION :
  ./backup-system/restore.sh --profile document
  ./backup-system/restore.sh --profile document --dry-run
  ./backup-system/restore.sh --profile document --file filename.txt


================================================================================
                              WORKFLOW COMPLET
================================================================================

┌─────────────────────────────────────────────────────────────────────────────┐
│ TERMINAL 1 : Lancer le serveur                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│ $ ./start-server.sh                                                         │
│ [INFO] Vérification de Flask... OK                                          │
│ [INFO] Création des répertoires... OK                                       │
│ [INFO] Démarrage du serveur sur http://localhost:5000                       │
│ → Serveur actif et en écoute                                                │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ TERMINAL 2 : Créer et uploader les backups                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│ $ cd backup-system                                                          │
│ $ ./backup.sh --profile document --type full                                │
│ [SUCCESS] Backup FULL terminé : full_2025-11-21_10-00-01.tar.gz             │
│                                                                             │
│ $ ./backup.sh --profile document --type incremental                         │
│ [SUCCESS] Backup INCREMENTAL terminé : inc_2025-11-21_10-00-05.tar.gz       │
│                                                                             │
│ $ ./upload.sh document --all                                                │
│ [SUCCESS] Upload réussi : full_2025-11-21_10-00-01.tar.gz                   │
│ [SUCCESS] Upload réussi : inc_2025-11-21_10-00-05.tar.gz                    │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ TERMINAL 2 : Vérifier la synchronisation                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│ $ ./verify_sync.sh                                                          │
│ [INFO] Vérification de la synchronisation...                                │
│                                                                             │
│ FULL                                                                        │
│   Local:  1 backups                                                         │
│   Remote: 1 backups                                                         │
│   Synced: 1 fichiers                                                        │
│                                                                             │
│ [SUCCESS] Synchronisation OK ✓                                              │
└─────────────────────────────────────────────────────────────────────────────┘


================================================================================
                            INTÉGRATION AVEC CRON
================================================================================

Ajouter au fichier crontab (crontab -e) :

# Sauvegarde quotidienne à 2h du matin
0 2 * * * cd /chemin/vers/backup-system && ./backup.sh --profile document --type full

# Upload à 3h du matin
0 3 * * * cd /chemin/vers/backup-system && ./upload.sh document --all

# Vérification de la synchronisation à 4h du matin
0 4 * * * cd /chemin/vers/backup-system && ./verify_sync.sh >> /tmp/backup_verify.log 2>&1


================================================================================
                              FICHIERS GÉNÉRÉS
================================================================================

LOGS :
  backup-system/logs/backup_2025-11-21.log      → Tous les backups du jour
  backup-system/logs/restore_2025-11-21.log     → Toutes les restaurations

SNAPSHOTS :
  backup-system/snap_document.dat               → Dernier backup FULL (pour INCR/DIFF)

MÉTADONNÉES (sur le serveur) :
  serv/backup-server/remote_backups/FULL/*.json → Métadonnées des archives

BACKUPS LOCAUX :
  backup-system/backup/FULL/*.tar.gz            → Archives complètes
  backup-system/backup/INC/*.tar.gz             → Archives incrémentales
  backup-system/backup/DIFF/*.tar.gz            → Archives différentielles

BACKUPS DISTANTS :
  serv/backup-server/remote_backups/FULL/*      → Copies sur le serveur
  serv/backup-server/remote_backups/INC/*
  serv/backup-server/remote_backups/DIFF/*


================================================================================
                            POINTS DE CONTRÔLE
================================================================================

✓ Les backups sont-ils créés localement ?
  $ ls -la backup-system/backup/FULL/

✓ Le serveur est-il en cours d'exécution ?
  $ curl http://localhost:5000/

✓ Les fichiers sont-ils uploadés ?
  $ ls -la serv/backup-server/remote_backups/FULL/

✓ La synchronisation est-elle correcte ?
  $ ./backup-system/verify_sync.sh

✓ Quelle est la taille totale ?
  $ ./backup-system/verify_sync.sh --stats


================================================================================
                         DÉPANNAGE ET ERREURS COURANTES
================================================================================

Erreur : "Flask not found"
→ Installer : pip3 install Flask Werkzeug

Erreur : "Connection refused"
→ Vérifier que le serveur est lancé : ./start-server.sh

Erreur : "Permission denied"
→ Rendre exécutable : chmod +x *.sh

Erreur : "File already exists on remote"
→ Les fichiers avec le même nom écrasent les anciens (comportement normal)

Erreur : "Out of sync"
→ L'un des fichiers locaux n'a pas été uploadé
→ Vérifier avec : ./verify_sync.sh


================================================================================
                              STATISTIQUES
================================================================================

Format des métadonnées JSON :
{
  "filename": "full_2025-11-21_10-00-01.tar.gz",
  "type": "FULL",
  "profile": "document",
  "size": 12288,
  "files": 5,
  "md5": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6",
  "uploaded_at": "2025-11-21T10:00:01"
}

Exemple de statistiques serveur :
{
  "FULL": {"count": 1, "size": 12288, "size_human": "12.0 KB"},
  "INC":  {"count": 1, "size": 5120,  "size_human": "5.0 KB"},
  "DIFF": {"count": 1, "size": 8192,  "size_human": "8.0 KB"},
  "total": {"files": 3, "size": 25600, "size_human": "25.0 KB"}
}


================================================================================
                          SÉCURITÉ ET BONNES PRATIQUES
================================================================================

⚠️ À NOTER :
- Le serveur accepte les fichiers jusqu'à 500 MB
- Les archives doivent être en .tar.gz
- Les MD5 sont calculés pour vérifier l'intégrité
- Les fichiers uploadés écrasent les anciens avec le même nom

✅ RECOMMANDATIONS :
- Inclure un horodatage dans le nom des archives (déjà fait par défaut)
- Utiliser des profils pour organiser les backups
- Vérifier régulièrement la synchronisation
- Garder les logs pour l'audit
- Tester les restaurations régulièrement


================================================================================
                            QUESTIONS FRÉQUENTES
================================================================================

Q: Peut-on avoir plusieurs serveurs ?
R: Oui, configurer SERVER_URL différemment pour chaque

Q: Les backups sont-ils compressés ?
R: Oui, avec gzip (format .tar.gz)

Q: Peut-on restaurer manuellement ?
R: Oui, en utilisant : tar -xzf archive.tar.gz

Q: Quel est l'espace nécessaire ?
R: Au minimum : local + 1x (taille des données) pour le serveur

Q: Peut-on restaurer un seul fichier ?
R: Oui, avec : ./restore.sh --profile doc --file filename

Q: Comment sécuriser le serveur ?
R: Ajouter une authentification dans app.py (à implémenter)

Q: Peut-on déployer le serveur en production ?
R: Oui, avec Gunicorn : gunicorn -w 4 -b 0.0.0.0:5000 app:app


================================================================================
                              LIENS UTILES
================================================================================

Documentation locale :
  - README.md                    → Vue d'ensemble du projet
  - USAGE_GUIDE.md              → Guide d'utilisation détaillé
  - serv/backup-server/README.md → Documentation du serveur
  - backup-system/profiles/document.yaml → Exemple de configuration

Fichiers importants :
  - backup-system/backup.sh     → Script de création de backups
  - backup-system/upload.sh     → Script d'upload
  - backup-system/verify_sync.sh → Script de vérification
  - serv/backup-server/app.py   → Application Flask


================================================================================
                    FIN DE L'ARCHITECTURE ET DU FLUX
================================================================================

Pour commencer : ./start-server.sh

EOF
