import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pif_paf_pouf/models/game_choice.dart';

class RoundResult {
  final int roundNumber;
  final List<String> winners;
  final bool completed;
  final DateTime? completedAt;
  final List<String> eliminated;
  final List<GameChoice> playerChoices;
  final bool resultAnnounced;
  final bool isTie;

  RoundResult({
    required this.roundNumber,
    this.winners = const [],
    this.completed = false,
    this.completedAt,
    this.eliminated = const [],
    this.playerChoices = const [],
    this.resultAnnounced = false,
    this.isTie = false,
  });

  // Factory pour créer un RoundResult à partir d'un document Firestore
  factory RoundResult.fromFirestore(DocumentSnapshot doc, {List<GameChoice> choices = const []}) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Extraire le numéro du round à partir de l'ID (ex: round_1 -> 1)
    int roundNumber = data['roundNumber'] ?? 0;
    if (roundNumber == 0 && doc.id.startsWith('round_')) {
      final numStr = doc.id.substring(6);
      roundNumber = int.tryParse(numStr) ?? 0;
    }

    // Liste des joueurs non éliminés = gagnants
    final elimList = data['eliminated'] is List ? List<String>.from(data['eliminated']) : <String>[];

    // Détecter si c'est une égalité parfaite
    bool isTie = data['isTie'] ?? false;

    // Si nous avons des choix, vérifier si tous les joueurs ont choisi la même chose
    if (choices.length > 1) {
      final firstChoice = choices.first.choice;
      final allSameChoice = choices.every((c) => c.choice == firstChoice);
      // C'est une égalité parfaite si tous ont choisi la même chose
      if (allSameChoice) {
        isTie = true;
      }
    }

    // Liste des gagnants (non éliminés) - à déterminer à partir des choices si non spécifié
    List<String> winners = [];
    if (data['winners'] != null) {
      winners = List<String>.from(data['winners']);
    } else if (choices.isNotEmpty) {
      // Calculer les gagnants à partir des joueurs non éliminés
      winners = choices.map((c) => c.playerId).where((id) => !elimList.contains(id)).toList();
    }

    return RoundResult(
      roundNumber: roundNumber,
      winners: winners,
      completed: data['resultAnnounced'] ?? false,
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
      eliminated: elimList,
      playerChoices: choices,
      resultAnnounced: data['resultAnnounced'] ?? false,
      isTie: isTie,
    );
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'roundNumber': roundNumber,
      'resultAnnounced': resultAnnounced,
      'eliminated': eliminated,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : FieldValue.serverTimestamp(),
    };
  }

  // Créer une copie avec des modifications
  RoundResult copyWith({
    int? roundNumber,
    List<String>? winners,
    bool? completed,
    DateTime? completedAt,
    List<String>? eliminated,
    List<GameChoice>? playerChoices,
    bool? resultAnnounced,
    bool? isTie,
  }) {
    return RoundResult(
      roundNumber: roundNumber ?? this.roundNumber,
      winners: winners ?? this.winners,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      eliminated: eliminated ?? this.eliminated,
      playerChoices: playerChoices ?? this.playerChoices,
      resultAnnounced: resultAnnounced ?? this.resultAnnounced,
      isTie: isTie ?? this.isTie,
    );
  }

  // Détermine si un joueur spécifique est un gagnant (non éliminé)
  bool isPlayerWinner(String playerId) {
    return !eliminated.contains(playerId);
  }

  // Vérifie s'il y a une égalité parfaite (tous les joueurs ont fait le même choix)
  bool get isPerfectTie {
    if (playerChoices.length <= 1) return false;

    final firstChoice = playerChoices.first.choice;
    return playerChoices.every((choice) => choice.choice == firstChoice);
  }

  // Vérifie s'il y a une égalité (personne n'est éliminé)
  bool get isDraw => isTie || (eliminated.isEmpty && playerChoices.length > 1);
}
