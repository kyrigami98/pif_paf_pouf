import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:pif_paf_pouf/app/app_keys.dart';
import 'package:pif_paf_pouf/app/routes.dart';
import 'package:pif_paf_pouf/services/firebase_service.dart';
import 'package:pif_paf_pouf/theme/colors.dart';
import 'dart:math';
import 'package:gap/gap.dart';

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
  String _roomCode = "";
  bool _isHost = false;
  bool _gameStarting = false;

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

      // Charger le code de la room
      final roomDoc = await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).get();

      if (roomDoc.exists && mounted) {
        setState(() {
          _roomCode = roomDoc.data()?['roomCode'] ?? '';
        });
      }
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
        context.go(RouteList.home);
      }
    } catch (e) {
      _showErrorMessage("Erreur lors de la sortie de la room: $e");
    }
  }

  void _copyRoomCode() {
    Clipboard.setData(ClipboardData(text: _roomCode)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code copié dans le presse-papier")));
    });
  }

  void _checkAllPlayersReady(List<Map<String, dynamic>> players) {
    if (players.isEmpty) return;

    final allReady = players.every((player) => player['isReady'] == true);
    final hasEnoughPlayers = players.length >= 2;

    if (allReady && hasEnoughPlayers && !_gameStarting) {
      setState(() {
        _allPlayersReady = true;
        _gameStarting = true;
      });

      // Si tous les joueurs sont prêts, on pourrait démarrer le jeu
      _showInfoMessage("Tous les joueurs sont prêts! Le jeu va commencer...");

      // Démarrage du jeu après un délai
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          // Naviguer vers l'écran de jeu
          context.goNamed(RouteNames.game, queryParameters: {'roomId': widget.roomId});
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
    return WillPopScope(
      onWillPop: () async {
        _leaveRoom();
        return false; // Empêcher le retour arrière standard
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text("Lobby", style: TextStyle(color: AppColors.onPrimary, fontFamily: 'Chewy')),
          backgroundColor: AppColors.primary,
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.onPrimary), onPressed: _leaveRoom),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).snapshots(),
          builder: (context, roomSnapshot) {
            if (roomSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (roomSnapshot.hasError || !roomSnapshot.hasData || !roomSnapshot.data!.exists) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Cette room n'existe plus", style: TextStyle(fontSize: 18)),
                    const Gap(20),
                    ElevatedButton(onPressed: () => context.go(RouteList.home), child: const Text("Retour à l'accueil")),
                  ],
                ),
              );
            }

            // Vérifier si la partie a commencé
            final roomData = roomSnapshot.data!.data() as Map<String, dynamic>;
            if (roomData['gameStarted'] == true && !_gameStarting) {
              // Rediriger vers l'écran de jeu si ce n'est pas déjà fait
              Future.microtask(() {
                context.goNamed(RouteNames.game, queryParameters: {'roomId': widget.roomId});
              });
            }

            return StreamBuilder<QuerySnapshot>(
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
                      return {
                        'id': doc.id,
                        'username': data['username'] ?? 'Joueur inconnu',
                        'isReady': data['isReady'] ?? false,
                        'isHost': data['isHost'] ?? false,
                      };
                    }).toList();

                // Vérifier si je suis l'hôte de la room
                if (_currentUserId != null) {
                  final currentPlayer = _players.firstWhere(
                    (player) => player['id'] == _currentUserId,
                    orElse: () => {'isReady': false, 'isHost': false},
                  );
                  _isReady = currentPlayer['isReady'] ?? false;
                  _isHost = currentPlayer['isHost'] ?? false;
                }

                // Vérifier si tous les joueurs sont prêts
                _checkAllPlayersReady(_players);

                return Column(
                  children: [
                    // Code de la room
                    if (_roomCode.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          color: AppColors.primaryLight,
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Column(
                                  children: [
                                    const Text(
                                      "CODE DE LA PARTIE",
                                      style: TextStyle(fontSize: 14, color: AppColors.primaryDark, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      _roomCode,
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 4,
                                        color: AppColors.primary,
                                        fontFamily: 'Chewy',
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(icon: const Icon(Icons.copy, color: AppColors.primary), onPressed: _copyRoomCode),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Nombre de joueurs
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("${_players.length}/6 joueurs", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(
                            _allPlayersReady ? "Tous prêts !" : "En attente...",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _allPlayersReady ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Joueurs dans la room
                    Expanded(child: _players.length >= 6 ? _buildPlayersGrid() : _buildPlayersRadar()),

                    // Bouton Prêt
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: ElevatedButton(
                        onPressed: _gameStarting ? null : _toggleReadyStatus,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isReady ? Colors.green : AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          disabledBackgroundColor: Colors.green.withOpacity(0.5),
                          minimumSize: const Size.fromHeight(60),
                        ),
                        child: Text(
                          _isReady ? "PRÊT !" : "JE SUIS PRÊT",
                          style: const TextStyle(fontSize: 18, fontFamily: 'Chewy'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
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

            // Cercle milieu
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1.5),
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: player['isReady'] ? Colors.green : AppColors.primary,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 3, offset: const Offset(0, 1))],
            ),
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

          // Badge hôte
          if (player['isHost'])
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(10)),
              child: const Text("HÔTE", style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
            ),

          // Statut
          Text(
            player['isReady'] ? "Prêt" : "En attente",
            style: TextStyle(fontSize: 10, color: player['isReady'] ? Colors.green : Colors.orange, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
