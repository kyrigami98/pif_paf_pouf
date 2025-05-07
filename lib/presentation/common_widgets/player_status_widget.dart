import 'package:flutter/material.dart';
import 'package:pif_paf_pouf/data/models/models.dart';
import 'package:pif_paf_pouf/data/services/game_rules_service.dart';
import 'package:pif_paf_pouf/presentation/theme/colors.dart';
import 'package:gap/gap.dart';

class PlayerStatusWidget extends StatelessWidget {
  final List<Player> players;
  final String? currentUserId;
  final bool showChoices;
  final int? roundNumber;

  const PlayerStatusWidget({super.key, required this.players, this.currentUserId, this.showChoices = false, this.roundNumber});

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
        gradient: LinearGradient(
          colors: [Colors.white, Colors.white.withOpacity(0.95)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 5))],
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
                // Titre avec numéro de round
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.people, color: AppColors.primary, size: 18),
                    ),
                    const Gap(8),
                    Text(
                      roundNumber != null ? "Round $roundNumber" : "Joueurs",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                    ),
                  ],
                ),
                // Badges d'information
                Row(
                  children: [
                    _buildStatusBadge(icon: Icons.check_circle, text: "${activePlayers.length} actifs", color: AppColors.success),
                    if (eliminatedPlayers.isNotEmpty)
                      _buildStatusBadge(
                        icon: Icons.cancel,
                        text: "${eliminatedPlayers.length} éliminés",
                        color: Colors.redAccent,
                        margin: const EdgeInsets.only(left: 8),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const Gap(12),

          // Joueurs actifs en défilement horizontal
          if (activePlayers.isNotEmpty) _buildPlayersList(activePlayers, isActive: true),

          // Joueurs éliminés (si présents) en défilement horizontal
          if (eliminatedPlayers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 12.0, bottom: 6.0),
              child: Row(
                children: [
                  const Icon(Icons.not_interested, size: 14, color: Colors.grey),
                  const Gap(4),
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

  Widget _buildStatusBadge({
    required IconData icon,
    required String text,
    required Color color,
    EdgeInsets margin = EdgeInsets.zero,
  }) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const Gap(4),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildPlayersList(List<Player> playersList, {required bool isActive}) {
    return SizedBox(
      height: 110,
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
      width: 70,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar avec statut
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors:
                        isActive
                            ? hasChosen
                                ? [AppColors.success.withOpacity(0.7), AppColors.success.withOpacity(0.3)]
                                : [AppColors.primary.withOpacity(0.7), AppColors.primary.withOpacity(0.3)]
                            : [Colors.grey.withOpacity(0.5), Colors.grey.withOpacity(0.2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: isCurrentUser ? 2.5 : (hasChosen ? 1.5 : 0)),
                  boxShadow:
                      isCurrentUser || (isActive && hasChosen)
                          ? [
                            BoxShadow(
                              color: isCurrentUser ? AppColors.primary.withOpacity(0.3) : AppColors.success.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                          : null,
                ),
                child: Center(
                  child: Text(
                    player.initial,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      overflow: TextOverflow.ellipsis,
                      color: Colors.white,
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
                    size: 14,
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

          const Gap(6),

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

          // Score du joueur
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withOpacity(0.7), AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, size: 10, color: Colors.white),
                const Gap(2),
                Text(
                  "${player.score} pts",
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Colors.white),
                ),
              ],
            ),
          ),

          // Indicateur de choix ou statut
          if (isActive && hasChosen && showChoices && choiceDisplayName != null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Text(
                choiceDisplayName,
                style: const TextStyle(fontSize: 9, color: AppColors.success, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else if (isActive)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: hasChosen ? AppColors.success.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: hasChosen ? AppColors.success.withOpacity(0.2) : Colors.orange.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasChosen ? Icons.check : Icons.access_time,
                    size: 8,
                    color: hasChosen ? AppColors.success : Colors.orange,
                  ),
                  const Gap(2),
                  Text(
                    hasChosen ? "A choisi" : "En attente",
                    style: TextStyle(
                      fontSize: 9,
                      color: hasChosen ? AppColors.success : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
