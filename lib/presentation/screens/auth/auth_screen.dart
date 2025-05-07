import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pif_paf_pouf/app/app_keys.dart';
import 'package:pif_paf_pouf/app/routes.dart';
import 'package:pif_paf_pouf/data/services/firebase_service.dart';
import 'package:pif_paf_pouf/presentation/theme/colors.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final firebaseService = FirebaseService();

        // S'assurer que l'utilisateur est connecté anonymement
        if (!firebaseService.isSignedIn) {
          await firebaseService.signInAnonymously();
        }

        // Enregistrer le pseudo
        final success = await firebaseService.saveUsername(_usernameController.text.trim());

        if (success && mounted) {
          // Naviguer vers l'écran d'accueil
          context.goNamed(RouteNames.home);
        } else if (mounted) {
          _showErrorMessage("Une erreur s'est produite. Veuillez réessayer.");
        }
      } catch (e) {
        _showErrorMessage("Une erreur s'est produite: $e");
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _showErrorMessage(String message) {
    alertKey.currentState?.showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Qui êtes-vous ?", style: TextStyle(color: AppColors.onPrimary)),
        backgroundColor: AppColors.primary,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Choisissez un pseudo pour continuer",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Pseudo',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Veuillez entrer un pseudo';
                  }
                  if (value.length < 3) {
                    return 'Le pseudo doit contenir au moins 3 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child:
                    _isLoading
                        ? const CircularProgressIndicator(color: AppColors.onPrimary)
                        : const Text('Continuer', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
