import "package:flutter/material.dart";
import 'package:go_router/go_router.dart';
import 'package:pif_paf_pouf/app/app_keys.dart';
import 'package:pif_paf_pouf/app/routes.dart';
import 'package:pif_paf_pouf/services/firebase_service.dart';
import 'package:pif_paf_pouf/theme/colors.dart';
import 'package:gap/gap.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _username = "";
  final _formKey = GlobalKey<FormState>();
  final _roomCodeController = TextEditingController();
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
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
      _isJoining = true;
    });

    try {
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
          _isJoining = false;
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
      final roomCode = _roomCodeController.text.trim().toUpperCase();
      final result = await FirebaseService().joinRoomByCode(roomCode, _username);

      if (mounted) {
        if (result['success']) {
          _roomCodeController.clear();
          context.goNamed(RouteNames.lobby, queryParameters: {'roomId': result['roomId']});
        } else {
          _showErrorMessage(result['message'] ?? "Code de room invalide");
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

  void _showErrorMessage(String message) {
    alertKey.currentState?.showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
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
              FirebaseService().signOut();
              context.go(RouteList.auth);
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_username.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    "Bienvenue, $_username !",
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
                ),

              // Création de partie
              ElevatedButton(
                onPressed: _isJoining ? null : _createRoom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  minimumSize: const Size.fromHeight(60),
                ),
                child:
                    _isJoining
                        ? const CircularProgressIndicator(color: AppColors.onPrimary)
                        : const Text("CRÉER UNE PARTIE", style: TextStyle(fontSize: 20, fontFamily: 'Chewy')),
              ),

              const Gap(30),

              const Text("- OU -", style: TextStyle(fontWeight: FontWeight.bold)),

              const Gap(30),

              // Rejoindre partie
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _roomCodeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Code de partie',
                        hintText: 'Ex: ABC123',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Entrez un code de partie';
                        }
                        if (value.length != 6) {
                          return 'Le code doit contenir 6 caractères';
                        }
                        return null;
                      },
                    ),

                    const Gap(15),

                    ElevatedButton(
                      onPressed: _isJoining ? null : _joinRoom,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        minimumSize: const Size.fromHeight(60),
                      ),
                      child:
                          _isJoining
                              ? const CircularProgressIndicator(color: AppColors.onPrimary)
                              : const Text("REJOINDRE", style: TextStyle(fontSize: 20, fontFamily: 'Chewy')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
