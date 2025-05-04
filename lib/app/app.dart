import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pif_paf_pouf/app/app_keys.dart';
import 'package:pif_paf_pouf/app/routes.dart';
import 'package:pif_paf_pouf/screens/auth_screen.dart';
import 'package:pif_paf_pouf/screens/home_screen.dart';
import 'package:pif_paf_pouf/screens/splash_screen.dart';
import 'package:pif_paf_pouf/screens/lobby_screen.dart';
import 'package:pif_paf_pouf/screens/game_screen.dart';
import 'package:pif_paf_pouf/theme/app_theme.dart';
import 'package:pif_paf_pouf/theme/colors.dart';
import '../firebase_options.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

class AppRouter {
  static final GoRouter _router = GoRouter(
    debugLogDiagnostics: true,
    navigatorKey: rootShellNavigatorKey,
    initialLocation: RouteList.splash,
    routes: [
      GoRoute(
        path: RouteList.splash,
        name: RouteNames.splash,
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const SplashScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
      ),
      GoRoute(
        path: RouteList.auth,
        name: RouteNames.auth,
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const AuthScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
      ),
      GoRoute(
        path: RouteList.home,
        name: RouteNames.home,
        pageBuilder:
            (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const HomeScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                final tween = Tween(begin: begin, end: end);
                final offsetAnimation = animation.drive(tween);
                return SlideTransition(position: offsetAnimation, child: child);
              },
            ),
      ),
      GoRoute(
        path: RouteList.lobby,
        name: RouteNames.lobby,
        pageBuilder: (context, state) {
          final roomId = state.uri.queryParameters['roomId'] ?? '';
          return CustomTransitionPage(
            key: state.pageKey,
            child: LobbyScreen(roomId: roomId),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              final tween = Tween(begin: begin, end: end);
              final offsetAnimation = animation.drive(tween);
              return SlideTransition(position: offsetAnimation, child: child);
            },
          );
        },
      ),
      GoRoute(
        path: RouteList.game,
        name: RouteNames.game,
        pageBuilder: (context, state) {
          final roomId = state.uri.queryParameters['roomId'] ?? '';
          return CustomTransitionPage(
            key: state.pageKey,
            child: GameScreen(roomId: roomId),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child);
            },
          );
        },
      ),
    ],
  );
  static GoRouter get router => _router;
}

class PifPafPoufMain extends StatelessWidget {
  const PifPafPoufMain({super.key});

  @override
  Widget build(BuildContext context) {
    // Configurer les préférences système
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.primary,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return MaterialApp.router(
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData mediaQueryData = MediaQuery.of(context);
        const double textScaleFactor = 1.0;
        return MediaQuery(
          data: mediaQueryData.copyWith(
            textScaler: const TextScaler.linear(textScaleFactor),
            padding: mediaQueryData.padding.copyWith(top: mediaQueryData.padding.top),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      scaffoldMessengerKey: alertKey,
      debugShowCheckedModeBanner: false,
      title: "Pif Paf Pouf",
      themeMode: ThemeMode.system,
      theme: ThemeProvider.lightTheme,
      darkTheme: ThemeProvider.darkTheme,
      routerConfig: AppRouter.router,
    );
  }
}
