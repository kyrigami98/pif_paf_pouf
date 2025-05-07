import "package:flutter/material.dart";
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pif_paf_pouf/app/app_keys.dart';
import 'package:pif_paf_pouf/app/routes.dart';
import 'package:pif_paf_pouf/data/services/firebase_service.dart';
import 'package:pif_paf_pouf/presentation/theme/colors.dart';
import 'package:lottie/lottie.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  String _username = "";
  final _formKey = GlobalKey<FormState>();
  final _roomCodeController = TextEditingController();
  bool _isJoining = false;
  bool _isCreating = false;
  bool _showJoinForm = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

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
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
    _animController.dispose();
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
      final result = await FirebaseService().createRoom(_username);

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
      final result = await FirebaseService().joinRoomByCode(roomCode, _username);

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
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            FirebaseService().signOut();
                            context.go(RouteList.auth);
                          },
                          child: Text("DÉCONNEXION", style: TextStyle(color: AppColors.error)),
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
                    margin: const EdgeInsets.only(bottom: 40),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            _username.isNotEmpty ? _username[0].toUpperCase() : "?",
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Bienvenue,", style: TextStyle(fontSize: 16, color: Colors.grey)),
                            Text(
                              _username,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Illustration du jeu
                if (!_showJoinForm)
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Lottie.asset('assets/lottie/loading.json', width: 260, height: 260),
                        const SizedBox(height: 10),
                        const Text(
                          "Prêt à défier vos amis ?",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                          textAlign: TextAlign.center,
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
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      "REJOINDRE UNE PARTIE",
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20),
                                    TextFormField(
                                      controller: _roomCodeController,
                                      textCapitalization: TextCapitalization.characters,
                                      decoration: InputDecoration(
                                        labelText: 'Code de la partie',
                                        hintText: 'Ex: ABCD12',
                                        prefixIcon: const Icon(Icons.tag),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                        ),
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
                                    const SizedBox(height: 20),
                                    ElevatedButton(
                                      onPressed: _isJoining ? null : _joinRoom,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.secondary,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child:
                                          _isJoining
                                              ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              )
                                              : const Text(
                                                "REJOINDRE",
                                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

                // Boutons d'action
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Bouton principal (créer une partie)
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton.icon(
                            onPressed: _isCreating ? null : _createRoom,
                            icon:
                                _isCreating
                                    ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                    : const Icon(Icons.add_circle_outline, size: 28),
                            label: Text(
                              _isCreating ? "CRÉATION..." : "CRÉER UNE PARTIE",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
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
