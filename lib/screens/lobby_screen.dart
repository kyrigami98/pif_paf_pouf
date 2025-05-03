import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:pif_paf_pouf/app/app_keys.dart';
import 'package:pif_paf_pouf/services/firebase_service.dart';
import 'package:pif_paf_pouf/theme/colors.dart';
// Pour résoudre les références manquantes
import 'dart:math';

class LobbyScreen extends StatefulWidget {
  final String roomId;

  const LobbyScreen({super.key, required this.roomId});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  String? _currentUserId;
  bool _isReady = false;
  bool _allPlayersReady = false;
  List<Map<String, dynamic>> _players = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final userId = _firebaseService.getCurrentUserId();
    if (userId != null) {
      setState(() {
        _currentUserId = userId;
      });

      // Mettre à jour le statut du joueur quand il rejoint le lobby
      await _firebaseService.updatePlayerStatus(widget.roomId, userId, false);
    }
  }

  Future<void> _toggleReadyStatus() async {
    if (_currentUserId == null) return;

    final newStatus = !_isReady;
    await _firebaseService.updatePlayerStatus(widget.roomId, _currentUserId!, newStatus);

    setState(() {
      _isReady = newStatus;
    });
  }

  Future<void> _leaveRoom() async {
    if (_currentUserId == null) return;

    try {
      await _firebaseService.removePlayerFromRoom(widget.roomId, _currentUserId!);
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      _showErrorMessage("Erreur lors de la sortie de la room: $e");
    }
  }

  void _checkAllPlayersReady(List<Map<String, dynamic>> players) {
    if (players.isEmpty) return;

    final allReady = players.every((player) => player['isReady'] == true);

    if (allReady && players.length >= 2) {
      setState(() {
        _allPlayersReady = true;
      });

      // Si tous les joueurs sont prêts, on pourrait démarrer le jeu
      _showInfoMessage("Tous les joueurs sont prêts! Le jeu va bientôt commencer...");

      // Démarrage du jeu après un délai
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          // Naviguer vers l'écran de jeu (à implémenter)
          // context.push('/game/${widget.roomId}');
        }
      });
    } else {
      setState(() {
        _allPlayersReady = false;
      });
    }
  }

  void _showErrorMessage(String message) {
    alertKey.currentState?.showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showInfoMessage(String message) {
    alertKey.currentState?.showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.primary));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Lobby", style: TextStyle(color: AppColors.onPrimary)),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.onPrimary), onPressed: _leaveRoom),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).collection('players').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Erreur: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Aucun joueur dans cette room"));
          }

          // Récupérer les données des joueurs
          _players =
              snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return {'id': doc.id, 'username': data['username'] ?? 'Joueur inconnu', 'isReady': data['isReady'] ?? false};
              }).toList();

          // Mise à jour du statut du joueur actuel
          if (_currentUserId != null) {
            final currentPlayer = _players.firstWhere(
              (player) => player['id'] == _currentUserId,
              orElse: () => {'isReady': false},
            );
            _isReady = currentPlayer['isReady'] ?? false;
          }

          // Vérifier si tous les joueurs sont prêts
          _checkAllPlayersReady(_players);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("Room ID: ${widget.roomId}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),

              // Joueurs dans la room
              Expanded(child: _players.length >= 6 ? _buildPlayersGrid() : _buildPlayersRadar()),

              // Bouton Prêt
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: ElevatedButton(
                  onPressed: _allPlayersReady ? null : _toggleReadyStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isReady ? Colors.green : AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    disabledBackgroundColor: Colors.green.withOpacity(0.5),
                  ),
                  child: Text(_isReady ? "Prêt !" : "Je suis prêt", style: const TextStyle(fontSize: 18)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlayersGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _players.length,
      itemBuilder: (context, index) {
        final player = _players[index];
        return _buildPlayerAvatar(player);
      },
    );
  }

  Widget _buildPlayersRadar() {
    return Center(
      child: SizedBox(
        width: 300,
        height: 300,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Cercle extérieur
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
              ),
            ),

            // Positionner les avatars des joueurs en cercle
            ..._positionPlayersInCircle(),

            // Cercle central
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryLight),
              child: Center(
                child: Text(
                  "${_players.length}/6",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _positionPlayersInCircle() {
    const radius = 120.0; // Rayon du cercle
    final center = const Offset(150, 150);
    final widgets = <Widget>[];

    for (int i = 0; i < _players.length; i++) {
      final player = _players[i];
      final angle = 2 * pi * i / max(1, _players.length);
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);

      widgets.add(Positioned(left: x - 40, top: y - 40, child: _buildPlayerAvatar(player)));
    }

    return widgets;
  }

  Widget _buildPlayerAvatar(Map<String, dynamic> player) {
    final isCurrentUser = player['id'] == _currentUserId;

    return Container(
      width: 80,
      height: 100,
      decoration: BoxDecoration(
        color: isCurrentUser ? AppColors.primaryLight : Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(shape: BoxShape.circle, color: player['isReady'] ? Colors.green : AppColors.primary),
            child: Center(
              child: Text(
                player['username'].substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 5),

          // Nom du joueur
          Text(
            player['username'],
            style: TextStyle(
              fontSize: 12,
              fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
              color: isCurrentUser ? AppColors.primary : Colors.black,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),

          // Statut
          Text(
            player['isReady'] ? "Prêt" : "En attente",
            style: TextStyle(fontSize: 10, color: player['isReady'] ? Colors.green : Colors.orange),
          ),
        ],
      ),
    );
  }
}
