import 'package:cloud_firestore/cloud_firestore.dart';
import "package:flutter/material.dart";
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pif_paf_pouf/app/app_keys.dart';
import 'package:pif_paf_pouf/app/routes.dart';
import 'package:pif_paf_pouf/data/services/firebase_service.dart';
import 'package:pif_paf_pouf/data/services/room_service.dart';
import 'package:pif_paf_pouf/presentation/theme/colors.dart';
import 'package:lottie/lottie.dart';
import 'package:gap/gap.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final RoomService _roomService = RoomService(FirebaseFirestore.instance);

  String _username = "";
  final _formKey = GlobalKey<FormState>();
  final _roomCodeController = TextEditingController();
  bool _isJoining = false;
  bool _isCreating = false;
  bool _showJoinForm = false;
  bool _extendedMode = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late AnimationController _buttonAnimController;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadUsername();

    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _buttonAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);

    _buttonScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _buttonAnimController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
    _animController.dispose();
    _buttonAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadUsername() async {
    final username = await FirebaseService().getLocalUsername();
    if (mounted && username != null) {
      setState(() {
        _username = username;
      });
    }
  }

  Future<void> _createRoom() async {
    setState(() {
      _isCreating = true;
    });

    try {
      HapticFeedback.mediumImpact();
      final result = await _roomService.createRoom(
        _firebaseService.getCurrentUserId() ?? "",
        _username,
        extendedMode: _extendedMode,
      );

      if (mounted) {
        if (result['success']) {
          context.goNamed(RouteNames.lobby, queryParameters: {'roomId': result['roomId']});
        } else {
          _showErrorMessage(result['message'] ?? "Erreur lors de la création de la room");
        }
      }
    } catch (e) {
      _showErrorMessage("Erreur: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Future<void> _joinRoom() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isJoining = true;
    });

    try {
      HapticFeedback.mediumImpact();
      final roomCode = _roomCodeController.text.trim().toUpperCase();
      final result = await _roomService.joinRoomByCode(roomCode, _firebaseService.getCurrentUserId() ?? "", _username);

      if (mounted) {
        if (result['success']) {
          _roomCodeController.clear();
          context.goNamed(RouteNames.lobby, queryParameters: {'roomId': result['roomId']});
        } else {
          _showErrorMessage(result['message'] ?? "Code de partie invalide");
        }
      }
    } catch (e) {
      _showErrorMessage("Erreur: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  void _toggleJoinForm() {
    setState(() {
      _showJoinForm = !_showJoinForm;
    });

    if (_showJoinForm) {
      _animController.forward();
    } else {
      _animController.reverse();
    }

    HapticFeedback.selectionClick();
  }

  void _showErrorMessage(String message) {
    HapticFeedback.vibrate();
    alertKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Pif Paf Pouf", style: TextStyle(fontSize: 30, color: AppColors.onPrimary, fontFamily: 'Chewy')),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.onPrimary),
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text("Se déconnecter ?"),
                      content: const Text("Votre pseudo sera oublié."),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            FirebaseService().signOut();
                            context.go(RouteList.auth);
                          },
                          icon: const Icon(Icons.logout, size: 16),
                          label: const Text("DÉCONNEXION"),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
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
            colors: [AppColors.primary, AppColors.primaryLight, AppColors.background],
            stops: const [0.0, 0.3, 0.6],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // En-tête avec avatar et nom
                if (_username.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.white.withOpacity(0.95)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8))],
                    ),
                    child: Row(
                      children: [
                        // Avatar animé
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(scale: value, child: child);
                          },
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _username.isNotEmpty ? _username[0].toUpperCase() : "?",
                                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        const Gap(16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Bienvenue,", style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                            Text(
                              _username,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Illustration du jeu ou formulaire de connexion
                if (!_showJoinForm)
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Lottie.asset('assets/lottie/loading.json', width: 260, height: 260),
                        const Gap(12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primary.withOpacity(0.7), AppColors.primary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
                            ],
                          ),
                          child: const Text(
                            "Prêt à défier vos amis ?",
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Formulaire pour rejoindre une partie
                if (_showJoinForm)
                  Expanded(
                    flex: 3,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.white, Colors.white.withOpacity(0.95)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8)),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.login, color: AppColors.secondary),
                                        Gap(8),
                                        Text(
                                          "REJOINDRE UNE PARTIE",
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                    const Gap(24),
                                    TextFormField(
                                      controller: _roomCodeController,
                                      textCapitalization: TextCapitalization.characters,
                                      decoration: InputDecoration(
                                        labelText: 'Code de la partie',
                                        hintText: 'Ex: ABCD12',
                                        prefixIcon: const Icon(Icons.tag),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(color: AppColors.secondary, width: 2),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                      ),
                                      style: const TextStyle(fontSize: 20, letterSpacing: 3),
                                      textAlign: TextAlign.center,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Veuillez entrer un code';
                                        }
                                        if (value.length != 6) {
                                          return 'Le code doit contenir 6 caractères';
                                        }
                                        return null;
                                      },
                                    ),
                                    const Gap(24),
                                    AnimatedBuilder(
                                      animation: _buttonScaleAnimation,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: _isJoining ? 1.0 : _buttonScaleAnimation.value,
                                          child: ElevatedButton.icon(
                                            onPressed: _isJoining ? null : _joinRoom,
                                            icon:
                                                _isJoining
                                                    ? const SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                    )
                                                    : const Icon(Icons.login),
                                            label: Text(
                                              _isJoining ? "CONNEXION..." : "REJOINDRE",
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.secondary,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 16),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              elevation: 5,
                                              shadowColor: AppColors.secondary.withOpacity(0.5),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Boutons d'action
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Option mode étendu (seulement visible quand création partie)
                        if (!_showJoinForm)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _extendedMode ? Colors.amber.withOpacity(0.5) : Colors.grey.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: _extendedMode,
                                  activeColor: Colors.amber,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (value) {
                                    setState(() {
                                      _extendedMode = value ?? false;
                                    });
                                    HapticFeedback.selectionClick();
                                  },
                                ),
                                const Gap(4),
                                Row(
                                  children: [
                                    Icon(Icons.extension, size: 16, color: _extendedMode ? Colors.amber : Colors.grey.shade600),
                                    const Gap(4),
                                    Text(
                                      "Mode étendu",
                                      style: TextStyle(
                                        color: _extendedMode ? Colors.amber : Colors.grey.shade600,
                                        fontWeight: _extendedMode ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder:
                                          (context) => AlertDialog(
                                            title: Row(
                                              children: [Icon(Icons.extension, color: Colors.amber), Gap(8), Text("Mode Étendu")],
                                            ),
                                            content: const Text(
                                              "Le mode étendu ajoute des choix supplémentaires au jeu classique Pierre-Papier-Ciseaux, comme le Puit et d'autres signes, pour plus de stratégie et de fun !",
                                            ),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
                                            ],
                                          ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                        // Bouton principal (créer une partie)
                        AnimatedBuilder(
                          animation: _buttonScaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _isCreating ? 1.0 : _buttonScaleAnimation.value,
                              child: Container(
                                width: double.infinity,
                                height: 60,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppColors.primary, AppColors.primaryDark],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.4),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    onTap: _isCreating ? null : _createRoom,
                                    borderRadius: BorderRadius.circular(16),
                                    splashColor: Colors.white.withOpacity(0.1),
                                    highlightColor: Colors.white.withOpacity(0.05),
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          _isCreating
                                              ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              )
                                              : const Icon(Icons.add_circle_outline, size: 28, color: Colors.white),
                                          const Gap(16),
                                          Text(
                                            _isCreating ? "CRÉATION..." : "CRÉER UNE PARTIE",
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // Bouton secondaire (rejoindre une partie)
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: OutlinedButton.icon(
                            onPressed: _toggleJoinForm,
                            icon: Icon(_showJoinForm ? Icons.close : Icons.login, size: 24),
                            label: Text(
                              _showJoinForm ? "ANNULER" : "J'AI UN CODE",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryDark,
                              side: const BorderSide(color: AppColors.primaryDark, width: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
