import 'package:flutter/material.dart';
import 'package:pif_paf_pouf/theme/colors.dart';

/*
class AppColors {
  // Couleurs principales
  static const Color primary = Color(0xFFFF9800); // Orange vif
  static const Color primaryLight = Color.fromARGB(255, 255, 216, 164); // Orange clair
  static const Color primaryDark = Color(0xFFF57C00); // Orange foncé

  // Couleurs secondaires (Teal)
  static const Color secondary = Color(0xFF009688); // Teal (équilibre chaud/froid) :contentReference[oaicite:0]{index=0}
  static const Color secondaryLight = Color(0xFF4DB6AC); // Teal clair :contentReference[oaicite:1]{index=1}
  static const Color secondaryDark = Color(0xFF00796B); // Teal foncé :contentReference[oaicite:2]{index=2}

  // Couleurs d'accentuation
  static const Color accent = Color(0xFFFFC107); // Ambre
  static const Color accentLight = Color(0xFFFFD54F); // Ambre clair
  static const Color accentDark = Color(0xFFFFA000); // Ambre foncé

  // Couleurs de fond et de surface
  static const Color background = Color(0xFFFFF8E1); // Beige clair
  static const Color surface = Color(0xFFFFFFFF); // Blanc

  // Couleurs de texte
  static const Color onPrimary = Color(0xFFFFFFFF); // Blanc
  static const Color onSecondary = Color(0xFFFFFFFF); // Blanc (sur secondary)
  static const Color onBackground = Color(0xFF000000); // Noir
  static const Color onSurface = Color(0xFF000000); // Noir
}

*/

class ThemeProvider {
  // Light Theme
  static ThemeData lightTheme = ThemeData(
    fontFamily: 'Chewy',
    useMaterial3: true,
    colorSchemeSeed: AppColors.primary,
    brightness: Brightness.light,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: Color(0xFF000000),
        fontFamily: 'Chewy',
        shadows: [
          Shadow(color: AppColors.primaryDark, offset: Offset(2, 2), blurRadius: 3),
          Shadow(color: AppColors.primaryLight, offset: Offset(-2, -2), blurRadius: 3),
        ],
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primary)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primary)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primary)),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.onBackground),
      bodyMedium: TextStyle(color: AppColors.onBackground),
      displayLarge: TextStyle(color: AppColors.onBackground),
      displayMedium: TextStyle(color: AppColors.onBackground),
      displaySmall: TextStyle(color: AppColors.onBackground),
      headlineMedium: TextStyle(color: AppColors.onBackground),
      headlineSmall: TextStyle(color: AppColors.onBackground),
      titleLarge: TextStyle(color: AppColors.onBackground),
    ),
    scaffoldBackgroundColor: AppColors.background,
  );

  // The dark theme is similar to the light theme but with different colors for dark mode.
  // You can customize the colors as per your design requirements.
  static ThemeData darkTheme = ThemeData(
    fontFamily: 'Chewy',
    useMaterial3: true,
    colorSchemeSeed: AppColors.primary,
    brightness: Brightness.dark,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: Color(0xFFFFFFFF),
        fontFamily: 'Chewy',
        shadows: [
          Shadow(color: AppColors.primaryDark, offset: Offset(2, 2), blurRadius: 3),
          Shadow(color: AppColors.primaryLight, offset: Offset(-2, -2), blurRadius: 3),
        ],
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primary)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primary)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primary)),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.onBackground),
      bodyMedium: TextStyle(color: AppColors.onBackground),
      displayLarge: TextStyle(color: AppColors.onBackground),
      displayMedium: TextStyle(color: AppColors.onBackground),
      displaySmall: TextStyle(color: AppColors.onBackground),
      headlineMedium: TextStyle(color: AppColors.onBackground),
      headlineSmall: TextStyle(color: AppColors.onBackground),
      titleLarge: TextStyle(color: AppColors.onBackground),
    ),
    scaffoldBackgroundColor: AppColors.background,
  );
}
