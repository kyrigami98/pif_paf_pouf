import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pif_paf_pouf/models/models.dart';
import 'package:pif_paf_pouf/models/game_choice_model.dart';
import 'package:pif_paf_pouf/services/game_rules_service.dart';
import 'dart:math';

class RoomService {
  final FirebaseFirestore _firestore;
  final GameRulesService _gameRulesService = GameRulesService();

  RoomService(this._firestore);

  // Générer un code de room court et lisible
  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // caractères lisibles (sans I, O, 0, 1)
    final random = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  // Créer une nouvelle room avec un code unique
  Future<Map<String, dynamic>> createRoom(String userId, String username) async {
    try {
      // Générer un code unique
      String joinCode = _generateRoomCode();
      bool isUnique = false;

      // Vérifier que le code est unique
      while (!isUnique) {
        final checkCode = await _firestore.collection('rooms').where('joinCode', isEqualTo: joinCode).limit(1).get();
        if (checkCode.docs.isEmpty) {
          isUnique = true;
        } else {
          joinCode = _generateRoomCode();
        }
      }

      // Créer la room
      final roomRef = _firestore.collection('rooms').doc();
      final roomId = roomRef.id;

      // Initialiser la room avec le schéma décrit dans le README
      await roomRef.set({
        'joinCode': joinCode,
        'status': 'lobby',
        'currentRound': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userId,
        'playerCount': 1,
      });

      // Ajouter le créateur comme premier joueur (hôte)
      await roomRef.collection('players').doc(userId).set({
        'name': username,
        'active': true,
        'ready': false,
        'isHost': true,
        'wins': 0,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      return {'success': true, 'roomId': roomId, 'roomCode': joinCode};
    } catch (e) {
      debugPrint('Erreur lors de la création de room: $e');
      return {'success': false, 'message': 'Erreur lors de la création: $e'};
    }
  }

  // Rejoindre une room par code
  Future<Map<String, dynamic>> joinRoomByCode(String roomCode, String userId, String username) async {
    try {
      // Rechercher la room par code
      final roomQuery = await _firestore.collection('rooms').where('joinCode', isEqualTo: roomCode).limit(1).get();

      if (roomQuery.docs.isEmpty) {
        return {'success': false, 'message': 'Code de room invalide'};
      }

      final roomDoc = roomQuery.docs.first;
      final roomId = roomDoc.id;
      final roomData = roomDoc.data();

      // Vérifier si la partie a déjà commencé
      if (roomData['status'] == 'in_game') {
        return {'success': false, 'message': 'La partie a déjà commencé'};
      }

      // Vérifier si la room est pleine (max 6 joueurs)
      if ((roomData['playerCount'] ?? 0) >= 6) {
        return {'success': false, 'message': 'La room est pleine (6 joueurs max)'};
      }

      // Vérifier si le joueur est déjà dans la room
      final playerRef = _firestore.collection('rooms').doc(roomId).collection('players').doc(userId);
      final playerDoc = await playerRef.get();

      if (playerDoc.exists) {
        // Le joueur existe déjà, on le réactive simplement
        await playerRef.update({'active': true, 'ready': false});
      } else {
        // Ajouter le joueur à la room
        await playerRef.set({
          'name': username,
          'active': true,
          'ready': false,
          'isHost': false,
          'wins': 0,
          'joinedAt': FieldValue.serverTimestamp(),
        });

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
      if (!roomDoc.exists) {
        throw Exception('Room $roomId n\'existe pas');
      }

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
      await _firestore.collection('rooms').doc(roomId).collection('players').doc(playerId).update({'ready': isReady});

      // Vérifier si tous les joueurs sont prêts
      final playersSnapshot = await _firestore.collection('rooms').doc(roomId).collection('players').get();
      final players = playersSnapshot.docs.map((doc) => Player.fromFirestore(doc)).toList();

      bool allReady = players.every((player) => player.isReady);
      final playerCount = players.length;

      // Si tous les joueurs sont prêts (au moins 2), mettre à jour le statut de la room
      if (allReady && playerCount >= 2) {
        await _firestore.collection('rooms').doc(roomId).update({
          'status': 'in_game',
          'currentRound': 1,
          'roundStartTime': FieldValue.serverTimestamp(),
        });

        // Créer le premier round
        await _firestore.collection('rooms').doc(roomId).collection('rounds').doc('round_1').set({
          'roundNumber': 1,
          'startedAt': FieldValue.serverTimestamp(),
          'resultAnnounced': false,
          'eliminated': [],
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
      // Vérifier si le joueur est l'hôte
      final playerDoc = await _firestore.collection('rooms').doc(roomId).collection('players').doc(playerId).get();
      final isHost = playerDoc.exists && (playerDoc.data()?['isHost'] == true);

      // Supprimer le joueur de la room
      await _firestore.collection('rooms').doc(roomId).collection('players').doc(playerId).delete();

      // Décrémenter le compteur de joueurs
      await _firestore.collection('rooms').doc(roomId).update({'playerCount': FieldValue.increment(-1)});

      // Vérifier s'il reste des joueurs
      final playersSnapshot = await _firestore.collection('rooms').doc(roomId).collection('players').get();

      if (playersSnapshot.docs.isEmpty) {
        // Supprimer la room si elle est vide
        await _firestore.collection('rooms').doc(roomId).delete();
      } else if (isHost) {
        // Si l'hôte part, attribuer le statut d'hôte à un autre joueur
        final newHostDoc = playersSnapshot.docs.first;
        await _firestore.collection('rooms').doc(roomId).collection('players').doc(newHostDoc.id).update({'isHost': true});
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
      if (!roomDoc.exists) {
        debugPrint('Room introuvable');
        return false;
      }

      final currentRound = roomDoc.data()?['currentRound'] ?? 1;
      final roundId = 'round_$currentRound';

      // Utiliser directement la chaîne de choix
      final choices = {};
      choices[playerId] = choiceStr;

      // Mettre à jour le choix dans rounds/{roundId}
      await _firestore.collection('rooms').doc(roomId).collection('rounds').doc(roundId).update({'choices.$playerId': choiceStr});

      // Mettre à jour le statut du joueur également
      await _firestore.collection('rooms').doc(roomId).collection('players').doc(playerId).update({'currentChoice': choiceStr});

      // Vérifier si tous les joueurs ont fait leur choix
      bool allMadeChoice = await checkAllChoicesMade(roomId);
      if (allMadeChoice) {
        // Déterminer les joueurs éliminés si tous ont fait leur choix
        await determineEliminations(roomId, roundId);
      }

      return true;
    } catch (e) {
      debugPrint('Erreur lors du choix: $e');
      return false;
    }
  }

  // Récupérer les choix d'un round
  Future<List<GameChoice>> getRoundChoices(String roomId, int roundNumber) async {
    try {
      final roundId = 'round_$roundNumber';
      final roundDoc = await _firestore.collection('rooms').doc(roomId).collection('rounds').doc(roundId).get();

      if (!roundDoc.exists) return [];

      final data = roundDoc.data() ?? {};
      final choices = data['choices'] as Map<String, dynamic>? ?? {};

      // Convertir la map en liste de GameChoice (utiliser le choix comme chaîne)
      final result = <GameChoice>[];
      choices.forEach((playerId, choiceStr) {
        result.add(GameChoice(playerId: playerId, choice: choiceStr, timestamp: null));
      });

      return result;
    } catch (e) {
      debugPrint('Erreur lors de la récupération des choix: $e');
      return [];
    }
  }

  // Stream des choix d'un round
  Stream<List<GameChoice>> roundChoicesStream(String roomId, int roundNumber) {
    final roundId = 'round_$roundNumber';
    return _firestore.collection('rooms').doc(roomId).collection('rounds').doc(roundId).snapshots().map((doc) {
      if (!doc.exists) return <GameChoice>[];

      final data = doc.data() ?? {};
      final choices = data['choices'] as Map<String, dynamic>? ?? {};

      final result = <GameChoice>[];
      choices.forEach((playerId, choiceStr) {
        result.add(GameChoice(playerId: playerId, choice: choiceStr, timestamp: null));
      });

      return result;
    });
  }

  // Vérifier si tous les joueurs ont fait leur choix
  Future<bool> checkAllChoicesMade(String roomId) async {
    try {
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      if (!roomDoc.exists) return false;

      final currentRound = roomDoc.data()?['currentRound'] ?? 1;
      final roundId = 'round_$currentRound';

      // Obtenir les données du round actuel
      final roundDoc = await _firestore.collection('rooms').doc(roomId).collection('rounds').doc(roundId).get();
      if (!roundDoc.exists) return false;

      final roundData = roundDoc.data() ?? {};
      final choices = roundData['choices'] as Map<String, dynamic>? ?? {};

      // Récupérer les survivants (joueurs actifs)
      List<String> activePlayers = [];

      // Si c'est le premier round, tous les joueurs sont actifs
      if (currentRound == 1) {
        final playersSnapshot = await _firestore.collection('rooms').doc(roomId).collection('players').get();
        activePlayers = playersSnapshot.docs.where((doc) => doc.data()['active'] == true).map((doc) => doc.id).toList();
      } else {
        // Sinon, récupérer les joueurs non éliminés des rounds précédents
        final prevRoundId = 'round_${currentRound - 1}';
        final prevRoundDoc = await _firestore.collection('rooms').doc(roomId).collection('rounds').doc(prevRoundId).get();

        if (prevRoundDoc.exists) {
          final prevRoundData = prevRoundDoc.data() ?? {};
          final eliminated = prevRoundData['eliminated'] as List<dynamic>? ?? [];

          // Récupérer tous les joueurs
          final playersSnapshot = await _firestore.collection('rooms').doc(roomId).collection('players').get();
          final allPlayerIds = playersSnapshot.docs.map((doc) => doc.id).toList();

          // Filtrer pour garder seulement les joueurs non éliminés
          activePlayers = allPlayerIds.where((id) => !eliminated.contains(id)).toList();
        }
      }

      // Vérifier si tous les joueurs actifs ont fait leur choix
      return activePlayers.every((playerId) => choices.containsKey(playerId));
    } catch (e) {
      debugPrint('Erreur lors de la vérification des choix: $e');
      return false;
    }
  }

  // Déterminer les joueurs éliminés dans un round
  Future<void> determineEliminations(String roomId, String roundId) async {
    try {
      // Récupérer les données de la room et du round
      final roundDoc = await _firestore.collection('rooms').doc(roomId).collection('rounds').doc(roundId).get();
      if (!roundDoc.exists) return;

      final roundData = roundDoc.data() ?? {};
      final choicesMap = roundData['choices'] as Map<String, dynamic>? ?? {};

      // Convertir les choix en GameChoice pour utiliser avec la logique d'élimination
      final gameChoices = <GameChoice>[];
      choicesMap.forEach((playerId, choiceStr) {
        gameChoices.add(GameChoice(playerId: playerId, choice: choiceStr));
      });

      // Utiliser la méthode de la classe GameChoice pour déterminer les joueurs éliminés
      final List<String> eliminated = GameChoice.determineEliminated(gameChoices);

      // Mettre à jour les joueurs éliminés dans le document du round
      await _firestore.collection('rooms').doc(roomId).collection('rounds').doc(roundId).update({
        'eliminated': eliminated,
        'resultAnnounced': true,
      });

      // Actualiser le statut 'active' des joueurs éliminés
      for (String playerId in eliminated) {
        await _firestore.collection('rooms').doc(roomId).collection('players').doc(playerId).update({'active': false});
      }

      // Vérifier le nombre de joueurs encore actifs
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      final currentRound = roomDoc.data()?['currentRound'] ?? 1;

      final playersSnapshot = await _firestore.collection('rooms').doc(roomId).collection('players').get();
      final activePlayerCount = playersSnapshot.docs.where((doc) => doc.data()['active'] == true).length;

      if (activePlayerCount <= 1) {
        // Fin de partie - un seul survivant (ou aucun en cas d'impasse)
        String? winner;
        if (activePlayerCount == 1) {
          winner = playersSnapshot.docs.firstWhere((doc) => doc.data()['active'] == true).id;

          // Incrémenter le nombre de victoires du gagnant
          await _firestore.collection('rooms').doc(roomId).collection('players').doc(winner).update({
            'wins': FieldValue.increment(1),
          });
        }

        await _firestore.collection('rooms').doc(roomId).update({'status': 'finished', 'winner': winner});
      } else {
        // Préparer le prochain round
        await _firestore.collection('rooms').doc(roomId).update({
          'currentRound': currentRound + 1,
          'roundStartTime': FieldValue.serverTimestamp(),
        });

        // Créer le document pour le prochain round
        await _firestore.collection('rooms').doc(roomId).collection('rounds').doc('round_${currentRound + 1}').set({
          'roundNumber': currentRound + 1,
          'startedAt': FieldValue.serverTimestamp(),
          'resultAnnounced': false,
          'eliminated': [],
        });
      }

      // Réinitialiser les choix des joueurs
      for (var doc in playersSnapshot.docs) {
        await doc.reference.update({'currentChoice': null, 'ready': false});
      }
    } catch (e) {
      debugPrint('Erreur lors de la détermination des éliminations: $e');
    }
  }

  // Récupérer les résultats d'un round
  Future<RoundResult?> getRoundResult(String roomId, int roundNumber) async {
    try {
      final roundId = 'round_$roundNumber';
      final roundDoc = await _firestore.collection('rooms').doc(roomId).collection('rounds').doc(roundId).get();

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
    final roundId = 'round_$roundNumber';
    return _firestore.collection('rooms').doc(roomId).collection('rounds').doc(roundId).snapshots().asyncMap((doc) async {
      if (!doc.exists) return null;

      // Récupérer les choix associés à ce round
      final choices = await getRoundChoices(roomId, roundNumber);

      return RoundResult.fromFirestore(doc, choices: choices);
    });
  }

  // Réinitialiser le round pour un nouveau tour
  Future<bool> resetRound(String roomId) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update({'roundStartTime': FieldValue.serverTimestamp()});
      return true;
    } catch (e) {
      debugPrint('Erreur lors de la réinitialisation du round: $e');
      return false;
    }
  }

  // Créer une nouvelle partie avec les mêmes joueurs
  Future<Map<String, dynamic>> createNewGameWithSamePlayers(String oldRoomId) async {
    try {
      // Récupérer les informations de la room actuelle
      final oldRoom = await getRoom(oldRoomId);
      if (oldRoom == null) {
        return {'success': false, 'message': 'La salle d\'origine n\'existe plus'};
      }

      // Générer un code unique pour la nouvelle room
      String joinCode = _generateRoomCode();
      bool isUnique = false;

      while (!isUnique) {
        final checkCode = await _firestore.collection('rooms').where('joinCode', isEqualTo: joinCode).limit(1).get();
        if (checkCode.docs.isEmpty) {
          isUnique = true;
        } else {
          joinCode = _generateRoomCode();
        }
      }

      // Créer la nouvelle room
      final roomRef = _firestore.collection('rooms').doc();
      final roomId = roomRef.id;

      // Initialiser la room
      await roomRef.set({
        'joinCode': joinCode,
        'status': 'lobby',
        'currentRound': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': oldRoom.createdBy,
        'playerCount': oldRoom.players.length,
      });

      // Ajouter tous les joueurs de l'ancienne room à la nouvelle
      for (final player in oldRoom.players) {
        // Réinitialiser isReady à false et active à true pour tous les joueurs
        await roomRef.collection('players').doc(player.id).set({
          'name': player.name,
          'ready': false,
          'isHost': player.isHost,
          'active': true,
          'wins': player.wins, // Conserver les victoires
          'joinedAt': FieldValue.serverTimestamp(),
        });
      }

      return {'success': true, 'roomId': roomId, 'roomCode': joinCode};
    } catch (e) {
      debugPrint('Erreur lors de la création d\'une nouvelle partie: $e');
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }
}
