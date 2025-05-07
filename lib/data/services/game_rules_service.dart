import 'package:flutter/material.dart';
import 'package:pif_paf_pouf/data/models/game/game_choice_model.dart';
import 'package:pif_paf_pouf/presentation/theme/colors.dart';

/// Service qui gère les règles du jeu et les choix disponibles
class GameRulesService {
  static final GameRulesService _instance = GameRulesService._internal();
  factory GameRulesService() => _instance;
  GameRulesService._internal();

  /// Liste des choix disponibles dans le jeu
  List<GameChoiceModel> getAvailableChoices() {
    return [
      GameChoiceModel(
        id: 'pierre',
        name: 'pierre',
        displayName: 'Pierre',
        imagePath: 'assets/images/rock.png',
        svgPath: 'assets/svg/rock.svg',
        color: AppColors.rock,
        beats: ['ciseaux'],
        description: 'La pierre écrase les ciseaux',
        icon: Icons.circle,
      ),
      GameChoiceModel(
        id: 'papier',
        name: 'papier',
        displayName: 'Papier',
        imagePath: 'assets/images/paper.png',
        svgPath: 'assets/svg/paper.svg',
        color: AppColors.paper,
        beats: ['pierre'],
        description: 'Le papier enveloppe la pierre',
        icon: Icons.description,
      ),
      GameChoiceModel(
        id: 'ciseaux',
        name: 'ciseaux',
        displayName: 'Ciseaux',
        imagePath: 'assets/images/scissors.png',
        svgPath: 'assets/svg/scissors.svg',
        color: AppColors.scissors,
        beats: ['papier'],
        description: 'Les ciseaux coupent le papier',
        icon: Icons.content_cut,
      ),
      GameChoiceModel(
        id: 'puit',
        name: 'puit',
        displayName: 'Puit',
        imagePath: 'assets/images/well.png',
        svgPath: 'assets/svg/well.svg',
        color: Colors.blueAccent,
        beats: ['pierre', 'ciseaux'],
        description: 'Le puit engloutit la pierre et les ciseaux',
        icon: Icons.waves,
      ),
    ];
  }

  /// Active ou désactive certains choix (permet d'étendre le jeu)
  List<GameChoiceModel> getActiveChoices({bool extendedMode = false}) {
    final allChoices = getAvailableChoices();
    if (!extendedMode) {
      // Mode classique : seulement pierre, papier, ciseaux
      return allChoices.where((choice) => ['pierre', 'papier', 'ciseaux'].contains(choice.id)).toList();
    }
    return allChoices; // Mode étendu : tous les choix
  }

  /// Récupère un choix par son ID
  GameChoiceModel? getChoiceById(String id) {
    final choices = getAvailableChoices();
    try {
      return choices.firstWhere((choice) => choice.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Détermine le résultat d'un duel entre deux choix
  GameDuelResult determineDuelWinner(GameChoiceModel choice1, GameChoiceModel choice2) {
    if (choice1.id == choice2.id) {
      return GameDuelResult.tie;
    } else if (choice1.canBeat(choice2)) {
      return GameDuelResult.firstWins;
    } else if (choice2.canBeat(choice1)) {
      return GameDuelResult.secondWins;
    } else {
      // Cas imprévu, considéré comme un match nul
      return GameDuelResult.tie;
    }
  }

  /// Détermine les joueurs éliminés entre plusieurs choix
  List<String> determineEliminated(List<GameChoice> gameChoices) {
    if (gameChoices.isEmpty) return [];

    // S'il n'y a qu'un seul choix, personne n'est éliminé
    if (gameChoices.length == 1) return [];

    // Vérifier si tous les joueurs ont fait le même choix (égalité parfaite)
    final firstChoice = gameChoices.first.choice;
    final isPerfectTie = gameChoices.every((choice) => choice.choice == firstChoice);
    if (isPerfectTie) return [];

    // Pour chaque paire de joueurs, déterminer qui gagne
    final List<String> eliminated = [];
    for (int i = 0; i < gameChoices.length; i++) {
      final choice1 = getChoiceById(gameChoices[i].choice);
      if (choice1 == null) continue;

      bool isEliminated = false;

      for (int j = 0; j < gameChoices.length; j++) {
        if (i == j) continue; // Ne pas comparer avec soi-même

        final choice2 = getChoiceById(gameChoices[j].choice);
        if (choice2 == null) continue;

        final result = determineDuelWinner(choice1, choice2);

        // Si le joueur i perd contre le joueur j, il est éliminé
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
}

/// Résultat possible d'un duel entre deux choix
enum GameDuelResult {
  firstWins, // Le premier choix gagne
  secondWins, // Le second choix gagne
  tie, // Match nul
}

// Classe GameChoice pour compatibilité avec le code existant
class GameChoice {
  final String playerId;
  final String choice;
  final DateTime? timestamp;

  GameChoice({required this.playerId, required this.choice, this.timestamp});
}
