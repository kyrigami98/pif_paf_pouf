import "package:flutter/material.dart";
import 'package:go_router/go_router.dart';
import 'package:pif_paf_pouf/app/routes.dart';
import 'package:pif_paf_pouf/services/firebase_service.dart';
import 'package:pif_paf_pouf/theme/colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _username = "";

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final username = await FirebaseService().getLocalUsername();
    if (mounted && username != null) {
      setState(() {
        _username = username;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Pif Paf Pouf", style: TextStyle(fontSize: 30, color: AppColors.onPrimary)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Icon(Icons.add, color: AppColors.onPrimary),
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
            ElevatedButton(
              onPressed: () {
                // Naviguer vers l'écran radar
                context.pushNamed(RouteNames.radar);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: const Text("Je suis prêt !", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
