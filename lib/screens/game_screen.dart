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
  final List<String> _countdownTexts = ['Pif...', 'Paf...', 'Pouf!'];
  int _countdownIndex = 0;
  bool _countdownActive = false;

  // Animation pour les résultats
  late AnimationController _resultsController;
  late Animation<double> _resultsAnimation;

  // Streams subscriptions
  StreamSubscription? _roomSubscription;
  StreamSubscription? _playersSubscription;
  StreamSubscription? _roundResultSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();

    // Initialiser l'animation de compte à rebours
    _countdownController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
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
            HapticFeedback.mediumImpact();
          }
        }
      });

    _countdownAnimation = CurvedAnimation(parent: _countdownController, curve: Curves.elasticOut);

    // Initialiser l'animation des résultats
    _resultsController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

    _resultsAnimation = CurvedAnimation(parent: _resultsController, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _playersSubscription?.cancel();
    _roundResultSubscription?.cancel();
    _countdownController.dispose();
    _resultsController.dispose();
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

    _countdownController.reset();
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
    _firebaseService.removePlayerFromRoom(widget.roomId, _currentUserId!);
    context.go(RouteList.home);
  }

  void _showErrorMessage(String message) {
    alertKey.currentState?.showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showInfoMessage(String message) {
    alertKey.currentState?.showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.primary));
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
              const Text("Cette partie n'existe plus", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.go(RouteList.home),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: const Text("RETOUR À L'ACCUEIL"),
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
        backgroundColor: AppColors.primaryLight,
        appBar: AppBar(
          title: Text("Round $_currentRound", style: const TextStyle(color: AppColors.onPrimary, fontFamily: 'Chewy')),
          backgroundColor: AppColors.primary,
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.exit_to_app, color: AppColors.onPrimary),
              onPressed: () {
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text("Quitter la partie ?"),
                        content: const Text("Voulez-vous vraiment quitter la partie ?"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _exitGame();
                            },
                            child: const Text("Quitter", style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                );
              },
            ),
          ],
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Phase de compte à rebours
            if (_countdownActive)
              Expanded(
                child: Center(
                  child: ScaleTransition(
                    scale: _countdownAnimation,
                    child: Text(
                      _countdownTexts[_countdownIndex],
                      style: const TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontFamily: 'Chewy',
                      ),
                    ),
                  ),
                ),
              ),

            // Phase de jeu
            if (!_countdownActive && !_showResults)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Faites votre choix !", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 40),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildChoiceButton(Choice.pierre),
                        _buildChoiceButton(Choice.papier),
                        _buildChoiceButton(Choice.ciseaux),
                      ],
                    ),

                    if (_selectedChoice != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 30),
                        child: Row(
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
    );
  }

  Widget _buildPlayerStatusList() {
    return StreamBuilder<List<GameChoice>>(
      stream: _firebaseService.roundChoicesStream(widget.roomId, _currentRound),
      builder: (context, snapshot) {
        final choices = snapshot.data ?? [];

        return SizedBox(
          height: 70,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _players.length,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              final player = _players[index];
              final hasChosen = choices.any((choice) => choice.playerId == player.id);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  children: [
                    CircleAvatar(
                      backgroundColor: hasChosen ? Colors.green : Colors.grey,
                      radius: 20,
                      child: Text(
                        player.initial,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      player.username,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: player.id == _currentUserId ? FontWeight.bold : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      hasChosen ? "Prêt" : "...",
                      style: TextStyle(fontSize: 10, color: hasChosen ? Colors.green : Colors.grey),
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

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.emoji_events, color: Colors.amber, size: 80),
        const SizedBox(height: 20),
        const Text(
          "VICTOIRE !",
          style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.primary, fontFamily: 'Chewy'),
        ),
        const SizedBox(height: 10),
        Text(winnerPlayer.username, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Text(
          isCurrentUserWinner
              ? "Félicitations, vous avez gagné la partie !"
              : "Vous avez perdu. Bravo à ${winnerPlayer.username} !",
          style: TextStyle(fontSize: 18, color: isCurrentUserWinner ? Colors.green : Colors.grey[700]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: _exitGame,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
          child: const Text("RETOUR À L'ACCUEIL", style: TextStyle(fontSize: 18, fontFamily: 'Chewy')),
        ),
      ],
    );
  }

  Widget _buildRoundResultView() {
    if (_roundResult == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final isCurrentUserWinner = _roundResult!.isPlayerWinner(_currentUserId!);
    final isDraw = _roundResult!.isDraw;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Résultats du Round $_currentRound", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 30),

        // Afficher tous les choix
        Container(
          padding: const EdgeInsets.all(15),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              const Text("Choix des joueurs", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ..._roundResult!.playerChoices.map((choiceData) {
                final player = _players.firstWhere(
                  (p) => p.id == choiceData.playerId,
                  orElse: () => Player(id: choiceData.playerId, username: 'Inconnu'),
                );

                final isWinner = _roundResult!.isPlayerWinner(choiceData.playerId);
                final isCurrentUser = choiceData.playerId == _currentUserId;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (isWinner) const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 5),
                          Text(
                            player.username,
                            style: TextStyle(fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal),
                          ),
                          if (isCurrentUser) const Text(" (vous)", style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      Row(
                        children: [
                          Text(choiceData.choice.emoji, style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 5),
                          Text(choiceData.choice.displayName),
                        ],
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
        Text(
          isDraw
              ? "Égalité parfaite ! Personne n'est éliminé."
              : isCurrentUserWinner
              ? "Vous survivez à ce round !"
              : "Vous êtes éliminé !",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color:
                isDraw
                    ? Colors.orange
                    : isCurrentUserWinner
                    ? Colors.green
                    : Colors.red,
          ),
        ),

        const SizedBox(height: 30),

        if (isCurrentUserWinner || isDraw)
          ElevatedButton(
            onPressed: _readyForNextRound,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            child: const Text("PRÊT POUR LE PROCHAIN ROUND", style: TextStyle(fontSize: 16, fontFamily: 'Chewy')),
          )
        else
          ElevatedButton(
            onPressed: _exitGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            child: const Text("QUITTER LA PARTIE", style: TextStyle(fontSize: 16, fontFamily: 'Chewy')),
          ),
      ],
    );
  }

  // --- Helper methods ---

  Widget _buildChoiceButton(Choice choice) {
    final bool isSelected = _selectedChoice == choice;

    return GestureDetector(
      onTap: _choiceLocked ? null : () => _makeChoice(choice),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: isSelected ? choice.color.withOpacity(0.8) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: isSelected ? choice.color.withOpacity(0.5) : Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: isSelected ? choice.color : Colors.grey.shade300, width: isSelected ? 3 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(choice.emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(
              choice.displayName,
              style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
