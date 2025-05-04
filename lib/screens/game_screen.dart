import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:pif_paf_pouf/app/app_keys.dart';
import 'package:pif_paf_pouf/app/routes.dart';
import 'package:pif_paf_pouf/models/models.dart';
import 'package:pif_paf_pouf/services/firebase_service.dart';
import 'package:pif_paf_pouf/theme/colors.dart';
import 'package:pif_paf_pouf/utils/animations.dart';
import 'package:pif_paf_pouf/widgets/game_countdown_widget.dart';
import 'package:pif_paf_pouf/widgets/player_status_widget.dart';

class GameScreen extends StatefulWidget {
  final String roomId;

  const GameScreen({super.key, required this.roomId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();

  // Variables d'état du jeu
  Room? _room;
  String? _currentUserId;
  Player? _currentPlayer;
  List<Player> _activePlayers = [];
  RoundResult? _roundResult;
  bool _showResults = false;

  // Animations
  late AnimationController _cardAnimController;
  late AnimationController _resultAnimController;
  late AnimationController _countdownAnimController;
  Choice? _selectedChoice;
  bool _choiceConfirmed = false;

  // Variable pour suivre l'état du redémarrage
  final bool _isRestarting = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = _firebaseService.getCurrentUserId();

    // Initialiser les contrôleurs d'animation
    _cardAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _resultAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _countdownAnimController = AnimationController(vsync: this, duration: const Duration(seconds: 3));

    _countdownAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _selectedChoice != null && !_choiceConfirmed) {
        _confirmChoice(_selectedChoice!);
      }
    });

    // Charger les données initiales
    _loadInitialData();
  }

  @override
  void dispose() {
    _cardAnimController.dispose();
    _resultAnimController.dispose();
    _countdownAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final room = await _firebaseService.getRoom(widget.roomId);
      if (mounted) {
        setState(() {
          _room = room;
          if (room != null) {
            _activePlayers = room.players.where((p) => p.active).toList();
            _currentPlayer = _activePlayers.firstWhere((p) => p.id == _currentUserId, orElse: () => _activePlayers.first);
          }
        });
      }
    } catch (e) {
      _showErrorMessage("Erreur de chargement: $e");
    }
  }

  // Sélection d'un choix (pierre, papier, ciseaux)
  void _selectChoice(Choice choice) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedChoice = choice;
    });

    _cardAnimController.reset();
    _cardAnimController.forward();

    // Démarrer le compte à rebours pour la confirmation automatique
    _countdownAnimController.reset();
    _countdownAnimController.forward();
  }

  // Confirmer un choix
  Future<void> _confirmChoice(Choice choice) async {
    if (_choiceConfirmed || _room == null || _currentUserId == null) return;

    setState(() {
      _choiceConfirmed = true;
      _countdownAnimController.stop();
    });

    HapticFeedback.heavyImpact();

    try {
      await _firebaseService.makeChoice(widget.roomId, _currentUserId!, choice.name);
    } catch (e) {
      _showErrorMessage("Erreur lors de la confirmation: $e");
      setState(() {
        _choiceConfirmed = false;
      });
    }
  }

  Future<void> _readyForNextRound() async {
    try {
      setState(() {
        _showResults = false;
        _roundResult = null;
        _selectedChoice = null;
        _choiceConfirmed = false;
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

  // Détermine si le joueur actuel est un survivant/toujours en jeu
  bool _isCurrentPlayerActive() {
    if (_room == null || _currentUserId == null || _currentPlayer == null) return false;
    return _currentPlayer!.active;
  }

  // Construire l'UI pour le choix du joueur
  Widget _buildChoiceUI() {
    final isActive = _isCurrentPlayerActive();

    if (!isActive) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/lottie/eliminated.json', width: 150, height: 150),
            const Text(
              "Vous avez été éliminé !",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              "Regardez la suite du jeu en spectateur",
              style: TextStyle(fontSize: 16, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_choiceConfirmed) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_selectedChoice != null) ...[
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: _selectedChoice!.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Image.asset(_selectedChoice!.imagePath, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Vous avez choisi ${_selectedChoice!.displayName}",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              StreamBuilder<List<GameChoice>>(
                stream: _firebaseService.roundChoicesStream(widget.roomId, _room!.currentRound),
                builder: (context, snapshot) {
                  final totalActive = _activePlayers.where((p) => p.active).length;
                  final choicesMade = snapshot.data?.length ?? 0;

                  return Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(
                              value: totalActive > 0 ? choicesMade / totalActive : 0,
                              strokeWidth: 6,
                              backgroundColor: Colors.grey.shade300,
                              color: AppColors.primary,
                            ),
                          ),
                          Text("$choicesMade/$totalActive", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text("En attente des autres joueurs...", style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Faites votre choix",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            childAspectRatio: 0.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            physics: const NeverScrollableScrollPhysics(),
            children: [_buildChoiceCard(Choice.pierre), _buildChoiceCard(Choice.papier), _buildChoiceCard(Choice.ciseaux)],
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: AnimatedBuilder(
            animation: _countdownAnimController,
            builder: (context, child) {
              final progress = 1 - _countdownAnimController.value;
              return GameCountdown(
                progress: progress,
                secondsRemaining: (3 * progress).ceil(),
                isActive: _selectedChoice != null,
              );
            },
          ),
        ),
        if (_selectedChoice != null) ...[
          const SizedBox(height: 32),
          AnimationUtils.withTapEffect(
            onTap: () => _confirmChoice(_selectedChoice!),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: _selectedChoice!.color,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: _selectedChoice!.color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text("CONFIRMER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Construire une carte de choix (pierre, papier, ciseaux)
  Widget _buildChoiceCard(Choice choice) {
    final isSelected = _selectedChoice == choice;

    return AnimatedScale(
      scale: isSelected ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Card(
        elevation: isSelected ? 8 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isSelected ? BorderSide(color: choice.color, width: 3) : BorderSide.none,
        ),
        child: InkWell(
          onTap: _choiceConfirmed ? null : () => _selectChoice(choice),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: choice.color.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset(choice.imagePath, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  choice.displayName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? choice.color : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Construire l'UI pour l'affichage des résultats du round
  Widget _buildResultsUI() {
    if (_roundResult == null) return const SizedBox.shrink();

    // Déterminer si le joueur a été éliminé ce round
    final bool wasEliminated = _roundResult!.eliminated.contains(_currentUserId);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animation de résultat
          Lottie.asset(
            wasEliminated ? 'assets/lottie/eliminated.json' : 'assets/lottie/success.json',
            width: 150,
            height: 150,
            controller: _resultAnimController,
            onLoaded: (composition) {
              _resultAnimController.forward();
            },
          ),

          Text(
            wasEliminated ? "Vous avez été éliminé !" : "Vous survivez ce round !",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Afficher les choix des joueurs
          if (_roundResult!.playerChoices.isNotEmpty) ...[
            const Text("Choix des joueurs :", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children:
                  _roundResult!.playerChoices.map((choice) {
                    final player = _activePlayers.firstWhere(
                      (p) => p.id == choice.playerId,
                      orElse: () => Player(id: '', name: 'Inconnu', isReady: false, active: false),
                    );
                    final choiceObj = Choice.values.firstWhere((c) => c.name == choice.choice, orElse: () => Choice.pierre);

                    return Column(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: choiceObj.color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(35),
                            border: Border.all(
                              color: choice.playerId == _currentUserId ? AppColors.primary : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Image.asset(choiceObj.imagePath),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          player.name,
                          style: TextStyle(fontWeight: choice.playerId == _currentUserId ? FontWeight.bold : FontWeight.normal),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ],

          const SizedBox(height: 32),

          // Bouton pour continuer
          if (_isCurrentPlayerActive())
            AnimationUtils.withTapEffect(
              onTap: _readyForNextRound,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, color: Colors.white),
                    SizedBox(width: 8),
                    Text("CONTINUER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Construire l'écran de fin de partie
  Widget _buildGameOverScreen(bool isWinner) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(isWinner ? 'assets/lottie/win.json' : 'assets/lottie/lose.json', width: 200, height: 200),
          const SizedBox(height: 24),
          Text(
            isWinner ? "VICTOIRE !" : "PERDU !",
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: isWinner ? AppColors.success : AppColors.error),
          ),
          const SizedBox(height: 16),
          Text(
            isWinner ? "Félicitations, vous avez remporté la partie !" : "Dommage, vous avez perdu cette partie.",
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.go(RouteList.home),
            icon: const Icon(Icons.home),
            label: const Text('RETOUR À L\'ACCUEIL'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
              Lottie.asset('assets/lottie/error.json', width: 200, height: 200),
              const Text("Cette partie n'existe plus", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.go(RouteList.home),
                icon: const Icon(Icons.home),
                label: const Text('RETOUR À L\'ACCUEIL'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Pif Paf Pouf", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            Text("Round ${_room!.currentRound}", style: const TextStyle(fontSize: 14, color: Colors.white70)),
          ],
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.exit_to_app, color: Colors.white),
          onPressed: () {
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text("Quitter la partie ?"),
                    content: const Text("Voulez-vous vraiment quitter cette partie ? Vous serez éliminé définitivement."),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _exitGame();
                        },
                        child: Text("QUITTER", style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
            );
          },
        ),
        actions: [
          // Indicateur de joueurs actifs avec animation
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  const Icon(Icons.people, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    "${_activePlayers.where((p) => p.active).length}",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<Room>(
          stream: _firebaseService.roomStream(widget.roomId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && _room == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 60, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text("Erreur: ${snapshot.error}", style: TextStyle(color: AppColors.error), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(onPressed: _exitGame, child: const Text("QUITTER LA PARTIE")),
                  ],
                ),
              );
            }

            if (snapshot.hasData) {
              _room = snapshot.data;
              _activePlayers = _room!.players;

              // Mise à jour du joueur actuel
              if (_currentUserId != null) {
                _currentPlayer = _activePlayers.firstWhere((p) => p.id == _currentUserId, orElse: () => _activePlayers.first);
              }

              // Vérifier si la partie est terminée
              if (_room!.status == RoomStatus.finished) {
                final isWinner = _room!.winner == _currentUserId;
                return _buildGameOverScreen(isWinner);
              }

              return Column(
                children: [
                  // Widget de statut des joueurs
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: PlayerStatusWidget(players: _activePlayers, currentUserId: _currentUserId, showChoices: _showResults),
                  ),

                  // Contenu principal
                  Expanded(
                    child: StreamBuilder<RoundResult?>(
                      stream: _firebaseService.roundResultStream(widget.roomId, _room!.currentRound),
                      builder: (context, resultSnapshot) {
                        if (resultSnapshot.hasData && resultSnapshot.data!.resultAnnounced) {
                          _roundResult = resultSnapshot.data;

                          // Ne pas montrer les résultats s'ils ont déjà été vus et que le joueur est prêt pour le prochain round
                          if (_showResults == false && _currentPlayer?.isReady == true) {
                            return _buildChoiceUI();
                          } else {
                            // Autrement, montrer les résultats
                            _showResults = true;
                            return _buildResultsUI();
                          }
                        }

                        // Si pas de résultats, montrer l'interface de choix
                        return _buildChoiceUI();
                      },
                    ),
                  ),
                ],
              );
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}
