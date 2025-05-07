import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pif_paf_pouf/data/models/game/room.dart';
import 'package:pif_paf_pouf/data/models/game/round_result.dart';
import 'package:pif_paf_pouf/data/models/user/player.dart';
import 'dart:math';

import 'package:pif_paf_pouf/data/services/game_rules_service.dart';

class RoomService {
  final FirebaseFirestore _firestore;
  final GameRulesService _gameRulesService = GameRulesService();

  // Cache local pour réduire les lectures Firestore
  final Map<String, Room> _roomCache = {};
  final Map<String, List<Player>> _playersCache = {};
  final Map<String, Map<int, List<GameChoice>>> _roundChoicesCache = {};

  RoomService(this._firestore);

  // Générer un code de room court et lisible
  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // caractères lisibles (sans I, O, 0, 1)
    final random = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  // Créer une nouvelle room avec un code unique
  Future<Map<String, dynamic>> createRoom(String userId, String username, {bool extendedMode = false}) async {
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

      // Utiliser WriteBatch pour regrouper les opérations d'écriture
      final batch = _firestore.batch();

      // Initialiser la room avec le schéma décrit
      batch.set(roomRef, {
        'joinCode': joinCode,
        'status': 'lobby',
        'currentRound': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': userId,
        'playerCount': 1,
        'extendedMode': extendedMode,
        'lastActivity': FieldValue.serverTimestamp(),
      });

      // Ajouter le créateur comme premier joueur (hôte)
      final playerRef = roomRef.collection('players').doc(userId);
      batch.set(playerRef, {
        'name': username,
        'active': true,
        'ready': false,
        'isHost': true,
        'wins': 0,
        'score': 0,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // Exécuter toutes les écritures en une seule opération
      await batch.commit();

      // Mettre à jour le cache local
      _roomCache[roomId] = Room(
        id: roomId,
        joinCode: joinCode,
        createdBy: userId,
        status: RoomStatus.lobby,
        currentRound: 0,
        playerCount: 1,
        players: [Player(id: userId, name: username, isHost: true, active: true)],
      );

      _playersCache[roomId] = [Player(id: userId, name: username, isHost: true, active: true)];

      return {'success': true, 'roomId': roomId, 'roomCode': joinCode};
    } catch (e) {
      debugPrint('Erreur lors de la création de room: $e');
      return {'success': false, 'message': 'Erreur lors de la création: $e'};
    }
  }

  // Mettre à jour le statut "prêt" du joueur
  Future<bool> updatePlayerStatus(String roomId, String playerId, bool isReady) async {
    try {
      // Mettre à jour le statut du joueur
      await _firestore.collection('rooms').doc(roomId).collection('players').doc(playerId).update({'ready': isReady});

      // Obtenir tous les joueurs après la mise à jour
      final playersQuery = await _firestore.collection('rooms').doc(roomId).collection('players').get();
      final players = playersQuery.docs.map((doc) => Player.fromFirestore(doc)).toList();

      // Mettre à jour le cache
      _playersCache[roomId] = players;

      // Vérifier si tous les joueurs sont prêts
      bool allReady = players.every((player) => player.isReady);
      final playerCount = players.length;

      // Si tous les joueurs sont prêts (au moins 2), mettre à jour le statut de la room
      if (allReady && playerCount >= 2) {
        final batch = _firestore.batch();
        final roomRef = _firestore.collection('rooms').doc(roomId);
        final roundRef = _firestore.collection('rooms').doc(roomId).collection('rounds').doc('round_1');

        batch.update(roomRef, {
          'status': 'in_game',
          'currentRound': 1,
          'roundStartTime': FieldValue.serverTimestamp(),
          'lastActivity': FieldValue.serverTimestamp(),
        });

        batch.set(roundRef, {
          'roundNumber': 1,
          'startedAt': FieldValue.serverTimestamp(),
          'resultAnnounced': false,
          'eliminated': [],
        });

        await batch.commit();
      }

      return true;
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour du statut: $e');
      return false;
    }
  }

  // Faire un choix (pierre, papier, ciseaux)
  Future<bool> makeChoice(String roomId, String playerId, String choiceStr) async {
    try {
      // Obtenir les informations nécessaires en dehors de la transaction
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      if (!roomDoc.exists) {
        debugPrint('Room introuvable');
        return false;
      }

      final currentRound = roomDoc.data()?['currentRound'] ?? 1;
      final roundId = 'round_$currentRound';

      // Mettre à jour le choix du joueur
      final batch = _firestore.batch();
      final roundRef = _firestore.collection('rooms').doc(roomId).collection('rounds').doc(roundId);
      final playerRef = _firestore.collection('rooms').doc(roomId).collection('players').doc(playerId);
      final roomRef = _firestore.collection('rooms').doc(roomId);

      // Vérifier si le document du round existe
      final roundDoc = await roundRef.get();
      if (!roundDoc.exists) {
        batch.set(roundRef, {
          'roundNumber': currentRound,
          'startedAt': FieldValue.serverTimestamp(),
          'resultAnnounced': false,
          'eliminated': [],
          'choices': {playerId: choiceStr},
        });
      } else {
        batch.update(roundRef, {'choices.$playerId': choiceStr});
      }

      batch.update(playerRef, {'currentChoice': choiceStr});
      batch.update(roomRef, {'lastActivity': FieldValue.serverTimestamp()});

      await batch.commit();

      // Obtenir tous les choix après mise à jour
      final updatedRoundDoc = await roundRef.get();
      final choices = (updatedRoundDoc.data()?['choices'] as Map<String, dynamic>?) ?? {};

      // Obtenir tous les joueurs actifs
      final playersQuery = await _firestore.collection('rooms').doc(roomId).collection('players').get();
      final players = playersQuery.docs.map((doc) => Player.fromFirestore(doc)).toList();
      final activePlayers = players.where((p) => p.active).map((p) => p.id).toList();

      // Vérifier si tous les joueurs actifs ont fait leur choix
      final allMadeChoice = activePlayers.every((id) => choices.containsKey(id));

      // Traiter les résultats si tous les joueurs ont fait leur choix
      if (allMadeChoice && activePlayers.length >= 2) {
        final gameChoices = <GameChoice>[];
        choices.forEach((playerId, choice) {
          if (activePlayers.contains(playerId)) {
            gameChoices.add(GameChoice(playerId: playerId, choice: choice));
          }
        });

        // Mettre à jour le cache
        if (!_roundChoicesCache.containsKey(roomId)) {
          _roundChoicesCache[roomId] = {};
        }
        _roundChoicesCache[roomId]![currentRound] = gameChoices;

        // Détermine les joueurs éliminés
        final eliminated = _determineEliminated(gameChoices);

        // Vérifier s'il y a une égalité parfaite
        final isPerfectTie =
            gameChoices.length > 1 && eliminated.isEmpty && gameChoices.every((c) => c.choice == gameChoices.first.choice);

        final isTie = isPerfectTie || eliminated.isEmpty;

        // Mise à jour des résultats
        final resultBatch = _firestore.batch();

        resultBatch.update(roundRef, {
          'eliminated': eliminated,
          'resultAnnounced': true,
          'isTie': isTie,
          'isPerfectTie': isPerfectTie,
          'completedAt': FieldValue.serverTimestamp(),
        });

        // Traiter les joueurs survivants/éliminés
        final survivors = gameChoices.map((c) => c.playerId).where((id) => !eliminated.contains(id)).toList();

        for (String id in gameChoices.map((c) => c.playerId)) {
          final playerRef = _firestore.collection('rooms').doc(roomId).collection('players').doc(id);

          if (eliminated.contains(id)) {
            resultBatch.update(playerRef, {'active': false});
          } else if (!isPerfectTie) {
            resultBatch.update(playerRef, {'score': FieldValue.increment(1)});
          }
        }

        // Compter les joueurs actifs après élimination
        final activePlayersAfterElimination = activePlayers.where((id) => !eliminated.contains(id)).length;

        // Cas 1: Égalité ou plusieurs joueurs actifs - continuer au prochain round
        if (isTie || activePlayersAfterElimination > 1) {
          resultBatch.update(roomRef, {
            'currentRound': currentRound + 1,
            'roundStartTime': FieldValue.serverTimestamp(),
            'survivors': survivors,
          });

          // Créer le document pour le prochain round
          final nextRoundRef = _firestore.collection('rooms').doc(roomId).collection('rounds').doc('round_${currentRound + 1}');
          resultBatch.set(nextRoundRef, {
            'roundNumber': currentRound + 1,
            'startedAt': FieldValue.serverTimestamp(),
            'resultAnnounced': false,
            'eliminated': [],
          });
        }
        // Cas 2: Un seul joueur restant - fin de la partie
        else if (activePlayersAfterElimination <= 1) {
          String? winner;
          if (activePlayersAfterElimination == 1) {
            winner = survivors.first;

            // Bonus pour le gagnant
            resultBatch.update(_firestore.collection('rooms').doc(roomId).collection('players').doc(winner), {
              'wins': FieldValue.increment(1),
              'score': FieldValue.increment(5), // Bonus pour avoir gagné
            });
          }

          resultBatch.update(roomRef, {
            'status': 'finished',
            'winner': winner,
            'survivors': survivors,
            'finishedAt': FieldValue.serverTimestamp(),
          });
        }

        // Réinitialiser les choix des joueurs pour le prochain round
        for (var player in players) {
          resultBatch.update(_firestore.collection('rooms').doc(roomId).collection('players').doc(player.id), {
            'currentChoice': null,
            'ready': false,
          });
        }

        await resultBatch.commit();
      }

      return true;
    } catch (e) {
      debugPrint('Erreur lors du choix: $e');
      return false;
    }
  }

  // Méthode pour déterminer les éliminés
  List<String> _determineEliminated(List<GameChoice> gameChoices) {
    if (gameChoices.isEmpty || gameChoices.length < 2) return [];

    // Vérifier si c'est une égalité parfaite
    final firstChoice = gameChoices.first.choice;
    if (gameChoices.every((c) => c.choice == firstChoice)) return [];

    final List<String> eliminated = [];

    for (int i = 0; i < gameChoices.length; i++) {
      final choice1 = _gameRulesService.getChoiceById(gameChoices[i].choice);
      if (choice1 == null) continue;

      bool isEliminated = false;

      for (int j = 0; j < gameChoices.length; j++) {
        if (i == j) continue;

        final choice2 = _gameRulesService.getChoiceById(gameChoices[j].choice);
        if (choice2 == null) continue;

        final result = _gameRulesService.determineDuelWinner(choice1, choice2);

        if (result == GameDuelResult.secondWins) {
          isEliminated = true;
          break;
        }
      }

      if (isEliminated && !eliminated.contains(gameChoices[i].playerId)) {
        eliminated.add(gameChoices[i].playerId);
      }
    }

    return eliminated;
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
      List<GameChoice> choices = await getRoundChoices(roomId, roundNumber);

      return RoundResult.fromFirestore(doc, choices: choices);
    });
  }

  // Récupérer les choix d'un round
  Future<List<GameChoice>> getRoundChoices(String roomId, int roundNumber) async {
    try {
      // Vérifier le cache d'abord
      if (_roundChoicesCache.containsKey(roomId) && _roundChoicesCache[roomId]!.containsKey(roundNumber)) {
        return _roundChoicesCache[roomId]![roundNumber]!;
      }

      final roundId = 'round_$roundNumber';
      final roundDoc = await _firestore.collection('rooms').doc(roomId).collection('rounds').doc(roundId).get();

      if (!roundDoc.exists) return [];

      final data = roundDoc.data() ?? {};
      final choices = data['choices'] as Map<String, dynamic>? ?? {};

      // Convertir la map en liste de GameChoice
      final result = <GameChoice>[];
      choices.forEach((playerId, choiceStr) {
        result.add(GameChoice(playerId: playerId, choice: choiceStr, timestamp: null));
      });

      // Mettre à jour le cache
      if (!_roundChoicesCache.containsKey(roomId)) {
        _roundChoicesCache[roomId] = {};
      }
      _roundChoicesCache[roomId]![roundNumber] = result;

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

      // Mettre à jour le cache
      if (!_roundChoicesCache.containsKey(roomId)) {
        _roundChoicesCache[roomId] = {};
      }
      _roundChoicesCache[roomId]![roundNumber] = result;

      return result;
    });
  }

  // Réinitialiser le round pour un nouveau tour
  Future<bool> resetRound(String roomId) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'roundStartTime': FieldValue.serverTimestamp(),
        'lastActivity': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Erreur lors de la réinitialisation du round: $e');
      return false;
    }
  }

  // Créer une nouvelle partie avec les mêmes joueurs
  Future<Map<String, dynamic>> createNewGameWithSamePlayers(String oldRoomId) async {
    try {
      // Récupérer les informations de la room actuelle (utiliser la fonction mise en cache)
      final oldRoom = await getRoom(oldRoomId);
      if (oldRoom == null) {
        return {'success': false, 'message': 'La salle d\'origine n\'existe plus'};
      }

      // Déterminer si on utilise le mode étendu
      bool extendedMode = false;
      final oldRoomDoc = await _firestore.collection('rooms').doc(oldRoomId).get();
      if (oldRoomDoc.exists) {
        extendedMode = oldRoomDoc.data()?['extendedMode'] ?? false;
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

      // Utiliser une transaction pour garantir l'intégrité
      return await _firestore.runTransaction<Map<String, dynamic>>((transaction) async {
        // Créer la nouvelle room
        final roomRef = _firestore.collection('rooms').doc();
        final roomId = roomRef.id;

        // Initialiser la room
        transaction.set(roomRef, {
          'joinCode': joinCode,
          'status': 'lobby',
          'currentRound': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': oldRoom.createdBy,
          'playerCount': oldRoom.players.length,
          'extendedMode': extendedMode,
          'lastActivity': FieldValue.serverTimestamp(),
        });

        // Ajouter tous les joueurs de l'ancienne room à la nouvelle
        for (final player in oldRoom.players) {
          // Réinitialiser isReady à false et active à true pour tous les joueurs
          // Conserver les victoires mais réinitialiser le score
          transaction.set(roomRef.collection('players').doc(player.id), {
            'name': player.name,
            'ready': false,
            'isHost': player.isHost,
            'active': true,
            'wins': player.wins, // Conserver les victoires totales
            'score': 0, // Réinitialiser le score pour la nouvelle partie
            'joinedAt': FieldValue.serverTimestamp(),
          });
        }

        // Ajouter nextRoomId à l'ancienne room pour rediriger tous les clients
        transaction.update(_firestore.collection('rooms').doc(oldRoomId), {'nextRoomId': roomId, 'nextRoomCode': joinCode});

        // Initialiser le cache pour la nouvelle room
        _roomCache[roomId] = Room(
          id: roomId,
          joinCode: joinCode,
          createdBy: oldRoom.createdBy,
          status: RoomStatus.lobby,
          currentRound: 0,
          playerCount: oldRoom.players.length,
          players: oldRoom.players.map((p) => p.copyWith(isReady: false, active: true, score: 0)).toList(),
        );

        _playersCache[roomId] = oldRoom.players.map((p) => p.copyWith(isReady: false, active: true, score: 0)).toList();

        return {'success': true, 'roomId': roomId, 'roomCode': joinCode};
      });
    } catch (e) {
      debugPrint('Erreur lors de la création d\'une nouvelle partie: $e');
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // Récupérer les informations complètes d'une room avec mise en cache
  Future<Room?> getRoom(String roomId) async {
    try {
      // Vérifier d'abord le cache
      if (_roomCache.containsKey(roomId)) {
        return _roomCache[roomId];
      }

      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      if (!roomDoc.exists) return null;

      // Récupérer tous les joueurs de la room
      final playersSnapshot = await _firestore.collection('rooms').doc(roomId).collection('players').get();
      final players = playersSnapshot.docs.map((doc) => Player.fromFirestore(doc)).toList();

      // Construire l'objet Room
      final room = Room.fromFirestore(roomDoc, players: players);

      // Mettre en cache
      _roomCache[roomId] = room;
      _playersCache[roomId] = players;

      return room;
    } catch (e) {
      debugPrint('Erreur lors de la récupération de la room: $e');
      return null;
    }
  }

  // Stream d'une room (pour les mises à jour en temps réel) avec optimisation
  Stream<Room> roomStream(String roomId) {
    // Réduire les lectures en combinant les streams
    return _firestore.collection('rooms').doc(roomId).snapshots().asyncMap((roomDoc) async {
      if (!roomDoc.exists) {
        throw Exception('Room $roomId n\'existe pas');
      }

      final room = Room.fromFirestore(roomDoc);

      // Récupérer tous les joueurs de la room
      final playersSnapshot = await _firestore.collection('rooms').doc(roomId).collection('players').get();
      final players = playersSnapshot.docs.map((doc) => Player.fromFirestore(doc)).toList();

      final completeRoom = room.copyWith(players: players);

      // Mettre à jour le cache
      _roomCache[roomId] = completeRoom;
      _playersCache[roomId] = players;

      return completeRoom;
    });
  }

  // Rejoindre une room par code
  Future<Map<String, dynamic>> joinRoomByCode(String roomCode, String userId, String username) async {
    try {
      // Rechercher la room par code
      final roomQuery = await _firestore.collection('rooms').where('joinCode', isEqualTo: roomCode.toUpperCase()).limit(1).get();

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

      // Utiliser WriteBatch pour les opérations groupées
      final batch = _firestore.batch();
      final playerRef = _firestore.collection('rooms').doc(roomId).collection('players').doc(userId);
      final roomRef = _firestore.collection('rooms').doc(roomId);

      // Vérifier si le joueur existe déjà
      final playerDoc = await playerRef.get();

      if (playerDoc.exists) {
        // Le joueur existe déjà, on le réactive simplement
        batch.update(playerRef, {'active': true, 'ready': false, 'lastActivity': FieldValue.serverTimestamp()});
      } else {
        // Ajouter le joueur à la room
        batch.set(playerRef, {
          'name': username,
          'active': true,
          'ready': false,
          'isHost': false,
          'wins': 0,
          'score': 0,
          'joinedAt': FieldValue.serverTimestamp(),
        });

        // Mettre à jour le compteur de joueurs
        batch.update(roomRef, {'playerCount': FieldValue.increment(1), 'lastActivity': FieldValue.serverTimestamp()});
      }

      await batch.commit();

      return {'success': true, 'roomId': roomId, 'roomCode': roomCode};
    } catch (e) {
      debugPrint('Erreur lors de la jointure de room: $e');
      return {'success': false, 'message': 'Erreur: $e'};
    }
  }

  // Supprimer un joueur d'une room
  Future<bool> removePlayerFromRoom(String roomId, String playerId) async {
    try {
      // Obtenir les informations nécessaires avant la suppression
      final playerDoc = await _firestore.collection('rooms').doc(roomId).collection('players').doc(playerId).get();
      final isHost = playerDoc.exists && (playerDoc.data()?['isHost'] == true);

      final batch = _firestore.batch();
      final playerRef = _firestore.collection('rooms').doc(roomId).collection('players').doc(playerId);
      final roomRef = _firestore.collection('rooms').doc(roomId);

      // Supprimer le joueur
      batch.delete(playerRef);

      // Décrémenter le compteur de joueurs
      batch.update(roomRef, {'playerCount': FieldValue.increment(-1), 'lastActivity': FieldValue.serverTimestamp()});

      // Vérifier s'il reste des joueurs
      final playersSnapshot = await _firestore.collection('rooms').doc(roomId).collection('players').get();

      if (playersSnapshot.docs.isEmpty) {
        // Supprimer la room si elle est vide
        batch.delete(roomRef);
      } else if (isHost) {
        // Si l'hôte part, attribuer le statut d'hôte à un autre joueur
        final newHostDoc = playersSnapshot.docs.first;
        batch.update(_firestore.collection('rooms').doc(roomId).collection('players').doc(newHostDoc.id), {'isHost': true});
      }

      await batch.commit();

      // Mise à jour du cache
      if (_playersCache.containsKey(roomId)) {
        _playersCache[roomId]?.removeWhere((p) => p.id == playerId);
      }

      return true;
    } catch (e) {
      debugPrint('Erreur lors de la suppression du joueur: $e');
      return false;
    }
  }

  // Stream des joueurs d'une room
  Stream<List<Player>> playersStream(String roomId) {
    return _firestore.collection('rooms').doc(roomId).collection('players').snapshots().map((snapshot) {
      final players = snapshot.docs.map((doc) => Player.fromFirestore(doc)).toList();

      // Mettre à jour le cache
      _playersCache[roomId] = players;

      return players;
    });
  }

  // Nouvelle méthode: changer le mode de jeu (standard ou étendu)
  Future<bool> toggleGameMode(String roomId, bool extendedMode) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'extendedMode': extendedMode,
        'lastActivity': FieldValue.serverTimestamp(),
      });

      // Mettre à jour le cache
      if (_roomCache.containsKey(roomId)) {
        // Note: Room aurait besoin d'un champ extendedMode à ajouter au modèle
        _roomCache[roomId] = _roomCache[roomId]!;
      }

      return true;
    } catch (e) {
      debugPrint('Erreur lors du changement de mode de jeu: $e');
      return false;
    }
  }

  // Nettoyer le cache pour libérer de la mémoire
  void clearCache(String roomId) {
    _roomCache.remove(roomId);
    _playersCache.remove(roomId);
    _roundChoicesCache.remove(roomId);
  }
}
