import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pif_paf_pouf/theme/colors.dart';

enum Choice {
  pierre(
    displayName: 'Pierre',
    color: AppColors.rock, // Utilisation de la couleur thématique
    beats: ['ciseaux'],
    imagePath: 'assets/images/rock.png',
    svgPath: 'assets/svg/rock.svg',
  ),

  papier(
    displayName: 'Papier',
    color: AppColors.paper, // Utilisation de la couleur thématique
    beats: ['pierre'],
    imagePath: 'assets/images/paper.png',
    svgPath: 'assets/svg/paper.svg',
  ),

  ciseaux(
    displayName: 'Ciseaux',
    color: AppColors.scissors, // Utilisation de la couleur thématique
    beats: ['papier'],
    imagePath: 'assets/images/scissors.png',
    svgPath: 'assets/svg/scissors.svg',
  );

  final String displayName;
  final Color color;
  final List<String> beats;
  final String imagePath;
  final String svgPath;

  const Choice({
    required this.displayName,
    required this.color,
    required this.beats,
    required this.imagePath,
    required this.svgPath,
  });

  // Vérifie si ce choix bat un autre choix
  bool canBeat(Choice other) {
    return beats.contains(other.name);
  }

  // Conversion depuis String
  static Choice fromString(String value) {
    switch (value) {
      case 'papier':
        return Choice.papier;
      case 'ciseaux':
        return Choice.ciseaux;
      case 'pierre':
      default:
        return Choice.pierre;
    }
  }

  // Conversion vers String pour Firestore
  String toFirestore() {
    return name;
  }
}

class GameChoice {
  final String playerId;
  final Choice choice;
  final DateTime? timestamp;

  GameChoice({required this.playerId, required this.choice, this.timestamp});

  // Factory pour créer un GameChoice à partir d'un document Firestore
  factory GameChoice.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GameChoice(
      playerId: doc.id,
      choice: Choice.fromString(data['choice'] ?? 'pierre'),
      timestamp: data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : null,
    );
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'choice': choice.toFirestore(),
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : FieldValue.serverTimestamp(),
    };
  }

  // Déterminer qui gagne entre deux choix
  static Choice? getWinner(List<Choice> choices) {
    // Compter les occurrences de chaque choix
    int pierreCount = 0;
    int papierCount = 0;
    int ciseauxCount = 0;

    for (var choice in choices) {
      if (choice == Choice.pierre) pierreCount++;
      if (choice == Choice.papier) papierCount++;
      if (choice == Choice.ciseaux) ciseauxCount++;
    }

    // Déterminer le choix gagnant selon les règles classiques
    if (pierreCount > 0 && papierCount > 0 && ciseauxCount == 0) {
      return Choice.papier; // Papier bat pierre
    } else if (papierCount > 0 && ciseauxCount > 0 && pierreCount == 0) {
      return Choice.ciseaux; // Ciseaux bat papier
    } else if (pierreCount > 0 && ciseauxCount > 0 && papierCount == 0) {
      return Choice.pierre; // Pierre bat ciseaux
    } else if (pierreCount > 0 && papierCount > 0 && ciseauxCount > 0) {
      // Si tous les choix sont présents, personne ne gagne
      return null;
    } else {
      // Si tout le monde a fait le même choix, personne ne gagne
      return null;
    }
  }
}
