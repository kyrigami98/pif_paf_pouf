import 'package:cloud_firestore/cloud_firestore.dart';

class Player {
  final String id;
  final String name;
  final bool isReady;
  final bool isHost;
  final bool active;
  final int wins;
  final int score; // Nouveau champ pour les points dans la partie actuelle
  final DateTime? joinedAt;
  final String? currentChoice;

  Player({
    required this.id,
    required this.name,
    this.isReady = false,
    this.isHost = false,
    this.active = true,
    this.wins = 0,
    this.score = 0, // Valeur par défaut
    this.joinedAt,
    this.currentChoice,
  });

  // Factory pour créer un Player à partir d'un document Firestore
  factory Player.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Player(
      id: doc.id,
      name: data['name'] ?? 'Joueur inconnu',
      isReady: data['ready'] ?? false,
      isHost: data['isHost'] ?? false,
      active: data['active'] ?? true,
      wins: data['wins'] ?? 0,
      score: data['score'] ?? 0, // Récupérer le score depuis Firestore
      joinedAt: data['joinedAt'] != null ? (data['joinedAt'] as Timestamp).toDate() : null,
      currentChoice: data['currentChoice'],
    );
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'ready': isReady,
      'isHost': isHost,
      'active': active,
      'wins': wins,
      'score': score, // Inclure le score dans les données à sauvegarder
      'joinedAt': joinedAt != null ? Timestamp.fromDate(joinedAt!) : FieldValue.serverTimestamp(),
      'currentChoice': currentChoice,
    };
  }

  // Créer une copie avec des modifications
  Player copyWith({
    String? name,
    bool? isReady,
    bool? isHost,
    bool? active,
    int? wins,
    int? score,
    DateTime? joinedAt,
    String? currentChoice,
  }) {
    return Player(
      id: id,
      name: name ?? this.name,
      isReady: isReady ?? this.isReady,
      isHost: isHost ?? this.isHost,
      active: active ?? this.active,
      wins: wins ?? this.wins,
      score: score ?? this.score,
      joinedAt: joinedAt ?? this.joinedAt,
      currentChoice: currentChoice ?? this.currentChoice,
    );
  }

  // Première lettre du nom d'utilisateur pour l'avatar
  String get initial => name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

  // Pour la compatibilité avec le code existant
  String get username => name;
}
