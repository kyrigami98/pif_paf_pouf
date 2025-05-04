import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pif_paf_pouf/models/game_choice.dart';

class RoundResult {
  final int roundNumber;
  final List<String> winners;
  final bool completed;
  final DateTime? completedAt;
  final List<GameChoice> playerChoices;

  RoundResult({
    required this.roundNumber,
    this.winners = const [],
    this.completed = false,
    this.completedAt,
    this.playerChoices = const [],
  });

  // Factory pour créer un RoundResult à partir d'un document Firestore
  factory RoundResult.fromFirestore(DocumentSnapshot doc, {List<GameChoice> choices = const []}) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Extraire le numéro du round à partir de l'ID (ex: round1 -> 1)
    int roundNumber = 0;
    if (doc.id.startsWith('round')) {
      final numStr = doc.id.substring(5);
      roundNumber = int.tryParse(numStr) ?? 0;
    }

    return RoundResult(
      roundNumber: roundNumber,
      winners: data['winners'] != null ? List<String>.from(data['winners']) : [],
      completed: data['completed'] ?? false,
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
      playerChoices: choices,
    );
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'winners': winners,
      'completed': completed,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : FieldValue.serverTimestamp(),
    };
  }

  // Créer une copie avec des modifications
  RoundResult copyWith({
    int? roundNumber,
    List<String>? winners,
    bool? completed,
    DateTime? completedAt,
    List<GameChoice>? playerChoices,
  }) {
    return RoundResult(
      roundNumber: roundNumber ?? this.roundNumber,
      winners: winners ?? this.winners,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      playerChoices: playerChoices ?? this.playerChoices,
    );
  }

  // Détermine si un joueur spécifique est un gagnant
  bool isPlayerWinner(String playerId) {
    return winners.contains(playerId);
  }

  // Vérifie s'il y a une égalité
  bool get isDraw => winners.isEmpty;
}
