import 'package:flutter/material.dart';

/// Modèle pour représenter un choix dans le jeu
class GameChoiceModel {
  final String id; // Identifiant unique du choix
  final String name; // Nom technique du choix
  final String displayName; // Nom à afficher
  final String imagePath; // Chemin vers l'image
  final String svgPath; // Chemin vers l'SVG (si disponible)
  final Color color; // Couleur associée au choix
  final List<String> beats; // Liste des choix que ce choix bat

  const GameChoiceModel({
    required this.id,
    required this.name,
    required this.displayName,
    required this.imagePath,
    this.svgPath = '',
    required this.color,
    required this.beats,
  });

  /// Vérifie si ce choix bat un autre choix
  bool canBeat(GameChoiceModel other) {
    return beats.contains(other.id);
  }

  /// Clone le modèle avec de nouvelles valeurs
  GameChoiceModel copyWith({
    String? id,
    String? name,
    String? displayName,
    String? imagePath,
    String? svgPath,
    Color? color,
    List<String>? beats,
  }) {
    return GameChoiceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      imagePath: imagePath ?? this.imagePath,
      svgPath: svgPath ?? this.svgPath,
      color: color ?? this.color,
      beats: beats ?? this.beats,
    );
  }
}
