import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

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
      print('Erreur lors de la connexion anonyme: $e');
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
      print('Erreur lors de l\'enregistrement du pseudo: $e');
      return false;
    }
  }

  // Récupérer le pseudo enregistré localement
  Future<String?> getLocalUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('username');
    } catch (e) {
      print('Erreur lors de la récupération du pseudo local: $e');
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

  Future<String?> createOrJoinRoom(String username) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      // Vérifier s'il y a une room disponible
      final availableRoomsSnapshot =
          await _firestore
              .collection('rooms')
              .where('playerCount', isLessThan: 6)
              .where('status', isEqualTo: 'waiting')
              .limit(1)
              .get();

      String roomId;

      if (availableRoomsSnapshot.docs.isNotEmpty) {
        // Rejoindre une room existante
        roomId = availableRoomsSnapshot.docs.first.id;

        // Vérifier si le joueur est déjà dans cette room
        final playerSnapshot = await _firestore.collection('rooms').doc(roomId).collection('players').doc(userId).get();

        if (!playerSnapshot.exists) {
          // Ajouter le joueur à la room
          await _firestore.collection('rooms').doc(roomId).collection('players').doc(userId).set({
            'username': username,
            'isReady': false,
            'joinedAt': FieldValue.serverTimestamp(),
          });

          // Mettre à jour le compteur de joueurs
          await _firestore.collection('rooms').doc(roomId).update({'playerCount': FieldValue.increment(1)});
        }
      } else {
        // Créer une nouvelle room
        final roomRef = _firestore.collection('rooms').doc();
        roomId = roomRef.id;

        await roomRef.set({
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': userId,
          'playerCount': 1,
          'status': 'waiting',
        });

        // Ajouter le joueur à la room
        await roomRef.collection('players').doc(userId).set({
          'username': username,
          'isReady': false,
          'joinedAt': FieldValue.serverTimestamp(),
        });
      }

      return roomId;
    } catch (e) {
      debugPrint('Erreur lors de la création/jointure de room: $e');
      return null;
    }
  }

  Future<bool> updatePlayerStatus(String roomId, String playerId, bool isReady) async {
    try {
      await _firestore.collection('rooms').doc(roomId).collection('players').doc(playerId).update({'isReady': isReady});

      // Vérifier si tous les joueurs sont prêts
      final playersSnapshot = await _firestore.collection('rooms').doc(roomId).collection('players').get();

      bool allReady = true;
      for (var player in playersSnapshot.docs) {
        if (player.data()['isReady'] != true) {
          allReady = false;
          break;
        }
      }

      // Si tous les joueurs sont prêts, mettre à jour le statut de la room
      if (allReady && playersSnapshot.docs.length >= 2) {
        await _firestore.collection('rooms').doc(roomId).update({'status': 'ready'});
      }

      return true;
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour du statut: $e');
      return false;
    }
  }

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
}
