import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pif_paf_pouf/models/game_choice_model.dart';
import 'package:pif_paf_pouf/services/game_rules_service.dart';

class GameChoice {
  final String playerId;
  final String choice; // Stocke l'ID du choix (pierre, papier, ciseaux)
  final DateTime? timestamp;

  GameChoice({required this.playerId, required this.choice, this.timestamp});

  // Factory pour créer un GameChoice à partir d'un document Firestore
  factory GameChoice.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GameChoice(
      playerId: doc.id,
      choice: data['choice'] ?? 'pierre',
      timestamp: data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : null,
    );
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {'choice': choice, 'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : FieldValue.serverTimestamp()};
  }

  // Obtenir le modèle de choix correspondant
  GameChoiceModel getChoiceModel() {
    final gameRulesService = GameRulesService();
    return gameRulesService.getChoiceById(choice) ?? gameRulesService.getAvailableChoices().first;
  }

  // Déterminer qui gagne entre plusieurs choix
  static List<String> determineEliminated(List<GameChoice> gameChoices) {
    if (gameChoices.isEmpty) return [];

    final gameRulesService = GameRulesService();
    final List<String> eliminated = [];

    // Pour chaque paire de joueurs, déterminer qui gagne
    for (int i = 0; i < gameChoices.length; i++) {
      final choice1 = gameRulesService.getChoiceById(gameChoices[i].choice);
      if (choice1 == null) continue;

      for (int j = i + 1; j < gameChoices.length; j++) {
        final choice2 = gameRulesService.getChoiceById(gameChoices[j].choice);
        if (choice2 == null) continue;

        final result = gameRulesService.determineDuelWinner(choice1, choice2);

        // Si le premier joueur perd, l'ajouter aux éliminés
        if (result == GameDuelResult.secondWins && !eliminated.contains(gameChoices[i].playerId)) {
          eliminated.add(gameChoices[i].playerId);
        }

        // Si le deuxième joueur perd, l'ajouter aux éliminés
        if (result == GameDuelResult.firstWins && !eliminated.contains(gameChoices[j].playerId)) {
          eliminated.add(gameChoices[j].playerId);
        }
      }
    }

    return eliminated;
  }
}
