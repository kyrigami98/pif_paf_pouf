import 'package:flutter/material.dart';
import 'package:pif_paf_pouf/models/models.dart';
import 'package:pif_paf_pouf/services/game_rules_service.dart';
import 'package:pif_paf_pouf/theme/colors.dart';

class PlayerStatusWidget extends StatelessWidget {
  final List<Player> players;
  final String? currentUserId;
  final bool showChoices;

  const PlayerStatusWidget({super.key, required this.players, this.currentUserId, this.showChoices = false});

  @override
  Widget build(BuildContext context) {
    // Trier les joueurs : d'abord l'utilisateur actuel, ensuite par ordre alphabétique
    final sortedPlayers = List<Player>.from(players);
    sortedPlayers.sort((a, b) {
      if (a.id == currentUserId) return -1;
      if (b.id == currentUserId) return 1;
      return a.name.compareTo(b.name);
    });

    // Filtrer les joueurs actifs
    final activePlayers = sortedPlayers.where((p) => p.active).toList();
    final eliminatedPlayers = sortedPlayers.where((p) => !p.active).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // En-tête avec compteur d'actifs et joueurs éliminés
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people, color: AppColors.primary, size: 20),
                    const SizedBox(width: 6),
                    Text("Joueurs", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, size: 12, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text(
                            "${activePlayers.length} actifs",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                    if (eliminatedPlayers.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            const Icon(Icons.cancel, size: 12, color: Colors.redAccent),
                            const SizedBox(width: 4),
                            Text(
                              "${eliminatedPlayers.length} éliminés",
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Joueurs actifs en défilement horizontal
          if (activePlayers.isNotEmpty) _buildPlayersList(activePlayers, isActive: true),

          // Joueurs éliminés (si présents) en défilement horizontal
          if (eliminatedPlayers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 12.0, bottom: 6.0),
              child: Row(
                children: [
                  const Icon(Icons.not_interested, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text("Éliminés", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
                ],
              ),
            ),
            _buildPlayersList(eliminatedPlayers, isActive: false),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayersList(List<Player> playersList, {required bool isActive}) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: playersList.length,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemBuilder: (context, index) {
          return _buildPlayerCard(playersList[index], isActive: isActive);
        },
      ),
    );
  }

  Widget _buildPlayerCard(Player player, {required bool isActive}) {
    final bool isCurrentUser = player.id == currentUserId;
    final bool hasChosen = player.currentChoice != null;

    // Déterminer la couleur de la bordure
    Color borderColor = Colors.transparent;
    if (isCurrentUser) {
      borderColor = AppColors.primary;
    } else if (isActive && hasChosen) {
      borderColor = AppColors.success;
    } else if (!isActive) {
      borderColor = Colors.grey.withOpacity(0.3);
    }

    // Obtenir le choix affiché si nécessaire
    String? choiceDisplayName;
    if (isActive && hasChosen && showChoices && player.currentChoice != null) {
      choiceDisplayName = GameRulesService().getChoiceById(player.currentChoice!)?.displayName;
    }

    return Container(
      width: 60,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar avec statut
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      isActive
                          ? hasChosen
                              ? AppColors.success.withOpacity(0.1)
                              : AppColors.primary.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: isCurrentUser ? 2.5 : (hasChosen ? 1.5 : 0)),
                ),
                child: Center(
                  child: Text(
                    player.initial,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      overflow: TextOverflow.ellipsis,
                      color:
                          isActive
                              ? hasChosen
                                  ? AppColors.success
                                  : AppColors.primary
                              : Colors.grey,
                    ),
                  ),
                ),
              ),

              // Indicateur de statut
              if (isActive)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 2, offset: const Offset(0, 1))],
                  ),
                  child: Icon(
                    hasChosen ? Icons.check_circle : Icons.hourglass_empty,
                    color: hasChosen ? AppColors.success : Colors.orange,
                    size: 12,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.cancel, color: Colors.redAccent, size: 16),
                ),
            ],
          ),

          const SizedBox(height: 6),

          // Nom du joueur (tronqué si trop long)
          Text(
            player.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Colors.black87 : Colors.grey,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),

          // Indicateur de choix ou statut
          if (isActive && hasChosen && showChoices && choiceDisplayName != null)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
              child: Text(
                choiceDisplayName,
                style: const TextStyle(fontSize: 9, color: AppColors.success, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else if (isActive)
            Text(
              hasChosen ? "A choisi" : "En attente",
              style: TextStyle(fontSize: 9, color: hasChosen ? AppColors.success : Colors.orange, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
