import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:pif_paf_pouf/models/models.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Obtenir l'utilisateur actuel
  User? get currentUser => _auth.currentUser;

  // Vérifier si l'utilisateur est connecté
  bool get isSignedIn => _auth.currentUser != null;

  // Obtenir l'ID de l'utilisateur actuel
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // Connexion anonyme
  Future<User?> signInAnonymously() async {
    try {
      final UserCredential userCredential = await _auth.signInAnonymously();
      return userCredential.user;
    } catch (e) {
      debugPrint('Erreur lors de la connexion anonyme: $e');
      return null;
    }
  }

  // Enregistrer le pseudo de l'utilisateur
  Future<bool> saveUsername(String username) async {
    if (_auth.currentUser == null) {
      return false;
    }

    try {
      // Enregistrer dans Firestore
      await _firestore.collection('users').doc(_auth.currentUser!.uid).set({
        'username': username,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Enregistrer localement
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);

      return true;
    } catch (e) {
      debugPrint('Erreur lors de l\'enregistrement du pseudo: $e');
      return false;
    }
  }

  // Récupérer le pseudo enregistré localement
  Future<String?> getLocalUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('username');
    } catch (e) {
      debugPrint('Erreur lors de la récupération du pseudo local: $e');
      return null;
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
  }

  // Méthodes pour la gestion des rooms

  // Générer un code de room court et lisible
  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // caractères lisibles (sans I, O, 0, 1)
    final random = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  // Créer une nouvelle room avec un code unique
  Future<Map<String, dynamic>> createRoom(String username) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return {'success': false, 'message': 'Non connecté'};

      // Générer un code unique
      String roomCode = _generateRoomCode();
      bool isUnique = false;

      // Vérifier que le code est unique
      while (!isUnique) {
        final checkCode = await _firestore.collection('rooms').where('roomCode', isEqualTo: roomCode).limit(1).get();
        if (checkCode.docs.isEmpty) {
          isUnique = true;
        } else {
          roomCode = _generateRoomCode();
        }
      }

      // Créer la room
      final roomRef = _firestore.collection('rooms').doc();
      final roomId = roomRef.id;

      // Créer un objet Room
      final room = Room(
        id: roomId,
        roomCode: roomCode,
        createdBy: userId,
        playerCount: 1,
        status: RoomStatus.waiting,
        currentRound: 0,
        gameStarted: false,
      );

      await roomRef.set(room.toFirestore());

      // Créer un objet Player pour le créateur
      final player = Player(id: userId, username: username, isReady: false, isHost: true);

      // Ajouter le créateur comme premier joueur
      await roomRef.collection('players').doc(userId).set(player.toFirestore());

      return {'success': true, 'roomId': roomId, 'roomCode': roomCode};
    } catch (e) {
      debugPrint('Erreur lors de la création de room: $e');
      return {'success': false, 'message': 'Erreur lors de la création: $e'};
    }
  }

  // Rejoindre une room par code
  Future<Map<String, dynamic>> joinRoomByCode(String roomCode, String username) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return {'success': false, 'message': 'Non connecté'};

      // Rechercher la room par code
      final roomQuery = await _firestore.collection('rooms').where('roomCode', isEqualTo: roomCode).limit(1).get();

      if (roomQuery.docs.isEmpty) {
        return {'success': false, 'message': 'Code de room invalide'};
      }

      final roomDoc = roomQuery.docs.first;
      final roomId = roomDoc.id;

      // Créer un objet Room
      final room = Room.fromFirestore(roomDoc);

      // Vérifier si la partie a déjà commencé
      if (room.gameStarted) {
        return {'success': false, 'message': 'La partie a déjà commencé'};
      }

      // Vérifier si la room est pleine
      if (room.playerCount >= 6) {
        return {'success': false, 'message': 'La room est pleine (6 joueurs max)'};
      }

      // Vérifier si le joueur est déjà dans la room
      final playerRef = _firestore.collection('rooms').doc(roomId).collection('players').doc(userId);
      final playerDoc = await playerRef.get();

      if (playerDoc.exists) {
        // Le joueur existe déjà, on le réactive simplement
        await playerRef.update({'isActive': true});
      } else {
        // Créer un objet Player pour le nouveau joueur
        final player = Player(id: userId, username: username, isReady: false, isHost: false);

        // Ajouter le joueur à la room
        await playerRef.set(player.toFirestore());

        // Mettre à jour le compteur de joueurs
        await _firestore.collection('rooms').doc(roomId).update({'playerCount': FieldValue.increment(1)});
      }

      return {'success': true, 'roomId': roomId, 'roomCode': roomCode};
    } catch (e) {
      debugPrint('Erreur lors de la jointure de room: $e');
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // Récupérer les informations complètes d'une room
  Future<Room?> getRoom(String roomId) async {
    try {
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      if (!roomDoc.exists) return null;

      // Récupérer tous les joueurs de la room
      final playersSnapshot = await _firestore.collection('rooms').doc(roomId).collection('players').get();
      final players = playersSnapshot.docs.map((doc) => Player.fromFirestore(doc)).toList();

      return Room.fromFirestore(roomDoc, players: players);
    } catch (e) {
      debugPrint('Erreur lors de la récupération de la room: $e');
      return null;
    }
  }

  // Stream d'une room (pour les mises à jour en temps réel)
  Stream<Room> roomStream(String roomId) {
    return _firestore.collection('rooms').doc(roomId).snapshots().asyncMap((roomDoc) async {
      // Récupérer tous les joueurs de la room en temps réel
      final playersSnapshot = await _firestore.collection('rooms').doc(roomId).collection('players').get();
      final players = playersSnapshot.docs.map((doc) => Player.fromFirestore(doc)).toList();

      return Room.fromFirestore(roomDoc, players: players);
    });
  }

  // Stream des joueurs d'une room
  Stream<List<Player>> playersStream(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('players')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Player.fromFirestore(doc)).toList());
  }

  // Mettre à jour le statut "prêt" du joueur
  Future<bool> updatePlayerStatus(String roomId, String playerId, bool isReady) async {
    try {
      await _firestore.collection('rooms').doc(roomId).collection('players').doc(playerId).update({'isReady': isReady});

      // Vérifier si tous les joueurs sont prêts
      final playersSnapshot = await _firestore.collection('rooms').doc(roomId).collection('players').get();
      final players = playersSnapshot.docs.map((doc) => Player.fromFirestore(doc)).toList();

      bool allReady = players.every((player) => player.isReady);
      final playerCount = players.length;

      // Si tous les joueurs sont prêts (au moins 2), mettre à jour le statut de la room
      if (allReady && playerCount >= 2) {
        await _firestore.collection('rooms').doc(roomId).update({
          'status': 'ready',
          'gameStarted': true,
          'currentRound': 1,
          'roundStartTime': FieldValue.serverTimestamp(),
        });
      }

      return true;
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour du statut: $e');
      return false;
    }
  }

  // Supprimer un joueur d'une room
  Future<bool> removePlayerFromRoom(String roomId, String playerId) async {
    try {
      // Supprimer le joueur de la room
      await _firestore.collection('rooms').doc(roomId).collection('players').doc(playerId).delete();

      // Décrémenter le compteur de joueurs
      await _firestore.collection('rooms').doc(roomId).update({'playerCount': FieldValue.increment(-1)});

      // Vérifier s'il reste des joueurs
      final playersSnapshot = await _firestore.collection('rooms').doc(roomId).collection('players').get();

      if (playersSnapshot.docs.isEmpty) {
        // Supprimer la room si elle est vide
        await _firestore.collection('rooms').doc(roomId).delete();
      }

      return true;
    } catch (e) {
      debugPrint('Erreur lors de la suppression du joueur: $e');
      return false;
    }
  }

  // Faire un choix (pierre, papier, ciseaux)
  Future<bool> makeChoice(String roomId, String playerId, String choiceStr) async {
    try {
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      final currentRound = roomDoc.data()?['currentRound'] ?? 1;

      // Convertir la chaîne en énumération Choice
      final choice = Choice.fromString(choiceStr);

      // Créer l'objet GameChoice
      final gameChoice = GameChoice(playerId: playerId, choice: choice);

      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('rounds')
          .doc('round$currentRound')
          .collection('choices')
          .doc(playerId)
          .set(gameChoice.toFirestore());

      return true;
    } catch (e) {
      debugPrint('Erreur lors du choix: $e');
      return false;
    }
  }

  // Récupérer les choix d'un round
  Future<List<GameChoice>> getRoundChoices(String roomId, int roundNumber) async {
    try {
      final choicesSnapshot =
          await _firestore
              .collection('rooms')
              .doc(roomId)
              .collection('rounds')
              .doc('round$roundNumber')
              .collection('choices')
              .get();

      return choicesSnapshot.docs.map((doc) => GameChoice.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Erreur lors de la récupération des choix: $e');
      return [];
    }
  }

  // Stream des choix d'un round
  Stream<List<GameChoice>> roundChoicesStream(String roomId, int roundNumber) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('rounds')
        .doc('round$roundNumber')
        .collection('choices')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => GameChoice.fromFirestore(doc)).toList());
  }

  // Vérifier si tous les joueurs ont fait leur choix
  Future<bool> checkAllChoicesMade(String roomId) async {
    try {
      final room = await getRoom(roomId);
      if (room == null) return false;

      final currentRound = room.currentRound;
      final playerCount = room.playerCount;

      final choices = await getRoundChoices(roomId, currentRound);
      return choices.length == playerCount;
    } catch (e) {
      debugPrint('Erreur lors de la vérification des choix: $e');
      return false;
    }
  }

  // Déterminer le gagnant du round
  Future<void> determineWinner(String roomId) async {
    try {
      final room = await getRoom(roomId);
      if (room == null) return;

      final currentRound = room.currentRound;

      // Récupérer tous les choix
      final choices = await getRoundChoices(roomId, currentRound);

      // Extraire les choix pour la logique de jeu
      final playerChoices = Map<String, Choice>.fromEntries(choices.map((choice) => MapEntry(choice.playerId, choice.choice)));

      // Déterminer les gagnants
      final survivorIds = calculateSurvivors(playerChoices);

      // Créer un objet RoundResult
      final result = RoundResult(
        roundNumber: currentRound,
        winners: survivorIds.toList(),
        completed: true,
        playerChoices: choices,
      );

      // Enregistrer les résultats
      await _firestore.collection('rooms').doc(roomId).collection('rounds').doc('round$currentRound').set(result.toFirestore());

      // Si un seul gagnant, fin de la partie
      if (survivorIds.length == 1) {
        await _firestore.collection('rooms').doc(roomId).update({
          'winner': survivorIds.first,
          'status': 'completed',
          'gameEnded': true,
        });
      } else if (survivorIds.isEmpty) {
        // Cas exceptionnel: égalité parfaite, tout le monde reste
        await _firestore.collection('rooms').doc(roomId).update({
          'currentRound': currentRound + 1,
          'roundStartTime': FieldValue.serverTimestamp(),
        });
      } else {
        // Préparation du round suivant
        await _firestore.collection('rooms').doc(roomId).update({
          'currentRound': currentRound + 1,
          'roundStartTime': FieldValue.serverTimestamp(),
          'survivors': survivorIds.toList(),
        });
      }
    } catch (e) {
      debugPrint('Erreur lors de la détermination du gagnant: $e');
    }
  }

  // Calculer les survivants du round (logique de jeu)
  Set<String> calculateSurvivors(Map<String, Choice> playerChoices) {
    // Si un seul joueur, il gagne automatiquement
    if (playerChoices.length == 1) {
      return playerChoices.keys.toSet();
    }

    // Compter les choix
    int pierreCount = 0, papierCount = 0, ciseauxCount = 0;
    for (var choice in playerChoices.values) {
      if (choice == Choice.pierre) pierreCount++;
      if (choice == Choice.papier) papierCount++;
      if (choice == Choice.ciseaux) ciseauxCount++;
    }

    // Déterminer le choix gagnant
    Choice? winningChoice;
    if (pierreCount > 0 && papierCount > 0 && ciseauxCount > 0) {
      // Tous les choix sont présents, personne n'est éliminé
      return playerChoices.keys.toSet();
    } else if (pierreCount > 0 && papierCount > 0) {
      winningChoice = Choice.papier; // Papier bat pierre
    } else if (papierCount > 0 && ciseauxCount > 0) {
      winningChoice = Choice.ciseaux; // Ciseaux bat papier
    } else if (pierreCount > 0 && ciseauxCount > 0) {
      winningChoice = Choice.pierre; // Pierre bat ciseaux
    } else {
      // Tous les joueurs ont fait le même choix, personne n'est éliminé
      return playerChoices.keys.toSet();
    }

    // Retourner les joueurs qui ont fait le choix gagnant
    Set<String> survivors = {};
    if (winningChoice != null) {
      playerChoices.forEach((playerId, choice) {
        if (choice == winningChoice) {
          survivors.add(playerId);
        }
      });
    }

    return survivors;
  }

  // Récupérer les résultats d'un round
  Future<RoundResult?> getRoundResult(String roomId, int roundNumber) async {
    try {
      final roundDoc = await _firestore.collection('rooms').doc(roomId).collection('rounds').doc('round$roundNumber').get();

      if (!roundDoc.exists) return null;

      // Récupérer les choix associés à ce round
      final choices = await getRoundChoices(roomId, roundNumber);

      return RoundResult.fromFirestore(roundDoc, choices: choices);
    } catch (e) {
      debugPrint('Erreur lors de la récupération des résultats: $e');
      return null;
    }
  }

  // Stream des résultats d'un round
  Stream<RoundResult?> roundResultStream(String roomId, int roundNumber) {
    return _firestore.collection('rooms').doc(roomId).collection('rounds').doc('round$roundNumber').snapshots().asyncMap((
      doc,
    ) async {
      if (!doc.exists) return null;

      // Récupérer les choix associés à ce round
      final choices = await getRoundChoices(roomId, roundNumber);

      return RoundResult.fromFirestore(doc, choices: choices);
    });
  }

  // Réinitialiser le round pour un nouveau tour
  Future<bool> resetRound(String roomId) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'roundStartTime': FieldValue.serverTimestamp(),
        'playersReady': [],
      });
      return true;
    } catch (e) {
      debugPrint('Erreur lors de la réinitialisation du round: $e');
      return false;
    }
  }
}
