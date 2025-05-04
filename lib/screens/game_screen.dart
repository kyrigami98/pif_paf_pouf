import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:pif_paf_pouf/app/app_keys.dart';
import 'package:pif_paf_pouf/app/routes.dart';
import 'package:pif_paf_pouf/models/models.dart';
import 'package:pif_paf_pouf/services/firebase_service.dart';
import 'package:pif_paf_pouf/theme/colors.dart';

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
  bool _isRestarting = false;

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
            _activePlayers = room.players.where((p) => p.isActive).toList();
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
    if (_room == null || _currentUserId == null) return false;

    // Si nous avons des survivants spécifiques, vérifier si le joueur en fait partie
    if (_room!.survivors != null && _room!.survivors!.isNotEmpty) {
      return _room!.survivors!.contains(_currentUserId);
    }

    // Autrement, considérer que tout le monde est actif
    return true;
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
                child: Center(child: Text(_selectedChoice!.emoji, style: const TextStyle(fontSize: 60))),
              ),
              const SizedBox(height: 24),
              Text(
                "Vous avez choisi ${_selectedChoice!.displayName}",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text("En attente des autres joueurs...", style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [_buildChoiceCard(Choice.pierre), _buildChoiceCard(Choice.papier), _buildChoiceCard(Choice.ciseaux)],
          ),
        ),
        const SizedBox(height: 24),
        AnimatedBuilder(
          animation: _countdownAnimController,
          builder: (context, child) {
            final progress = 1 - _countdownAnimController.value;
            return Column(
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade300,
                  color: _getProgressColor(progress),
                  minHeight: 10,
                ),
                const SizedBox(height: 8),
                Text(
                  "Choix automatique dans ${(3 * progress).ceil()} secondes",
                  style: TextStyle(fontSize: 14, color: _getProgressColor(progress)),
                ),
              ],
            );
          },
        ),
        if (_selectedChoice != null) ...[
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _confirmChoice(_selectedChoice!),
            icon: const Icon(Icons.check_circle),
            label: const Text("CONFIRMER"),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedChoice!.color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ],
    );
  }

  Color _getProgressColor(double progress) {
    if (progress > 0.6) return Colors.green;
    if (progress > 0.3) return Colors.orange;
    return Colors.red;
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(color: choice.color.withOpacity(0.2), borderRadius: BorderRadius.circular(40)),
                  child: Center(child: Text(choice.emoji, style: const TextStyle(fontSize: 40))),
                ),
                const SizedBox(height: 12),
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

  // Afficher les résultats du round
  Widget _buildResultsUI() {
    if (_roundResult == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final isWinner = _currentUserId != null && _roundResult!.isPlayerWinner(_currentUserId!);
    final isDraw = _roundResult!.isDraw;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isDraw) ...[
            Lottie.asset('assets/lottie/draw.json', width: 160, height: 160),
            const Text("MATCH NUL !", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            const Text("Tous les joueurs ont fait le même choix.", style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
          ] else if (isWinner) ...[
            Lottie.asset('assets/lottie/winner.json', width: 160, height: 160),
            const Text(
              "VOUS GAGNEZ !",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.success),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Lottie.asset('assets/lottie/lost.json', width: 160, height: 160),
            const Text(
              "ÉLIMINÉ !",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 32),

          _buildChoicesRecap(),

          const SizedBox(height: 32),

          ElevatedButton.icon(
            onPressed: _readyForNextRound,
            icon: const Icon(Icons.arrow_forward),
            label: const Text("CONTINUER", style: TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }

  // Récapitulatif des choix des joueurs
  Widget _buildChoicesRecap() {
    if (_roundResult == null || _roundResult!.playerChoices.isEmpty) {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Choix des joueurs", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _roundResult!.playerChoices.length,
              separatorBuilder: (context, index) => const Divider(height: 8),
              itemBuilder: (context, index) {
                final choice = _roundResult!.playerChoices[index];
                final player = _activePlayers.firstWhere(
                  (p) => p.id == choice.playerId,
                  orElse: () => Player(id: choice.playerId, username: "Joueur inconnu"),
                );

                final isWinner = _roundResult!.isPlayerWinner(choice.playerId);

                return Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isWinner ? AppColors.success.withOpacity(0.2) : AppColors.cardDark,
                      radius: 20,
                      child: Text(
                        player.initial,
                        style: TextStyle(fontWeight: FontWeight.bold, color: isWinner ? AppColors.success : Colors.black87),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        player.username,
                        style: TextStyle(fontWeight: player.id == _currentUserId ? FontWeight.bold : FontWeight.normal),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: choice.choice.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(choice.choice.emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(choice.choice.displayName),
                        ],
                      ),
                    ),
                    if (isWinner)
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Icon(Icons.emoji_events, color: AppColors.success, size: 20),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Ajout d'une nouvelle fonction pour jouer à nouveau
  Future<void> _playAgain() async {
    try {
      setState(() {
        // Désactiver le bouton pendant le traitement
        _isRestarting = true;
      });

      // Créer une nouvelle room avec les mêmes joueurs
      final result = await _firebaseService.createNewGameWithSamePlayers(widget.roomId);

      if (result['success'] && mounted) {
        // Naviguer vers la nouvelle salle
        context.goNamed(RouteNames.lobby, queryParameters: {'roomId': result['roomId']});
      } else {
        _showErrorMessage(result['message'] ?? "Impossible de créer une nouvelle partie");
      }
    } catch (e) {
      _showErrorMessage("Erreur lors de la création d'une nouvelle partie: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isRestarting = false;
        });
      }
    }
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
                    content: const Text("Voulez-vous vraiment quitter cette partie ?"),
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
          // Indicateur de joueurs actifs
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                const Icon(Icons.people, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  "${_room!.survivors?.length ?? _activePlayers.length}",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
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
              _activePlayers = _room!.players.where((p) => p.isActive).toList();

              // Vérifier si la partie est terminée
              if (_room!.winner != null) {
                final isWinner = _room!.winner == _currentUserId;
                return _buildGameOverScreen(isWinner);
              }

              return StreamBuilder<RoundResult?>(
                stream: _firebaseService.roundResultStream(widget.roomId, _room!.currentRound),
                builder: (context, resultSnapshot) {
                  if (resultSnapshot.hasData && resultSnapshot.data!.completed) {
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
              );
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  // Écran de fin de partie modifié avec le bouton "Rejouer"
  Widget _buildGameOverScreen(bool isWinner) {
    // Trouver le gagnant
    final winner = _room!.players.firstWhere(
      (p) => p.id == _room!.winner,
      orElse: () => Player(id: _room!.winner ?? '', username: "Joueur inconnu"),
    );

    return Scaffold(
      backgroundColor: isWinner ? AppColors.success.withOpacity(0.2) : AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isWinner) ...[
              Lottie.asset('assets/lottie/trophy.json', width: 200, height: 200),
              const Text(
                "FÉLICITATIONS !",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.success),
              ),
              const SizedBox(height: 16),
              const Text("Vous avez remporté la victoire !", style: TextStyle(fontSize: 22)),
            ] else ...[
              Lottie.asset('assets/lottie/game_over.json', width: 200, height: 200),
              Text(
                "${winner.username} a gagné !",
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 40),

            // Rangée de boutons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Bouton pour jouer à nouveau
                ElevatedButton.icon(
                  onPressed: _isRestarting ? null : _playAgain,
                  icon:
                      _isRestarting
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                          : const Icon(Icons.replay),
                  label: const Text("REJOUER", style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),

                const SizedBox(width: 16),

                // Bouton pour retourner à l'accueil
                ElevatedButton.icon(
                  onPressed: _exitGame,
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text("ACCUEIL", style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
