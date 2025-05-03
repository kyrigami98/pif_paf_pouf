import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pif_paf_pouf/app/app_keys.dart';
import 'package:pif_paf_pouf/app/routes.dart';
import 'package:pif_paf_pouf/screens/auth_screen.dart';
import 'package:pif_paf_pouf/screens/home_screen.dart';
import 'package:pif_paf_pouf/screens/splash_screen.dart';
import 'package:pif_paf_pouf/screens/radar_screen.dart';
import 'package:pif_paf_pouf/screens/lobby_screen.dart';
import 'package:pif_paf_pouf/theme/app_theme.dart';
import '../firebase_options.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  static final GoRouter _router = GoRouter(
    debugLogDiagnostics: true,
    navigatorKey: rootShellNavigatorKey,
    initialLocation: RouteList.splash,
    routes: [
      GoRoute(path: RouteList.splash, name: RouteNames.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: RouteList.auth, name: RouteNames.auth, builder: (context, state) => const AuthScreen()),
      GoRoute(path: RouteList.home, name: RouteNames.home, builder: (context, state) => const HomeScreen()),
      GoRoute(path: RouteList.radar, name: RouteNames.radar, builder: (context, state) => const RadarScreen()),
      GoRoute(
        path: RouteList.lobby,
        name: RouteNames.lobby,
        builder: (context, state) {
          final roomId = state.uri.queryParameters['roomId'] ?? '';
          return LobbyScreen(roomId: roomId);
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
    return MaterialApp.router(
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData mediaQueryData = MediaQuery.of(context);
        double textScaleFactor = 1.0;
        return child != null
            ? MediaQuery(data: mediaQueryData.copyWith(textScaler: TextScaler.linear(textScaleFactor)), child: child)
            : const SizedBox.shrink();
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
