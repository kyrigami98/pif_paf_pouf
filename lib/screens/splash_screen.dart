import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pif_paf_pouf/app/routes.dart';
import 'package:pif_paf_pouf/services/firebase_service.dart';
import 'package:pif_paf_pouf/theme/colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Simuler un délai pour le chargement
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final firebaseService = FirebaseService();
    final username = await firebaseService.getLocalUsername();

    // Si l'utilisateur a déjà un pseudo, naviguer directement vers l'accueil
    // Sinon, naviguer vers l'écran d'authentification
    if (username != null && username.isNotEmpty && firebaseService.isSignedIn) {
      context.goNamed(RouteNames.home);
    } else {
      context.goNamed(RouteNames.auth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', width: 200, height: 200),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: AppColors.onPrimary),
            const SizedBox(height: 20),
            const Text('Chargement...', style: TextStyle(color: AppColors.onPrimary, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
