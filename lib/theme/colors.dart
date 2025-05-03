import 'package:flutter/material.dart' show Color, Colors, Offset, Shadow;

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
