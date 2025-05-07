import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:pif_paf_pouf/app/app_keys.dart';
import 'package:pif_paf_pouf/app/routes.dart';
import 'package:pif_paf_pouf/data/services/firebase_service.dart';
import 'package:pif_paf_pouf/data/services/room_service.dart';
import 'package:pif_paf_pouf/presentation/theme/colors.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'dart:math';

class LobbyScreen extends StatefulWidget {
  final String roomId;

  const LobbyScreen({super.key, required this.roomId});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final RoomService _roomService = RoomService(FirebaseFirestore.instance);

  String? _currentUserId;
  bool _isReady = false;
  bool _allPlayersReady = false;
  List<Map<String, dynamic>> _players = [];
  String _joinCode = "";
  bool _isHost = false;
  bool _gameStarting = false;
  bool _shouldCheckReadyStatus = false;

  // Animations
  late AnimationController _codeAnimController;
  late Animation<double> _codeAnimation;
  late AnimationController _buttonAnimController;
  late Animation<double> _buttonAnimation;
  late AnimationController _playerAnimController;
  Timer? _confettiTimer;

  @override
  void initState() {
    super.initState();
    _initialize();

    // Code de salle animation
    _codeAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _codeAnimation = CurvedAnimation(parent: _codeAnimController, curve: Curves.easeOutBack);
    _codeAnimController.forward();

    // Bouton animation
    _buttonAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
      reverseDuration: const Duration(milliseconds: 1000),
    );
    _buttonAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.05), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 1.05, end: 1.0), weight: 1),
    ]).animate(_buttonAnimController);
    _buttonAnimController.repeat(reverse: true);

    // Animation des joueurs
    _playerAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  }

  @override
  void dispose() {
    _codeAnimController.dispose();
    _buttonAnimController.dispose();
    _playerAnimController.dispose();
    _confettiTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    final userId = _firebaseService.getCurrentUserId();
    if (userId != null) {
      setState(() {
        _currentUserId = userId;
      });

      await _roomService.updatePlayerStatus(widget.roomId, userId, false);

      final roomDoc = await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).get();

      if (roomDoc.exists && mounted) {
        setState(() {
          _joinCode = roomDoc.data()?['joinCode'] ?? '';
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shouldCheckReadyStatus) {
      _shouldCheckReadyStatus = false;
      Future.microtask(() => _checkAllPlayersReady(_players));
    }
  }

  Future<void> _toggleReadyStatus() async {
    if (_currentUserId == null) return;

    final newStatus = !_isReady;
    await _roomService.updatePlayerStatus(widget.roomId, _currentUserId!, newStatus);

    setState(() {
      _isReady = newStatus;
    });

    // Feedback tactile et visuel
    HapticFeedback.mediumImpact();
  }

  Future<void> _leaveRoom() async {
    if (_currentUserId == null) return;

    try {
      await _roomService.removePlayerFromRoom(widget.roomId, _currentUserId!);
      if (mounted) {
        HapticFeedback.mediumImpact();
        context.go(RouteList.home);
      }
    } catch (e) {
      _showErrorMessage("Erreur lors de la sortie de la room: $e");
    }
  }

  void _copyRoomCode() {
    Clipboard.setData(ClipboardData(text: _joinCode)).then((_) {
      HapticFeedback.selectionClick();
      _showInfoMessage("Code copié dans le presse-papier");
    });
  }

  void _checkAllPlayersReady(List<Map<String, dynamic>> players) {
    if (players.isEmpty) return;

    final allReady = players.every((player) => player['isReady'] == true);
    final hasEnoughPlayers = players.length >= 2;

    final shouldStartGame = allReady && hasEnoughPlayers && !_gameStarting;

    if (shouldStartGame || allReady != _allPlayersReady) {
      setState(() {
        _allPlayersReady = allReady && hasEnoughPlayers;

        if (shouldStartGame) {
          _gameStarting = true;

          // Feedback et animation
          HapticFeedback.heavyImpact();
          _showCountdown();

          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              context.goNamed(RouteNames.game, queryParameters: {'roomId': widget.roomId});
            }
          });
        }
      });
    }
  }

  void _showCountdown() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.primary.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "TOUS LES JOUEURS SONT PRÊTS!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 20),
              Lottie.asset('assets/lottie/countdown.json', width: 120, height: 120, repeat: true),
              const SizedBox(height: 10),
              const Text("La partie commence...", style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        );
      },
    );

    // Activer les confettis
    _confettiTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      HapticFeedback.lightImpact();
    });
  }

  void _showErrorMessage(String message) {
    HapticFeedback.vibrate();
    alertKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showInfoMessage(String message) {
    alertKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _leaveRoom();
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.group, color: AppColors.onPrimary),
              const SizedBox(width: 8),
              const Text("Salle d'attente", style: TextStyle(color: AppColors.onPrimary)),
            ],
          ),
          elevation: 0,
          backgroundColor: AppColors.primary,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.onPrimary),
            onPressed: () {
              HapticFeedback.lightImpact();
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text("Quitter la salle ?"),
                      content: const Text("Voulez-vous vraiment quitter cette salle d'attente ?"),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _leaveRoom();
                          },
                          child: Text("Quitter", style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
              );
            },
          ),
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
                    Lottie.asset('assets/lottie/error.json', width: 150, height: 150),
                    const Text("Cette salle n'existe plus", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => context.go(RouteList.home),
                      icon: const Icon(Icons.home),
                      label: const Text("RETOUR À L'ACCUEIL"),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                    ),
                  ],
                ),
              );
            }

            final roomData = roomSnapshot.data!.data() as Map<String, dynamic>;
            if (roomData['status'] == 'in_game' && !_gameStarting) {
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
                  return const Center(child: Text("Aucun joueur dans cette salle"));
                }

                final players =
                    snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return {
                        'id': doc.id,
                        'username': data['name'] ?? 'Joueur inconnu',
                        'isReady': data['ready'] ?? false,
                        'isHost': data['isHost'] ?? false,
                      };
                    }).toList();

                if (_currentUserId != null) {
                  final currentPlayer = players.firstWhere(
                    (player) => player['id'] == _currentUserId,
                    orElse: () => {'isReady': false, 'isHost': false},
                  );
                  _isReady = currentPlayer['isReady'] ?? false;
                  _isHost = currentPlayer['isHost'] ?? false;
                }

                if (_players.toString() != players.toString()) {
                  _players = players;
                  _shouldCheckReadyStatus = true;
                  _playerAnimController.reset();
                  _playerAnimController.forward();
                }

                return SafeArea(
                  child: Column(
                    children: [
                      // Code de salle animé
                      ScaleTransition(
                        scale: _codeAnimation,
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.9,
                          margin: const EdgeInsets.symmetric(vertical: 16),
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "CODE DE LA PARTIE",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _joinCode,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      letterSpacing: 5,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: _copyRoomCode,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.copy_rounded, color: Colors.white, size: 28),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Statut et joueurs
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(color: AppColors.cardDark, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.people, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  "${players.length}/6 joueurs",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _allPlayersReady ? AppColors.success.withOpacity(0.2) : AppColors.warning.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _allPlayersReady ? Icons.check_circle : Icons.hourglass_empty,
                                    size: 16,
                                    color: _allPlayersReady ? AppColors.success : AppColors.warning,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _allPlayersReady ? "Tous prêts !" : "En attente...",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _allPlayersReady ? AppColors.success : AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Liste des joueurs
                      Expanded(child: FadeTransition(opacity: _playerAnimController, child: _buildPlayersList(players))),

                      // Bouton prêt avec animation
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                        child: ScaleTransition(
                          scale: _isReady ? const AlwaysStoppedAnimation(1.0) : _buttonAnimation,
                          child: Container(
                            width: double.infinity,
                            height: 70,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors:
                                    _isReady
                                        ? [AppColors.success, AppColors.success.withGreen(180)]
                                        : [AppColors.primary, AppColors.primaryDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isReady ? AppColors.success : AppColors.primary).withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _gameStarting ? null : _toggleReadyStatus,
                                borderRadius: BorderRadius.circular(16),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(_isReady ? Icons.check_circle : Icons.play_circle_fill, color: Colors.white, size: 28),
                                      const SizedBox(width: 12),
                                      Text(
                                        _isReady ? "PRÊT !" : "JE SUIS PRÊT",
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlayersList(List<Map<String, dynamic>> players) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: players.length,
          separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.transparent),
          itemBuilder: (context, index) {
            final player = players[index];
            final isCurrentUser = player['id'] == _currentUserId;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: isCurrentUser ? AppColors.primaryLight : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: player['isReady'] ? AppColors.success : AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (player['isReady'] ? AppColors.success : AppColors.primary).withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          player['username'].substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    if (player['isReady'])
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                      ),
                  ],
                ),
                title: Row(
                  children: [
                    Text(
                      player['username'],
                      style: TextStyle(
                        fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                        fontSize: 16,
                        color: isCurrentUser ? AppColors.primary : AppColors.onBackground,
                      ),
                    ),
                    if (isCurrentUser)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "VOUS",
                          style: TextStyle(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                subtitle: Text(
                  player['isReady'] ? "Prêt à jouer" : "En attente...",
                  style: TextStyle(fontSize: 12, color: player['isReady'] ? AppColors.success : AppColors.textMuted),
                ),
                trailing:
                    player['isHost']
                        ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stars, size: 14, color: AppColors.secondary),
                              SizedBox(width: 4),
                              Text(
                                "HÔTE",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary),
                              ),
                            ],
                          ),
                        )
                        : null,
              ),
            );
          },
        ),
      ),
    );
  }
}
