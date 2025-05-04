import 'package:flutter/material.dart';
import 'package:pif_paf_pouf/models/models.dart';
import 'package:pif_paf_pouf/theme/colors.dart';

class PlayerStatusWidget extends StatelessWidget {
  final List<Player> players;
  final String? currentUserId;
  final bool showChoices;

  const PlayerStatusWidget({Key? key, required this.players, this.currentUserId, this.showChoices = false}) : super(key: key);

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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Joueurs", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  "${activePlayers.length} actifs",
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Joueurs actifs
          if (activePlayers.isNotEmpty) ...[
            const Divider(height: 1),
            for (final player in activePlayers) _buildPlayerTile(player, isActive: true),
          ],

          // Joueurs éliminés
          if (eliminatedPlayers.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text("Éliminés", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
            const Divider(height: 8),
            for (final player in eliminatedPlayers) _buildPlayerTile(player, isActive: false),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerTile(Player player, {required bool isActive}) {
    final bool isCurrentUser = player.id == currentUserId;
    final bool hasChosen = player.currentChoice != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Avatar
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color:
                      isActive
                          ? hasChosen
                              ? AppColors.success
                              : AppColors.primary
                          : Colors.grey,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    player.initial,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              if (!isActive)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                  child: const Center(child: Icon(Icons.close, size: 18, color: Colors.white)),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Nom et statut
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      player.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? Colors.black87 : Colors.grey,
                      ),
                    ),
                    if (isCurrentUser)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "VOUS",
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                  ],
                ),
                if (!isActive)
                  const Text("Éliminé", style: TextStyle(fontSize: 12, color: Colors.red))
                else if (hasChosen && showChoices)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getChoiceDisplayName(player.currentChoice!),
                          style: const TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    hasChosen ? "A fait son choix" : "En réflexion...",
                    style: TextStyle(fontSize: 12, color: hasChosen ? AppColors.success : Colors.orange),
                  ),
              ],
            ),
          ),

          // Indicateur de statut
          if (isActive)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: hasChosen ? AppColors.success : Colors.orange, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }

  String _getChoiceDisplayName(String choice) {
    switch (choice) {
      case 'pierre':
        return 'Pierre';
      case 'papier':
        return 'Papier';
      case 'ciseaux':
        return 'Ciseaux';
      default:
        return 'Inconnu';
    }
  }
}
