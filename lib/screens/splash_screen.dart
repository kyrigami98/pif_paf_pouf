import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pif_paf_pouf/app/routes.dart';
import 'package:pif_paf_pouf/services/firebase_service.dart';
import 'package:pif_paf_pouf/theme/colors.dart';
import 'dart:async';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.7, curve: Curves.elasticOut)));

    _animationController.forward();

    _checkAuthAndNavigate();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Simuler un délai pour l'animation
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary, AppColors.primaryDark.withOpacity(0.8)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: size.height * 0.15),
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(opacity: _fadeAnimation, child: ScaleTransition(scale: _scaleAnimation, child: child));
                },
                child: Column(
                  children: [
                    Image.asset('assets/logo.png', width: 180, height: 180),
                    const SizedBox(height: 24),
                    Text(
                      "Pif Paf Pouf",
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        shadows: [Shadow(color: Colors.black.withOpacity(0.3), offset: const Offset(2, 2), blurRadius: 3)],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: Column(
                  children: [
                    Lottie.asset('assets/lottie/loading.json', width: 80, height: 80, fit: BoxFit.cover),
                    const SizedBox(height: 16),
                    const Text(
                      'Préparation du jeu...',
                      style: TextStyle(color: AppColors.onPrimary, fontSize: 16, fontWeight: FontWeight.w500),
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
