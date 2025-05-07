import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
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
}
