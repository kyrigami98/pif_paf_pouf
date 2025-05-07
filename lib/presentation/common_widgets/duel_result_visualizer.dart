import 'package:flutter/material.dart';
import 'package:pif_paf_pouf/data/models/game/game_choice_model.dart';
import 'package:pif_paf_pouf/data/models/user/player.dart';
import 'package:pif_paf_pouf/data/services/game_rules_service.dart';
import 'package:pif_paf_pouf/presentation/theme/colors.dart';
import 'package:gap/gap.dart';
import 'package:lottie/lottie.dart';

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
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withOpacity(0.7), AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_kabaddi, color: Colors.white, size: 20),
                Gap(8),
                Text("Résultats des duels", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),

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
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Card(
                  elevation: (player1.id == currentUserId || player2.id == currentUserId) ? 4 : 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  shadowColor:
                      (player1.id == currentUserId || player2.id == currentUserId)
                          ? AppColors.primary.withOpacity(0.5)
                          : Colors.black.withOpacity(0.1),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient:
                          (player1.id == currentUserId || player2.id == currentUserId)
                              ? LinearGradient(
                                colors: [AppColors.primaryLight, Colors.white],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                              : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(12.0),
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
                            gradient: LinearGradient(
                              colors: _getDuelResultGradient(duelResult),
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _getDuelResultColor(duelResult).withOpacity(0.3),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(child: Icon(_getDuelResultIcon(duelResult), color: Colors.white, size: 20)),
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
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const Gap(10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, color: Colors.amber, size: 16),
              Gap(8),
              Flexible(
                child: Text("Tous les joueurs ont choisi la même chose", style: TextStyle(fontSize: 14, color: Colors.amber)),
              ),
            ],
          ),
        ),
        const Gap(24),
        Container(
          width: 120,
          height: 120,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [choiceModel.color.withOpacity(0.7), choiceModel.color.withOpacity(0.3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: choiceModel.color.withOpacity(0.3), blurRadius: 15, spreadRadius: 5)],
          ),
          child: Image.asset(choiceModel.imagePath, fit: BoxFit.contain),
        ),
        const Gap(12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: choiceModel.color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: choiceModel.color.withOpacity(0.3)),
          ),
          child: Text(
            choiceModel.displayName,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: choiceModel.color),
          ),
        ),
        const Gap(30),
        const Text("Joueurs à égalité :", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const Gap(10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children:
              players.where((p) => playerChoices.any((c) => c.playerId == p.id)).map((player) {
                final isCurrentUser = player.id == currentUserId;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors:
                          isCurrentUser
                              ? [AppColors.primary.withOpacity(0.7), AppColors.primary]
                              : [Colors.grey.shade200, Colors.grey.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow:
                        isCurrentUser
                            ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 2))]
                            : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: isCurrentUser ? Colors.white : AppColors.primary.withOpacity(0.2),
                        child: Text(
                          player.initial,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isCurrentUser ? AppColors.primary : Colors.black87,
                          ),
                        ),
                      ),
                      const Gap(8),
                      Text(
                        player.name,
                        style: TextStyle(
                          fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                          color: isCurrentUser ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ),
        const Gap(20),
        FractionallySizedBox(widthFactor: 0.7, child: Lottie.asset('assets/lottie/tie.json', height: 100)),
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
                  gradient: LinearGradient(
                    colors: [choice.color.withOpacity(0.7), choice.color.withOpacity(0.3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: isCurrentUser ? AppColors.primary : Colors.transparent, width: isCurrentUser ? 2 : 0),
                  boxShadow: [BoxShadow(color: choice.color.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))],
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
          const Gap(6),
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

  List<Color> _getDuelResultGradient(GameDuelResult result) {
    final baseColor = _getDuelResultColor(result);
    return [baseColor.withOpacity(0.7), baseColor];
  }
}
