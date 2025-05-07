Mise à jour de la méthodologie (join via code)
Création de la room

Génération d’un code unique (par exemple 6 ou 8 caractères alphanumériques) quand l’hôte appuie sur “Nouvelle partie”.

Écriture d’un document rooms/{roomId} dans Firestore avec l’attribut joinCode et l’état lobby.

Phase de lobby (rejoindre via code)

Sur l’écran d’accueil, l’utilisateur :

Rentre son pseudo,

Choisit “Rejoindre une partie” puis saisit le code.

Le client query Firestore pour trouver rooms où joinCode == saisi.

Si trouvé et que players.count < 6, ajouter un sous-doc players/{playerId} dans la room.

Validation “Prêt” et transition en jeu

Chaque joueur clique sur “Prêt” ; on met à jour son champ ready: true.

Quand tous les joueurs du lobby sont prêts, on passe rooms/{roomId}.status à in_game et on initialise currentRound = 1.

Boucle des rounds “battle royale”

Pour chaque round tant que players.active.count > 1 :

Collecte des choix : chaque joueur actif écrit son choix dans rooms/{roomId}/rounds/{roundId}/choices/{playerId}.

Affichage des choix : on lit tous les docs choices/ et on les présente dans l’UI AVANT d’éliminer.

Calcul et éliminations :

Déterminer les signes en lice,

Lister les playerId éliminés,

Mettre à jour rooms/{roomId}/rounds/{roundId}.eliminated et, dans players/{playerId}, active: false.

Incrémentation du round : rooms/{roomId}.currentRound += 1.

Fin de partie et scores

Quand il ne reste qu’un seul joueur actif :

Mettre rooms/{roomId}.status = "finished",

Incrémenter players/{winnerId}.wins dans la sous-collection players.

Proposer un bouton ”Rejouer” qui remet :

status = "lobby",

Tous les players/{playerId}.active = true et ready = false,

Supprime la sous-collection rounds (ou archive les anciens rounds si besoin).

Schéma Firestore adapté
typescript
Copier
Modifier
rooms (collection)
│
├─ {roomId} (document)
│   ├─ joinCode: string            // code généré pour rejoindre
│   ├─ status: "lobby" | "in_game" | "finished"
│   ├─ currentRound: number
│   ├─ createdAt: Timestamp
│
│   ├─ players (subcollection)
│   │   ├─ {playerId} (document)
│   │   │   ├─ name: string
│   │   │   ├─ active: boolean     // en lice ce round
│   │   │   ├─ ready: boolean      // prêt pour démarrer
│   │   │   └─ wins: number        // total de victoires
│
│   └─ rounds (subcollection)
│       ├─ {roundId} (document)    // ex. "round_1", "round_2", …
│       │   ├─ roundNumber: number
│       │   ├─ startedAt: Timestamp
│       │   ├─ resultAnnounced: boolean
│       │   ├─ choices (map)       // playerId → "rock"|"paper"|"scissors"
│       │   └─ eliminated: string[]// liste des playerId éliminés
Points clés :

Le champ joinCode remplace le “tchin” : simple saisie et requête Firestore.

Les sous-collections players et rounds permettent de gérer l’état et l’historique de chaque partie.

On conserve les victoires (wins) pour permettre plusieurs parties sans perdre les scores.

Cette approche garantit un flux clair : création/join via code, lobby, rounds “battle royale” avec affichage des choix avant élimination, et réinitialisation pour rejouer tout en gardant les statistiques.