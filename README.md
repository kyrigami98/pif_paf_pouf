# pif_paf_pouf

PifPafPouf – nom décalé et ludique, basé sur des onomatopées comiques (« pif », « paf », « pouf »). Il évoque une ambiance cartoon et amusante pour les duels, idéal pour un public familial ou les plus jeunes.

🔧 Fonctionnalités principales à implémenter :
Détection de proximité (5 mètres)

Utilise Bluetooth Low Energy (BLE) ou Nearby (Google’s Nearby Connections API) pour détecter les téléphones proches.

Flutter plugins possibles :

flutter_blue_plus

nearby_connections

Déclenchement du “tchin” / cogner les téléphones

Capteurs :

Accéléromètre + gyroscope pour détecter le mouvement synchrone d’un “tchin”.

Plugin : sensors_plus

Bonus : petite animation ou vibration lors de la détection du “cogne”.

Connexion entre appareils

Une fois la proximité détectée, établir une session Firebase (Realtime Database ou Firestore).

Chaque utilisateur rejoint une "room" automatiquement créée à la connexion.

Gameplay Pierre-Papier-Ciseaux

Interface simple : trois boutons avec animations stylisées.

Une fois les choix envoyés, Firestore synchronise les coups et affiche le gagnant.

Système de groupe via code (alternative en ligne)

Génération de code aléatoire pour rejoindre une partie à distance.

Stockage de la room dans Firestore avec un ID de groupe partageable.

🗃️ Firebase modules nécessaires :
Authentication (anonyme) pour tracker les joueurs.

Firestore ou Realtime Database pour gérer les parties en direct.

Cloud Functions (optionnel) pour calculer le résultat et gérer des règles de jeu.

Firebase Analytics pour suivre l’utilisation et améliorer l’expérience.

🎨 UI/UX suggestions pour "PifPafPouf"
Interface légère et joyeuse avec des animations cartoon (onoma : pif, paf, pouf).

Grosse importance sur l’effet “tchin” avec des feedbacks visuels.

Matchmaking visuel amusant quand deux téléphones se connectent.

Possibilité de collectionner des “victoires” sous forme de stickers ou badges.


Structure recommandée (sans clean archi)

lib/
├── main.dart
├── app/
│   ├── app.dart             # Widget racine (MaterialApp, GoRouter, etc.)
│   └── routes.dart          # Toutes les routes centralisées
├── screens/                 # Par page principale de l'app
│   ├── home/                # Écran d’accueil
│   ├── game/                # Écran du jeu Pierre-Papier-Ciseaux
│   ├── pairing/             # Écran de détection / appairage ("tchin")
│   └── lobby/               # Attente de joueur, pré-match
├── widgets/                 # Widgets réutilisables
│   └── game_button.dart     # Exemple : bouton animé pour le choix
├── services/                # Firebase, Bluetooth, Nearby, etc.
│   ├── firebase_service.dart
│   ├── nearby_service.dart
│   └── motion_detector.dart # Pour gérer le “tchin” via gyroscope
├── models/                  # Modèles simples (GameChoice, Player, etc.)
├── utils/                   # Fonctions utilitaires (comparateur, helpers, etc.)
├── theme/                   # Thème global, couleurs, typographies
│   ├── colors.dart
│   └── app_theme.dart
└── constants/               # Textes statiques, tailles, assets
    ├── strings.dart
    └── assets.dart