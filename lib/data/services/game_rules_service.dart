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
      ),
      GameChoiceModel(
        id: 'papier',
        name: 'papier',
        displayName: 'Papier',
        imagePath: 'assets/images/paper.png',
        svgPath: 'assets/svg/paper.svg',
        color: AppColors.paper,
        beats: ['pierre'],
      ),
      GameChoiceModel(
        id: 'ciseaux',
        name: 'ciseaux',
        displayName: 'Ciseaux',
        imagePath: 'assets/images/scissors.png',
        svgPath: 'assets/svg/scissors.svg',
        color: AppColors.scissors,
        beats: ['papier'],
      ),
      // GameChoiceModel(
      //   id: 'puit',
      //   name: 'puit',
      //   displayName: 'Puit',
      //   imagePath: 'assets/images/puit.png',
      //   svgPath: 'assets/svg/puit.svg',
      //   color: Colors.blueAccent,
      //   beats: ['pierre', 'ciseaux'],
      // ),
    ];
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
      return GameDuelResult.tie; // Cas imprévu, considéré comme un match nul
    }
  }
}

/// Résultat possible d'un duel entre deux choix
enum GameDuelResult {
  firstWins, // Le premier choix gagne
  secondWins, // Le second choix gagne
  tie, // Match nul
}
