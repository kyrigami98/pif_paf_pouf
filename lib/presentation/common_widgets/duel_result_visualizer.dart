import 'package:flutter/material.dart';
import 'package:pif_paf_pouf/data/models/models.dart';
import 'package:pif_paf_pouf/data/services/game_rules_service.dart';
import 'package:pif_paf_pouf/presentation/theme/colors.dart';

class DuelResultVisualizer extends StatelessWidget {
  final List<GameChoice> playerChoices;
  final List<Player> players;
  final String? currentUserId;
  final List<String> eliminatedPlayers;
  final bool isPerfectTie;

  const DuelResultVisualizer({
    super.key,
    required this.playerChoices,
    required this.players,
    this.currentUserId,
    required this.eliminatedPlayers,
    this.isPerfectTie = false,
  });

  @override
  Widget build(BuildContext context) {
    final gameRulesService = GameRulesService();
    final availableChoices = gameRulesService.getAvailableChoices();

    // Vérifier si c'est une égalité parfaite (tous ont fait le même choix)
    if (isPerfectTie && playerChoices.isNotEmpty) {
      // Affichage spécial pour l'égalité parfaite
      return _buildPerfectTieView(gameRulesService, availableChoices);
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          const Text("Résultats des duels", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // Liste des duels
          ...playerChoices.asMap().entries.expand((entry) {
            final idx = entry.key;
            final choice1 = entry.value;

            // Trouver le joueur correspondant
            final player1 = players.firstWhere(
              (p) => p.id == choice1.playerId,
              orElse: () => Player(id: '', name: 'Inconnu', isReady: false, active: false),
            );

            // Trouver le modèle de choix correspondant
            final choiceModel1 = gameRulesService.getChoiceById(choice1.choice) ?? availableChoices.first;

            // Déterminer si le joueur a été éliminé
            final isPlayer1Eliminated = eliminatedPlayers.contains(player1.id);

            return playerChoices.sublist(idx + 1).map((choice2) {
              // Trouver le joueur 2
              final player2 = players.firstWhere(
                (p) => p.id == choice2.playerId,
                orElse: () => Player(id: '', name: 'Inconnu', isReady: false, active: false),
              );

              // Trouver le modèle de choix 2
              final choiceModel2 = gameRulesService.getChoiceById(choice2.choice) ?? availableChoices.first;

              // Déterminer le résultat du duel
              final duelResult = gameRulesService.determineDuelWinner(choiceModel1, choiceModel2);

              // Déterminer si le joueur 2 a été éliminé
              final isPlayer2Eliminated = eliminatedPlayers.contains(player2.id);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Card(
                  elevation: (player1.id == currentUserId || player2.id == currentUserId) ? 3 : 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Joueur 1
                        _buildPlayerChoice(
                          player1.name,
                          choiceModel1,
                          isEliminated: isPlayer1Eliminated,
                          isCurrentUser: player1.id == currentUserId,
                          isWinner: duelResult == GameDuelResult.firstWins,
                          isTie: duelResult == GameDuelResult.tie,
                        ),

                        // Indicateur de résultat
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _getDuelResultColor(duelResult).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(_getDuelResultIcon(duelResult), color: _getDuelResultColor(duelResult), size: 20),
                          ),
                        ),

                        // Joueur 2
                        _buildPlayerChoice(
                          player2.name,
                          choiceModel2,
                          isEliminated: isPlayer2Eliminated,
                          isCurrentUser: player2.id == currentUserId,
                          isWinner: duelResult == GameDuelResult.secondWins,
                          isTie: duelResult == GameDuelResult.tie,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList();
          }),
        ],
      ),
    );
  }

  Widget _buildPerfectTieView(GameRulesService gameRulesService, List<GameChoiceModel> availableChoices) {
    final firstChoice = playerChoices.first.choice;
    final choiceModel = gameRulesService.getChoiceById(firstChoice) ?? availableChoices.first;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Égalité parfaite !",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          "Tous les joueurs ont choisi la même chose",
          style: TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          width: 100,
          height: 100,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: choiceModel.color.withOpacity(0.2), shape: BoxShape.circle),
          child: Image.asset(choiceModel.imagePath, fit: BoxFit.contain),
        ),
        const SizedBox(height: 12),
        Text(choiceModel.displayName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: choiceModel.color)),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children:
              players.where((p) => playerChoices.any((c) => c.playerId == p.id)).map((player) {
                final isCurrentUser = player.id == currentUserId;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCurrentUser ? AppColors.primary.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    player.name,
                    style: TextStyle(
                      fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                      color: isCurrentUser ? AppColors.primary : Colors.black87,
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildPlayerChoice(
    String playerName,
    GameChoiceModel choice, {
    bool isEliminated = false,
    bool isCurrentUser = false,
    bool isWinner = false,
    bool isTie = false,
  }) {
    return Expanded(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 60,
                height: 60,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: choice.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: isCurrentUser ? AppColors.primary : Colors.transparent, width: isCurrentUser ? 2 : 0),
                ),
                child: Image.asset(choice.imagePath),
              ),
              if (isEliminated)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.cancel, color: AppColors.error, size: 16),
                ),
              if (isWinner && !isEliminated)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.emoji_events, color: AppColors.success, size: 16),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            playerName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
              color: isEliminated ? AppColors.textMuted : Colors.black,
              decoration: isEliminated ? TextDecoration.lineThrough : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            choice.displayName,
            style: TextStyle(fontSize: 11, color: choice.color.withOpacity(0.8), fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  IconData _getDuelResultIcon(GameDuelResult result) {
    switch (result) {
      case GameDuelResult.firstWins:
        return Icons.arrow_back;
      case GameDuelResult.secondWins:
        return Icons.arrow_forward;
      case GameDuelResult.tie:
        return Icons.sync;
    }
  }

  Color _getDuelResultColor(GameDuelResult result) {
    switch (result) {
      case GameDuelResult.firstWins:
      case GameDuelResult.secondWins:
        return AppColors.primary;
      case GameDuelResult.tie:
        return Colors.grey;
    }
  }
}
