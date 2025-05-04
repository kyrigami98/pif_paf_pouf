import 'package:cloud_firestore/cloud_firestore.dart';

class Player {
  final String id;
  final String username;
  final bool isReady;
  final bool isHost;
  final DateTime? joinedAt;
  final bool isActive;
  final String? currentChoice; // Ajout pour suivre le choix actuel du joueur

  Player({
    required this.id,
    required this.username,
    this.isReady = false,
    this.isHost = false,
    this.joinedAt,
    this.isActive = true,
    this.currentChoice,
  });

  // Factory pour créer un Player à partir d'un document Firestore
  factory Player.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Player(
      id: doc.id,
      username: data['username'] ?? 'Joueur inconnu',
      isReady: data['isReady'] ?? false,
      isHost: data['isHost'] ?? false,
      joinedAt: data['joinedAt'] != null ? (data['joinedAt'] as Timestamp).toDate() : null,
      isActive: data['isActive'] ?? true,
      currentChoice: data['currentChoice'],
    );
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'isReady': isReady,
      'isHost': isHost,
      'joinedAt': joinedAt != null ? Timestamp.fromDate(joinedAt!) : FieldValue.serverTimestamp(),
      'isActive': isActive,
      'currentChoice': currentChoice,
    };
  }

  // Créer une copie avec des modifications
  Player copyWith({String? username, bool? isReady, bool? isHost, DateTime? joinedAt, bool? isActive, String? currentChoice}) {
    return Player(
      id: this.id,
      username: username ?? this.username,
      isReady: isReady ?? this.isReady,
      isHost: isHost ?? this.isHost,
      joinedAt: joinedAt ?? this.joinedAt,
      isActive: isActive ?? this.isActive,
      currentChoice: currentChoice ?? this.currentChoice,
    );
  }

  // Première lettre du nom d'utilisateur pour l'avatar
  String get initial => username.isNotEmpty ? username.substring(0, 1).toUpperCase() : '?';
}
