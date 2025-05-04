import 'package:flutter/material.dart';
import 'package:pif_paf_pouf/theme/colors.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeProvider {
  // Police principale
  static final TextTheme _baseTextTheme = GoogleFonts.poppinsTextTheme();

  // Entêtes avec police de jeu
  static TextStyle gameHeadingStyle = GoogleFonts.comfortaa(fontWeight: FontWeight.bold, color: AppColors.primary);

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    fontFamily: GoogleFonts.poppins().fontFamily,
    useMaterial3: true,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: gameHeadingStyle.copyWith(fontSize: 26, color: AppColors.onPrimary, letterSpacing: 1.2),
      iconTheme: const IconThemeData(color: AppColors.onPrimary),
    ),

    cardTheme: CardTheme(
      color: AppColors.card,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 3,
        shadowColor: AppColors.primary.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardDark,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      labelStyle: const TextStyle(color: AppColors.textMuted),
      hintStyle: const TextStyle(color: AppColors.textMuted),
    ),

    textTheme: _baseTextTheme.copyWith(
      displayLarge: _baseTextTheme.displayLarge?.copyWith(color: AppColors.onBackground),
      displayMedium: _baseTextTheme.displayMedium?.copyWith(color: AppColors.onBackground),
      displaySmall: _baseTextTheme.displaySmall?.copyWith(color: AppColors.onBackground),
      headlineLarge: gameHeadingStyle.copyWith(fontSize: 32),
      headlineMedium: gameHeadingStyle.copyWith(fontSize: 28),
      headlineSmall: gameHeadingStyle.copyWith(fontSize: 24),
      titleLarge: _baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      titleMedium: _baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.card,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    scaffoldBackgroundColor: AppColors.background,
    dividerColor: AppColors.cardDark,
    dialogTheme: DialogThemeData(backgroundColor: AppColors.card),
  );

  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    fontFamily: GoogleFonts.poppins().fontFamily,
    useMaterial3: true,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      error: AppColors.error,
      onError: Colors.white,
      surface: Color(0xFF1E1E1E),
      onSurface: Colors.white,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: gameHeadingStyle.copyWith(fontSize: 26, color: AppColors.onPrimary, letterSpacing: 1.2),
      iconTheme: const IconThemeData(color: AppColors.onPrimary),
    ),

    cardTheme: CardTheme(
      color: const Color(0xFF1E1E1E),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 3,
        shadowColor: AppColors.primary.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
    ),

    textTheme: _baseTextTheme.copyWith(
      displayLarge: _baseTextTheme.displayLarge?.copyWith(color: Colors.white),
      displayMedium: _baseTextTheme.displayMedium?.copyWith(color: Colors.white),
      displaySmall: _baseTextTheme.displaySmall?.copyWith(color: Colors.white),
      headlineLarge: gameHeadingStyle.copyWith(fontSize: 32, color: Colors.white),
      headlineMedium: gameHeadingStyle.copyWith(fontSize: 28, color: Colors.white),
      headlineSmall: gameHeadingStyle.copyWith(fontSize: 24, color: Colors.white),
      titleLarge: _baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
      titleMedium: _baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
      bodyLarge: _baseTextTheme.bodyLarge?.copyWith(color: Colors.white),
      bodyMedium: _baseTextTheme.bodyMedium?.copyWith(color: Colors.white),
    ),

    scaffoldBackgroundColor: const Color(0xFF121212),
  );
}
