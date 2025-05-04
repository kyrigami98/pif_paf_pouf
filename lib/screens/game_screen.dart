import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:pif_paf_pouf/app/app_keys.dart';
import 'package:pif_paf_pouf/app/routes.dart';
import 'package:pif_paf_pouf/services/firebase_service.dart';
import 'package:pif_paf_pouf/models/models.dart';
import 'package:pif_paf_pouf/theme/colors.dart';
import 'dart:async';
import 'package:lottie/lottie.dart';

class GameScreen extends StatefulWidget {
  final String roomId;

  const GameScreen({super.key, required this.roomId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  String? _currentUserId;
  Choice? _selectedChoice;
  bool _choiceLocked = false;
  bool _showResults = false;
  int _currentRound = 1;
  Room? _room;
  List<Player> _players = [];
  RoundResult? _roundResult;

  // Animation pour le compte à rebours
  late AnimationController _countdownController;
  late Animation<double> _countdownAnimation;
  late Animation<double> _pulseAnimation;
  final List<String> _countdownTexts = ['Pif...', 'Paf...', 'Pouf!'];
  int _countdownIndex = 0;
  bool _countdownActive = false;

  // Animation pour les résultats
  late AnimationController _resultsController;
  late Animation<double> _resultsAnimation;

  // Animation pour les choix
  late AnimationController _choiceController;
  late Animation<double> _choiceAnimation;

  // Streams subscriptions
  StreamSubscription? _roomSubscription;
  StreamSubscription? _playersSubscription;
  StreamSubscription? _roundResultSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();

    // Initialiser l'animation de compte à rebours
    _countdownController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (_countdownIndex < _countdownTexts.length - 1) {
            _countdownIndex++;
            _countdownController.reset();
            _countdownController.forward();
          } else if (_countdownIndex == _countdownTexts.length - 1) {
            // Après "Pouf!", on peut choisir
            setState(() {
              _countdownActive = false;
              _choiceLocked = false;
            });
            // Vibrer pour indiquer que c'est le moment de choisir
            HapticFeedback.heavyImpact();
            // Démarrer l'animation des choix
            _choiceController.forward();
          }
        }
      });

    _countdownAnimation = CurvedAnimation(parent: _countdownController, curve: Curves.elasticOut);
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.2), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _countdownController, curve: const Interval(0.5, 1.0, curve: Curves.easeInOut)));

    // Initialiser l'animation des résultats
    _resultsController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _resultsAnimation = CurvedAnimation(parent: _resultsController, curve: Curves.elasticOut);

    // Initialiser l'animation des choix
    _choiceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _choiceAnimation = CurvedAnimation(parent: _choiceController, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _playersSubscription?.cancel();
    _roundResultSubscription?.cancel();
    _countdownController.dispose();
    _resultsController.dispose();
    _choiceController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final userId = _firebaseService.getCurrentUserId();
    if (userId != null) {
      setState(() {
        _currentUserId = userId;
      });
    }

    // S'abonner aux changements de la room
    _subscribeToRoom();

    // S'abonner aux changements des joueurs
    _subscribeToPlayers();
  }

  void _subscribeToRoom() {
    _roomSubscription = _firebaseService
        .roomStream(widget.roomId)
        .listen(
          (room) {
            if (mounted) {
              setState(() {
                _room = room;

                // Si le numéro de round a changé, réinitialiser l'état
                if (_room!.currentRound != _currentRound) {
                  _currentRound = _room!.currentRound;
                  _selectedChoice = null;
                  _choiceLocked = false;
                  _showResults = false;
                  _roundResult = null;

                  // Annuler l'ancienne subscription au round et en créer une nouvelle
                  _roundResultSubscription?.cancel();
                  _subscribeToRoundResult();

                  // Commencer le compte à rebours pour le nouveau round
                  _startCountdown();
                }

                // Vérifier s'il y a un gagnant final
                if (_room!.winner != null && _room!.status == RoomStatus.completed) {
                  setState(() {
                    _showResults = true;
                  });
                  _resultsController.forward();
                }
              });
            }
          },
          onError: (e) {
            debugPrint('Erreur dans le stream de room: $e');
            if (mounted) {
              _showErrorMessage("Erreur de connexion avec la partie");
            }
          },
        );
  }

  void _subscribeToPlayers() {
    _playersSubscription = _firebaseService
        .playersStream(widget.roomId)
        .listen(
          (players) {
            if (mounted) {
              setState(() {
                _players = players;
              });
            }
          },
          onError: (e) {
            debugPrint('Erreur dans le stream de joueurs: $e');
          },
        );
  }

  void _subscribeToRoundResult() {
    _roundResultSubscription = _firebaseService
        .roundResultStream(widget.roomId, _currentRound)
        .listen(
          (result) {
            if (result != null && result.completed && !_showResults && mounted) {
              setState(() {
                _roundResult = result;
                _showResults = true;
              });
              _resultsController.forward();
              HapticFeedback.mediumImpact();
            }
          },
          onError: (e) {
            debugPrint('Erreur dans le stream du résultat de round: $e');
          },
        );
  }

  void _startCountdown() {
    setState(() {
      _countdownIndex = 0;
      _countdownActive = true;
      _choiceLocked = true;
    });

    // Réinitialiser les animations
    _countdownController.reset();
    _choiceController.reset();
    _countdownController.forward();
  }

  Future<void> _makeChoice(Choice choice) async {
    if (_choiceLocked || _showResults || _selectedChoice != null) return;

    setState(() {
      _selectedChoice = choice;
      _choiceLocked = true;
    });

    try {
      // Donner un feedback tactile à la sélection
      HapticFeedback.selectionClick();

      // Envoyer le choix à Firebase sous forme de string
      await _firebaseService.makeChoice(widget.roomId, _currentUserId!, choice.name);

      // Vérifier si tous les joueurs ont fait leur choix
      bool allMadeChoice = await _firebaseService.checkAllChoicesMade(widget.roomId);

      if (allMadeChoice) {
        // Déterminer le gagnant si tous les joueurs ont choisi
        await _firebaseService.determineWinner(widget.roomId);
      }
    } catch (e) {
      _showErrorMessage("Erreur: $e");
      setState(() {
        _selectedChoice = null;
        _choiceLocked = false;
      });
    }
  }

  Future<void> _readyForNextRound() async {
    try {
      // Donner un feedback tactile
      HapticFeedback.mediumImpact();

      // Réinitialiser l'état local
      setState(() {
        _selectedChoice = null;
        _showResults = false;
        _roundResult = null;
      });

      // Marquer comme prêt pour le prochain round
      await _firebaseService.updatePlayerStatus(widget.roomId, _currentUserId!, true);
    } catch (e) {
      _showErrorMessage("Erreur: $e");
    }
  }

  void _exitGame() {
    HapticFeedback.mediumImpact();
    _firebaseService.removePlayerFromRoom(widget.roomId, _currentUserId!);
    context.go(RouteList.home);
  }

  void _showErrorMessage(String message) {
    alertKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
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
        margin: const EdgeInsets.all(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Vérifier si la room a été supprimée
    if (_room == null) {
      return Scaffold(
        backgroundColor: AppColors.primaryLight,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/error.json', width: 200, height: 200),
              const Text("Cette partie n'existe plus", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.go(RouteList.home),
                icon: const Icon(Icons.home),
                label: const Text("RETOUR À L'ACCUEIL"),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              ),
            ],
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        // Empêcher le retour arrière accidentel
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [const Icon(Icons.sports_esports, size: 24), const SizedBox(width: 8), Text("Round $_currentRound")],
          ),
          backgroundColor: AppColors.primary,
          centerTitle: true,
          automaticallyImplyLeading: false,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: () {
                HapticFeedback.lightImpact();
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text("Quitter la partie ?"),
                        content: const Text("Voulez-vous vraiment quitter la partie ?"),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _exitGame();
                            },
                            child: Text("Quitter", style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                );
              },
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primaryLight.withOpacity(0.3), AppColors.background],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Phase de compte à rebours
              if (_countdownActive)
                Expanded(
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _countdownController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: ScaleTransition(
                            scale: _countdownAnimation,
                            child: Text(
                              _countdownTexts[_countdownIndex],
                              style: TextStyle(
                                fontSize: 60,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                letterSpacing: 2,
                                shadows: [
                                  Shadow(color: AppColors.primary.withOpacity(0.3), offset: const Offset(0, 4), blurRadius: 8),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // Phase de jeu
              if (!_countdownActive && !_showResults)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Faites votre choix !",
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 40),

                      SizeTransition(
                        sizeFactor: _choiceAnimation,
                        axis: Axis.horizontal,
                        axisAlignment: 0.0,
                        child: FadeTransition(
                          opacity: _choiceAnimation,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildChoiceButton(Choice.pierre),
                              _buildChoiceButton(Choice.papier),
                              _buildChoiceButton(Choice.ciseaux),
                            ],
                          ),
                        ),
                      ),

                      if (_selectedChoice != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 30),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedChoice!.color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _selectedChoice!.color, width: 2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_selectedChoice!.emoji, style: const TextStyle(fontSize: 28)),
                                const SizedBox(width: 10),
                                Text(
                                  "Vous avez choisi: ${_selectedChoice!.displayName}",
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 40),

                      // Liste des joueurs participants
                      const Text("Joueurs:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),

                      // Afficher les avatars des joueurs
                      _buildPlayerStatusList(),
                    ],
                  ),
                ),

              // Phase de résultats
              if (_showResults)
                Expanded(
                  child: Center(
                    child: ScaleTransition(
                      scale: _resultsAnimation,
                      child: _room!.winner != null ? _buildFinalWinnerView() : _buildRoundResultView(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerStatusList() {
    return StreamBuilder<List<GameChoice>>(
      stream: _firebaseService.roundChoicesStream(widget.roomId, _currentRound),
      builder: (context, snapshot) {
        final choices = snapshot.data ?? [];

        return Container(
          height: 90,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _players.length,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              final player = _players[index];
              final hasChosen = choices.any((choice) => choice.playerId == player.id);
              final isCurrentUser = player.id == _currentUserId;

              return Container(
                width: 70,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasChosen ? AppColors.success : AppColors.textMuted,
                            boxShadow: [
                              BoxShadow(
                                color: (hasChosen ? AppColors.success : AppColors.textMuted).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(2),
                          child: CircleAvatar(
                            backgroundColor: isCurrentUser ? AppColors.primary : Colors.white,
                            radius: 25,
                            child: Text(
                              player.initial,
                              style: TextStyle(
                                color: isCurrentUser ? Colors.white : AppColors.onBackground,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        if (hasChosen)
                          Container(
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                            child: const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      player.username,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                        color: isCurrentUser ? AppColors.primary : AppColors.onBackground,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      hasChosen ? "Prêt" : "En attente...",
                      style: TextStyle(
                        fontSize: 10,
                        color: hasChosen ? AppColors.success : AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFinalWinnerView() {
    final winnerPlayer = _players.firstWhere(
      (player) => player.id == _room!.winner,
      orElse: () => Player(id: 'unknown', username: 'Inconnu'),
    );

    final isCurrentUserWinner = _room!.winner == _currentUserId;

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.2), spreadRadius: 5, blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isCurrentUserWinner)
            Lottie.asset('assets/winner.json', width: 150, height: 150, repeat: true, animate: true)
          else
            Lottie.asset('assets/trophy.json', width: 120, height: 120, repeat: true, animate: true),

          const SizedBox(height: 20),

          Text(
            "VICTOIRE !",
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
              letterSpacing: 1.5,
              shadows: [Shadow(color: AppColors.secondary.withOpacity(0.3), offset: const Offset(0, 2), blurRadius: 3)],
            ),
          ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
            child: Text(
              winnerPlayer.username,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            isCurrentUserWinner
                ? "Félicitations, vous avez gagné la partie !"
                : "La partie est terminée. ${winnerPlayer.username} est le vainqueur !",
            style: TextStyle(
              fontSize: 18,
              color: isCurrentUserWinner ? AppColors.success : AppColors.onBackground,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 30),

          ElevatedButton.icon(
            onPressed: _exitGame,
            icon: const Icon(Icons.home),
            label: const Text("RETOUR À L'ACCUEIL"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundResultView() {
    if (_roundResult == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final isCurrentUserWinner = _roundResult!.isPlayerWinner(_currentUserId!);
    final isDraw = _roundResult!.isDraw;

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer, size: 24, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                "Résultats du Round $_currentRound",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // Afficher tous les choix
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: AppColors.cardDark, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                const Text("Choix des joueurs", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Divider(height: 20),
                ..._roundResult!.playerChoices.map((choiceData) {
                  final player = _players.firstWhere(
                    (p) => p.id == choiceData.playerId,
                    orElse: () => Player(id: choiceData.playerId, username: 'Inconnu'),
                  );

                  final isWinner = _roundResult!.isPlayerWinner(choiceData.playerId);
                  final isCurrentUser = choiceData.playerId == _currentUserId;

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isCurrentUser ? AppColors.primaryLight : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isWinner ? AppColors.success : AppColors.cardDark, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (isWinner) const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                            const SizedBox(width: 5),
                            Text(
                              player.username,
                              style: TextStyle(
                                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                                color: isCurrentUser ? AppColors.primary : AppColors.onBackground,
                              ),
                            ),
                            if (isCurrentUser) const Text(" (vous)", style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: choiceData.choice.color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(choiceData.choice.emoji, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 5),
                              Text(
                                choiceData.choice.displayName,
                                style: TextStyle(fontWeight: FontWeight.w500, color: choiceData.choice.color),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Résultat
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            decoration: BoxDecoration(
              color:
                  isDraw
                      ? AppColors.warning.withOpacity(0.2)
                      : isCurrentUserWinner
                      ? AppColors.success.withOpacity(0.2)
                      : AppColors.error.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isDraw
                        ? AppColors.warning
                        : isCurrentUserWinner
                        ? AppColors.success
                        : AppColors.error,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDraw
                      ? Icons.balance
                      : isCurrentUserWinner
                      ? Icons.check_circle
                      : Icons.cancel,
                  color:
                      isDraw
                          ? AppColors.warning
                          : isCurrentUserWinner
                          ? AppColors.success
                          : AppColors.error,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  isDraw
                      ? "Égalité parfaite ! Personne n'est éliminé."
                      : isCurrentUserWinner
                      ? "Vous survivez à ce round !"
                      : "Vous êtes éliminé !",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color:
                        isDraw
                            ? AppColors.warning
                            : isCurrentUserWinner
                            ? AppColors.success
                            : AppColors.error,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          if (isCurrentUserWinner || isDraw)
            ElevatedButton.icon(
              onPressed: _readyForNextRound,
              icon: const Icon(Icons.play_arrow),
              label: const Text("PRÊT POUR LE PROCHAIN ROUND"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _exitGame,
              icon: const Icon(Icons.exit_to_app),
              label: const Text("QUITTER LA PARTIE"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
        ],
      ),
    );
  }

  // --- Helper methods ---

  Widget _buildChoiceButton(Choice choice) {
    final bool isSelected = _selectedChoice == choice;

    return GestureDetector(
      onTap: _choiceLocked ? null : () => _makeChoice(choice),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 100,
        height: 120,
        decoration: BoxDecoration(
          color: isSelected ? choice.color.withOpacity(0.9) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isSelected ? choice.color.withOpacity(0.6) : Colors.black.withOpacity(0.1),
              blurRadius: isSelected ? 15 : 8,
              offset: Offset(0, isSelected ? 6 : 4),
              spreadRadius: isSelected ? 1 : 0,
            ),
          ],
          border: Border.all(color: isSelected ? choice.color : Colors.grey.shade300, width: isSelected ? 3 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Émoji vibrant et animé
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              transform: isSelected ? (Matrix4.identity()..scale(1.2)) : Matrix4.identity(),
              transformAlignment: Alignment.center,
              child: Text(choice.emoji, style: const TextStyle(fontSize: 40)),
            ),
            const SizedBox(height: 10),
            // Nom du choix
            Text(
              choice.displayName,
              style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            // Indication visuelle de sélection
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 5),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
              ),
          ],
        ),
      ),
    );
  }
}
