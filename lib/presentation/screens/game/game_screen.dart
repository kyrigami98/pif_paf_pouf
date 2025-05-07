import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:pif_paf_pouf/app/app_keys.dart';
import 'package:pif_paf_pouf/app/routes.dart';
import 'package:pif_paf_pouf/data/models/models.dart';
import 'package:pif_paf_pouf/data/services/firebase_service.dart';
import 'package:pif_paf_pouf/data/services/game_rules_service.dart';
import 'package:pif_paf_pouf/data/services/room_service.dart';
import 'package:pif_paf_pouf/presentation/theme/colors.dart';
import 'package:pif_paf_pouf/presentation/common_widgets/game_countdown_widget.dart';
import 'package:pif_paf_pouf/presentation/common_widgets/player_status_widget.dart';
import 'package:pif_paf_pouf/presentation/common_widgets/duel_result_visualizer.dart';
import 'package:gap/gap.dart'; // Utilisation du package gap pour les espacements

class GameScreen extends StatefulWidget {
  final String roomId;

  const GameScreen({super.key, required this.roomId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();

  final RoomService _roomService = RoomService(FirebaseFirestore.instance);
  final GameRulesService _gameRulesService = GameRulesService();

  // Variables d'état du jeu
  Room? _room;
  String? _currentUserId;
  Player? _currentPlayer;
  List<Player> _activePlayers = [];
  RoundResult? _roundResult;
  bool _showResults = false;
  bool _extendedMode = false;

  // Animations
  late AnimationController _cardAnimController;
  late AnimationController _resultAnimController;
  late AnimationController _countdownAnimController;
  late AnimationController _tieBreakerCountdownController;
  late AnimationController _floatingAnimController;
  late AnimationController _pulseAnimController;

  GameChoiceModel? _selectedChoice;
  bool _choiceConfirmed = false;
  bool _processingTieBreaker = false;

  // Liste des choix disponibles
  late List<GameChoiceModel> _availableChoices;
  final List<GameChoice> _currentRoundChoices = [];

  // État de chargement
  bool _isLoading = true;
  bool _showTutorial = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = _firebaseService.getCurrentUserId();

    // Initialiser les contrôleurs d'animation
    _cardAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _resultAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _countdownAnimController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _tieBreakerCountdownController = AnimationController(vsync: this, duration: const Duration(seconds: 5));
    _floatingAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _pulseAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);

    _countdownAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _selectedChoice != null && !_choiceConfirmed) {
        _confirmChoice(_selectedChoice!);
      }
    });

    _tieBreakerCountdownController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _processingTieBreaker) {
        _readyForNextRound();
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
    _tieBreakerCountdownController.dispose();
    _floatingAnimController.dispose();
    _pulseAnimController.dispose();

    // Nettoyer le cache Firebase pour cette room
    _roomService.clearCache(widget.roomId);

    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final room = await _roomService.getRoom(widget.roomId);

      if (mounted) {
        final roomDoc = await FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).get();
        final extendedMode = roomDoc.data()?['extendedMode'] ?? false;

        setState(() {
          _room = room;
          _extendedMode = extendedMode;
          _availableChoices = _gameRulesService.getActiveChoices(extendedMode: extendedMode);

          if (room != null) {
            _activePlayers = room.players.where((p) => p.active).toList();
            _currentPlayer = _activePlayers.firstWhere(
              (p) => p.id == _currentUserId,
              orElse: () => _activePlayers.isNotEmpty ? _activePlayers.first : Player(id: '', name: 'Inconnu'),
            );
          }

          _isLoading = false;

          // Afficher le tutorial une fois pour les nouveaux joueurs
          _showTutorial = !_hasPreviouslyPlayed();
        });

        if (_showTutorial) {
          _saveTutorialShown();
          // Afficher le tutorial après un court délai
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _showTutorialDialog();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorMessage("Erreur de chargement: $e");
      }
    }
  }

  bool _hasPreviouslyPlayed() {
    // En production, utilisez SharedPreferences pour vérifier
    // Pour l'exemple, je renvoie toujours false pour montrer le tutoriel
    return false;
  }

  void _saveTutorialShown() {
    // En production, utilisez SharedPreferences pour sauvegarder
  }

  // Sélection d'un choix (pierre, papier, ciseaux, etc.)
  void _selectChoice(GameChoiceModel choice) {
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
  Future<void> _confirmChoice(GameChoiceModel choice) async {
    if (_choiceConfirmed || _room == null || _currentUserId == null) return;

    setState(() {
      _choiceConfirmed = true;
      _countdownAnimController.stop();
    });

    HapticFeedback.heavyImpact();

    try {
      await _roomService.makeChoice(widget.roomId, _currentUserId!, choice.name);
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
        _processingTieBreaker = false;
      });

      // Marquer comme prêt pour le prochain round
      await _roomService.updatePlayerStatus(widget.roomId, _currentUserId!, true);
    } catch (e) {
      _showErrorMessage("Erreur: $e");
    }
  }

  void _exitGame() {
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Quitter la partie ?"),
            content: const Text("Voulez-vous vraiment quitter cette partie ? Vous serez éliminé définitivement."),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _roomService.removePlayerFromRoom(widget.roomId, _currentUserId!);
                  context.go(RouteList.home);
                },
                icon: const Icon(Icons.exit_to_app, size: 18),
                label: const Text("QUITTER"),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              ),
            ],
          ),
    );
  }

  void _showErrorMessage(String message) {
    alertKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
        action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
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
        action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
      ),
    );
  }

  void _showTutorialDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.lightbulb, color: AppColors.secondary),
                const SizedBox(width: 10),
                const Text("Comment jouer ?"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Bienvenue dans Pif Paf Pouf, le battle royale de Shifumi !"),
                const Gap(10),
                const Text("• Chaque joueur choisit un signe"),
                const Text("• Les joueurs qui perdent sont éliminés"),
                const Text("• Les tours continuent jusqu'à ce qu'il ne reste qu'un joueur"),
                const Gap(10),
                if (_extendedMode)
                  const Text(
                    "Vous jouez en mode étendu avec des choix supplémentaires !",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                const Gap(15),
                const Text("Bon jeu ! 🎮", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            actions: [
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_circle),
                label: const Text("COMPRIS !"),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
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
            const Gap(16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
              child: const Text(
                "Regardez la suite du jeu en spectateur",
                style: TextStyle(fontSize: 16, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
            const Gap(32),
            // Afficher les joueurs actifs restants et leur score
            if (_activePlayers.where((p) => p.active).isNotEmpty)
              Column(
                children: [
                  const Text("Joueurs restants:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Gap(8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children:
                        _activePlayers
                            .where((p) => p.active)
                            .map(
                              (p) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppColors.primary.withOpacity(0.7), AppColors.primary],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.3),
                                      blurRadius: 5,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.white,
                                      radius: 14,
                                      child: Text(
                                        p.initial,
                                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const Gap(8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                        Row(
                                          children: [
                                            const Icon(Icons.star, color: Colors.amber, size: 12),
                                            const Gap(2),
                                            Text("${p.score} pts", style: const TextStyle(color: Colors.white, fontSize: 11)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ],
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
              AnimatedBuilder(
                animation: _floatingAnimController,
                builder: (context, child) {
                  return Transform.translate(offset: Offset(0, _floatingAnimController.value * -5), child: child);
                },
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: _selectedChoice!.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(70),
                    boxShadow: [BoxShadow(color: _selectedChoice!.color.withOpacity(0.3), blurRadius: 15, spreadRadius: 5)],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Image.asset(_selectedChoice!.imagePath, fit: BoxFit.contain),
                  ),
                ),
              ),
              const Gap(24),
              Text(
                "Vous avez choisi ${_selectedChoice!.displayName}",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              if (_selectedChoice!.description != null)
                Text(
                  _selectedChoice!.description!,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
              const Gap(32),
              StreamBuilder<List<GameChoice>>(
                stream: _roomService.roundChoicesStream(widget.roomId, _room!.currentRound),
                builder: (context, snapshot) {
                  final totalActive = _activePlayers.where((p) => p.active).length;
                  final choicesMade = snapshot.data?.length ?? 0;

                  return Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: AnimatedBuilder(
                              animation: _pulseAnimController,
                              builder: (context, child) {
                                return CircularProgressIndicator(
                                  value: totalActive > 0 ? choicesMade / totalActive : 0,
                                  strokeWidth: 8,
                                  backgroundColor: Colors.grey.shade300,
                                  color: AppColors.primary.withOpacity(0.5 + _pulseAnimController.value * 0.5),
                                );
                              },
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                "$choicesMade/$totalActive",
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text("Joueurs", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ],
                      ),
                      const Gap(16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time, color: AppColors.primary, size: 18),
                            const Gap(8),
                            Text("En attente des autres joueurs...", style: TextStyle(fontSize: 14, color: AppColors.primary)),
                          ],
                        ),
                      ),
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
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary.withOpacity(0.6), AppColors.primary.withOpacity(0.2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app, color: AppColors.primary),
              Gap(10),
              Text(
                "Faites votre choix",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.all(16.0), child: _buildChoicesGrid()),
        const Gap(16),
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
        const Gap(16),
        if (_selectedChoice != null) ...[
          const Gap(24),
          AnimatedBuilder(
            animation: _pulseAnimController,
            builder: (context, child) {
              return Transform.scale(scale: 1.0 + (_pulseAnimController.value * 0.05), child: child);
            },
            child: ElevatedButton.icon(
              onPressed: () => _confirmChoice(_selectedChoice!),
              icon: const Icon(Icons.check_circle),
              label: const Text("CONFIRMER", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedChoice!.color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 5,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Construire une grille de choix qui s'adapte dynamiquement
  Widget _buildChoicesGrid() {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _availableChoices.length <= 4 ? 2 : 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _availableChoices.length,
      itemBuilder: (context, index) {
        return _buildChoiceCard(_availableChoices[index]);
      },
    );
  }

  // Construire une carte de choix (pierre, papier, ciseaux, etc.)
  Widget _buildChoiceCard(GameChoiceModel choice) {
    final isSelected = _selectedChoice?.id == choice.id;

    return AnimatedScale(
      scale: isSelected ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow:
              isSelected
                  ? [BoxShadow(color: choice.color.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))]
                  : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: _choiceConfirmed ? null : () => _selectChoice(choice),
            borderRadius: BorderRadius.circular(16),
            splashColor: choice.color.withOpacity(0.2),
            highlightColor: choice.color.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [choice.color.withOpacity(0.2), choice.color.withOpacity(0.4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(12.0),
                      child: Image.asset(choice.imagePath, fit: BoxFit.contain),
                    ),
                  ),
                  const Gap(8),
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
      ),
    );
  }

  // Construire l'UI pour l'affichage des résultats du round
  Widget _buildResultsUI() {
    if (_roundResult == null) return const SizedBox.shrink();

    // Déterminer si le joueur a été éliminé ce round
    final bool wasEliminated = _roundResult!.eliminated.contains(_currentUserId);
    final bool isPerfectTie = _roundResult!.isTie && _roundResult!.eliminated.isEmpty && _roundResult!.playerChoices.length > 1;

    // Si c'est une égalité parfaite, lancer le compte à rebours pour passer automatiquement au round suivant
    if (isPerfectTie && !_processingTieBreaker) {
      _processingTieBreaker = true;
      _tieBreakerCountdownController.reset();
      _tieBreakerCountdownController.forward();
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animation de résultat
          Lottie.asset(
            wasEliminated
                ? 'assets/lottie/eliminated.json'
                : isPerfectTie
                ? 'assets/lottie/tie.json'
                : 'assets/lottie/success.json',
            width: 150,
            height: 150,
            controller: _resultAnimController,
            onLoaded: (composition) {
              _resultAnimController.forward();
            },
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    wasEliminated
                        ? [AppColors.error.withOpacity(0.7), AppColors.error]
                        : isPerfectTie
                        ? [Colors.amber.withOpacity(0.7), Colors.amber]
                        : [AppColors.success.withOpacity(0.7), AppColors.success],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color:
                      wasEliminated
                          ? AppColors.error.withOpacity(0.3)
                          : isPerfectTie
                          ? Colors.amber.withOpacity(0.3)
                          : AppColors.success.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              wasEliminated
                  ? "Vous avez été éliminé !"
                  : isPerfectTie
                  ? "Égalité parfaite ! Nouveau round..."
                  : "Vous survivez ce round !",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),

          // Explication du score
          if (!wasEliminated && !isPerfectTie) ...[
            const Gap(12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_circle, color: AppColors.success, size: 16),
                  const Gap(6),
                  const Text(
                    "1 point pour avoir survécu !",
                    style: TextStyle(fontSize: 14, color: AppColors.success, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],

          // Afficher le compte à rebours en cas d'égalité parfaite
          if (isPerfectTie) ...[
            const Gap(16),
            AnimatedBuilder(
              animation: _tieBreakerCountdownController,
              builder: (context, child) {
                final countdown = 5 - (_tieBreakerCountdownController.value * 5).floor();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(30)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, color: AppColors.primary, size: 18),
                      const Gap(8),
                      Text(
                        "Prochain round dans $countdown secondes",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          const Gap(24),

          // Utiliser le visualiseur de duels pour afficher les résultats détaillés
          if (_roundResult!.playerChoices.isNotEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DuelResultVisualizer(
                  playerChoices: _roundResult!.playerChoices,
                  players: _activePlayers,
                  currentUserId: _currentUserId,
                  eliminatedPlayers: _roundResult!.eliminated,
                  isPerfectTie: isPerfectTie,
                ),
              ),
            ),

          const Gap(16),

          // Bouton pour continuer
          if (_isCurrentPlayerActive() && !isPerfectTie)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: AnimatedBuilder(
                animation: _pulseAnimController,
                builder: (context, child) {
                  return Transform.scale(scale: 1.0 + (_pulseAnimController.value * 0.05), child: child);
                },
                child: ElevatedButton.icon(
                  onPressed: _readyForNextRound,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("CONTINUER", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Construire l'écran de fin de partie
  Widget _buildGameOverScreen(bool isWinner) {
    // Trouver le joueur ayant le score le plus élevé
    Player? topScorer;
    int topScore = -1;

    for (var player in _activePlayers) {
      if (player.score > topScore) {
        topScore = player.score;
        topScorer = player;
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(isWinner ? 'assets/lottie/win.json' : 'assets/lottie/lose.json', width: 200, height: 200),
          const Gap(20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    isWinner
                        ? [AppColors.success.withOpacity(0.7), AppColors.success]
                        : [AppColors.error.withOpacity(0.7), AppColors.error],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: isWinner ? AppColors.success.withOpacity(0.3) : AppColors.error.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              isWinner ? "VICTOIRE !" : "PERDU !",
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const Gap(16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 30),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Text(
              isWinner ? "Félicitations, vous avez remporté la partie !" : "Dommage, vous avez perdu cette partie.",
              style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
          ),

          // Afficher le meilleur score
          if (topScorer != null) ...[
            const Gap(30),
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade300, Colors.amber.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events, color: Colors.white, size: 22),
                      Gap(8),
                      Text("MEILLEUR SCORE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  const Gap(12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.2),
                          radius: 22,
                          child: Text(
                            topScorer.initial,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                        const Gap(12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topScorer.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 16),
                                const Gap(4),
                                Text(
                                  "${topScorer.score} points",
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Gap(40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => context.go(RouteList.home),
                icon: const Icon(Icons.home),
                label: const Text('RETOUR À L\'ACCUEIL'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
              const Gap(16),
              ElevatedButton.icon(
                onPressed: () {
                  _showInfoMessage("Création d'une nouvelle partie...");
                  _roomService.createNewGameWithSamePlayers(widget.roomId);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('REJOUER'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Construire un widget qui affiche les règles du jeu
  Widget _buildRulesDialog() {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.primary),
          Gap(8),
          Text("Règles du jeu", style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var choice in _availableChoices) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: choice.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: choice.color.withOpacity(0.2), borderRadius: BorderRadius.circular(25)),
                      child: Image.asset(choice.imagePath),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(choice.displayName, style: TextStyle(fontWeight: FontWeight.bold, color: choice.color)),
                          if (choice.beats.isNotEmpty)
                            Row(
                              children: [
                                const Text("Bat: ", style: TextStyle(fontSize: 12)),
                                Expanded(
                                  child: Wrap(
                                    spacing: 4,
                                    children:
                                        choice.beats.map((id) {
                                          final beatChoice = _gameRulesService.getChoiceById(id);
                                          return Container(
                                            margin: const EdgeInsets.only(top: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: beatChoice?.color.withOpacity(0.2) ?? Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              beatChoice?.displayName ?? id,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: beatChoice?.color ?? Colors.grey,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_availableChoices.last != choice) const Divider(),
            ],
            const Gap(20),
            const Text(
              "Règle du Battle Royale: à chaque round, les joueurs dont le choix est battu par un autre sont éliminés. Le dernier joueur restant gagne la partie!",
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.check_circle),
          label: const Text("COMPRIS"),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Afficher un écran de chargement
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.primaryLight,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/lottie/loading.json', width: 120, height: 120),
              const Gap(20),
              const Text("Chargement de la partie...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

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
              const Gap(20),
              ElevatedButton.icon(
                onPressed: () => context.go(RouteList.home),
                icon: const Icon(Icons.home),
                label: const Text('RETOUR À L\'ACCUEIL'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: Text("Round ${_room!.currentRound}", style: const TextStyle(fontSize: 14, color: Colors.white70)),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        leading: IconButton(icon: const Icon(Icons.exit_to_app, color: Colors.white), onPressed: _exitGame),
        actions: [
          // Indicateur de mode de jeu
          if (_extendedMode)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.extension, color: Colors.amber, size: 14),
                  const Gap(4),
                  const Text("Étendu", style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

          // Bouton pour afficher les règles
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () {
              showDialog(context: context, builder: (context) => _buildRulesDialog());
            },
          ),

          // Indicateur de joueurs actifs avec animation
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                const Icon(Icons.people, size: 16, color: Colors.white),
                const Gap(4),
                Text(
                  "${_activePlayers.where((p) => p.active).length}",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<Room>(
          stream: _roomService.roomStream(widget.roomId),
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
                    const Gap(16),
                    Text("Erreur: ${snapshot.error}", style: TextStyle(color: AppColors.error), textAlign: TextAlign.center),
                    const Gap(24),
                    ElevatedButton(
                      onPressed: _exitGame,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                      child: const Text("QUITTER LA PARTIE"),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.hasData) {
              _room = snapshot.data;

              // Vérifier s'il y a une nouvelle salle à rejoindre (pour le rejeu)
              if (_room?.nextRoomId != null && mounted) {
                Future.microtask(() {
                  context.goNamed(RouteNames.lobby, queryParameters: {'roomId': _room!.nextRoomId});
                });
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      Gap(20),
                      Text("Redirection vers la nouvelle partie...", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }

              _activePlayers = _room!.players;

              // Mise à jour du joueur actuel
              if (_currentUserId != null) {
                _currentPlayer = _activePlayers.firstWhere(
                  (p) => p.id == _currentUserId,
                  orElse: () => _activePlayers.isNotEmpty ? _activePlayers.first : Player(id: '', name: 'Inconnu'),
                );
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
                    child: PlayerStatusWidget(
                      players: _activePlayers,
                      currentUserId: _currentUserId,
                      showChoices: _showResults,
                      roundNumber: _room!.currentRound,
                    ),
                  ),
                  // Contenu principal
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          StreamBuilder<RoundResult?>(
                            stream: _roomService.roundResultStream(widget.roomId, _room!.currentRound),
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
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  Gap(16),
                  Text("Chargement de la partie...", style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          },
        ),
      ),
      bottomSheet: _buildDeveloperModeToggle(),
    );
  }

  // Nouveau widget pour activer/désactiver le mode développeur (extension)
  Widget _buildDeveloperModeToggle() {
    // Seulement visible pour l'hôte et en mode développement
    if (_room == null || !_isHost() || !kDebugMode) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black87,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.developer_mode, color: _extendedMode ? Colors.amber : Colors.grey, size: 18),
              const Gap(8),
              Text("Mode étendu", style: TextStyle(color: _extendedMode ? Colors.amber : Colors.grey)),
            ],
          ),
          Switch(
            value: _extendedMode,
            activeColor: Colors.amber,
            onChanged: (value) async {
              bool success = await _firebaseService.roomService.toggleGameMode(widget.roomId, value);
              if (success) {
                setState(() {
                  _extendedMode = value;
                  _availableChoices = _gameRulesService.getActiveChoices(extendedMode: value);
                });
                if (value) {
                  _showInfoMessage("Mode étendu activé ! De nouveaux choix sont disponibles.");
                } else {
                  _showInfoMessage("Mode étendu désactivé. Retour au mode classique.");
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // Déterminer si le joueur actuel est l'hôte
  bool _isHost() {
    if (_room == null || _currentUserId == null) return false;
    final currentPlayer = _room!.players.firstWhere(
      (p) => p.id == _currentUserId,
      orElse: () => Player(id: '', name: '', isHost: false),
    );
    return currentPlayer.isHost;
  }
}
