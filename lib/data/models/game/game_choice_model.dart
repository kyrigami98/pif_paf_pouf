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
  final String? description; // Description optionnelle du choix
  final IconData? icon; // Icône optionnelle pour représenter le choix

  const GameChoiceModel({
    required this.id,
    required this.name,
    required this.displayName,
    required this.imagePath,
    this.svgPath = '',
    required this.color,
    required this.beats,
    this.description,
    this.icon,
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
    String? description,
    IconData? icon,
  }) {
    return GameChoiceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      imagePath: imagePath ?? this.imagePath,
      svgPath: svgPath ?? this.svgPath,
      color: color ?? this.color,
      beats: beats ?? this.beats,
      description: description ?? this.description,
      icon: icon ?? this.icon,
    );
  }

  // Pour faciliter la comparaison des choix
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GameChoiceModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
