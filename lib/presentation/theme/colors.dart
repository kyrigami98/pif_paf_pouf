import 'package:flutter/material.dart' show Color, Colors, Offset, Shadow;

class AppColors {
  // Couleurs principales - palette modernisée
  static const Color primary = Color(0xFF6A5AE0); // Violet moderne
  static const Color primaryLight = Color(0xFFEAE8FD); // Violet très clair
  static const Color primaryDark = Color(0xFF4E41B0); // Violet foncé

  // Couleurs secondaires
  static const Color secondary = Color(0xFFFF8C00); // Orange vibrant
  static const Color secondaryLight = Color(0xFFFFDEA9); // Orange clair
  static const Color secondaryDark = Color(0xFFE67E00); // Orange foncé

  // Couleurs d'accentuation
  static const Color accent = Color(0xFF00C9A7); // Turquoise
  static const Color accentLight = Color(0xFFB5F5EA); // Turquoise clair
  static const Color accentDark = Color(0xFF00A086); // Turquoise foncé

  // Couleurs de fond et de surface
  static const Color background = Color(0xFFF6F7FB); // Gris très clair
  static const Color surface = Color(0xFFFFFFFF); // Blanc
  static const Color card = Color(0xFFFFFFFF); // Blanc
  static const Color cardDark = Color(0xFFF0F2F8); // Gris clair

  // Couleurs de texte
  static const Color onPrimary = Color(0xFFFFFFFF); // Blanc
  static const Color onSecondary = Color(0xFFFFFFFF); // Blanc (sur secondary)
  static const Color onBackground = Color(0xFF1D1E2C); // Presque noir
  static const Color onSurface = Color(0xFF1D1E2C); // Presque noir
  static const Color textMuted = Color(0xFF9FA1B2); // Gris moyen

  // Couleurs de statut
  static const Color success = Color(0xFF4CAF50); // Vert
  static const Color error = Color(0xFFE53935); // Rouge
  static const Color warning = Color(0xFFFFB300); // Ambre

  // Couleurs des éléments de jeu
  static const Color rock = Color(0xFF6A5AE0); // Violet (primaire)
  static const Color paper = Color(0xFF00C9A7); // Turquoise
  static const Color scissors = Color(0xFFFF8C00); // Orange
}
