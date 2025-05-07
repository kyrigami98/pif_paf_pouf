import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:pif_paf_pouf/data/models/models.dart';
import 'package:pif_paf_pouf/data/services/room_service.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final RoomService roomService;

  // Singleton pattern
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal() {
    roomService = RoomService(_firestore);
  }

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

  // Méthodes déléguées au RoomService
  Future<Map<String, dynamic>> createRoom(String username) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Future.value({'success': false, 'message': 'Non connecté'});
    return roomService.createRoom(userId, username);
  }

  Future<Map<String, dynamic>> joinRoomByCode(String roomCode, String username) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Future.value({'success': false, 'message': 'Non connecté'});
    return roomService.joinRoomByCode(roomCode, userId, username);
  }

  Future<Room?> getRoom(String roomId) {
    return roomService.getRoom(roomId);
  }

  Stream<Room> roomStream(String roomId) {
    return roomService.roomStream(roomId);
  }

  Stream<List<Player>> playersStream(String roomId) {
    return roomService.playersStream(roomId);
  }

  Future<bool> updatePlayerStatus(String roomId, String playerId, bool isReady) {
    return roomService.updatePlayerStatus(roomId, playerId, isReady);
  }

  Future<bool> removePlayerFromRoom(String roomId, String playerId) {
    return roomService.removePlayerFromRoom(roomId, playerId);
  }

  Future<bool> makeChoice(String roomId, String playerId, String choiceStr) {
    return roomService.makeChoice(roomId, playerId, choiceStr);
  }

  Future<List<GameChoice>> getRoundChoices(String roomId, int roundNumber) {
    return roomService.getRoundChoices(roomId, roundNumber);
  }

  Stream<List<GameChoice>> roundChoicesStream(String roomId, int roundNumber) {
    return roomService.roundChoicesStream(roomId, roundNumber);
  }

  Future<bool> checkAllChoicesMade(String roomId) {
    return roomService.checkAllChoicesMade(roomId);
  }

  Future<RoundResult?> getRoundResult(String roomId, int roundNumber) {
    return roomService.getRoundResult(roomId, roundNumber);
  }

  Stream<RoundResult?> roundResultStream(String roomId, int roundNumber) {
    return roomService.roundResultStream(roomId, roundNumber);
  }

  Future<bool> resetRound(String roomId) {
    return roomService.resetRound(roomId);
  }

  Future<Map<String, dynamic>> createNewGameWithSamePlayers(String oldRoomId) {
    return roomService.createNewGameWithSamePlayers(oldRoomId);
  }
}
