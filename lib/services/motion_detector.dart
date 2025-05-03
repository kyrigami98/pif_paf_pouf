import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

class MotionDetector {
  static final MotionDetector _instance = MotionDetector._internal();
  factory MotionDetector() => _instance;
  MotionDetector._internal();

  // Seuils de détection pour le mouvement "tchin"
  final double _impactThreshold = 25.0; // Augmentation du seuil pour éviter les faux positifs
  final double _gyroThreshold = 5.0; // Seuil de rotation pour confirmer un vrai impact
  final double _timeWindowMs = 300; // Fenêtre temporelle pour détecter un impact (ms)

  bool _isListening = false;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  final _tchinDetectedController = StreamController<void>.broadcast();
  Stream<void> get onTchinDetected => _tchinDetectedController.stream;

  double _lastImpactTime = 0;
  bool _isImpactCooldown = false;

  // Valeurs des capteurs
  List<double> _accelerometerValues = [0, 0, 0];
  List<double> _gyroscopeValues = [0, 0, 0];

  // Historique des mouvements récents pour analyse
  final List<double> _recentMagnitudes = [];
  final int _historyLength = 10;

  void startListening() {
    if (_isListening) return;

    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      _accelerometerValues = [event.x, event.y, event.z];

      // Conserver l'historique des magnitudes récentes
      double currentMagnitude = _calculateMagnitude(_accelerometerValues);
      _addToHistory(currentMagnitude);

      _detectTchin();
    });

    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      _gyroscopeValues = [event.x, event.y, event.z];
    });

    _isListening = true;
    debugPrint('Motion detector listening started');
  }

  void _addToHistory(double magnitude) {
    _recentMagnitudes.add(magnitude);
    if (_recentMagnitudes.length > _historyLength) {
      _recentMagnitudes.removeAt(0);
    }
  }

  void stopListening() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _isListening = false;
    debugPrint('Motion detector listening stopped');
  }

  void _detectTchin() {
    // Calcul de la magnitude de l'accélération
    double magnitude = _calculateMagnitude(_accelerometerValues);
    double gyroMagnitude = _calculateMagnitude(_gyroscopeValues);

    // Détection d'un pic soudain (rapport entre la valeur actuelle et la moyenne récente)
    double averageMagnitude = _calculateAverageMagnitude();
    double impactRatio = magnitude / (averageMagnitude > 0 ? averageMagnitude : 1);

    // Vérifier si l'impact est supérieur au seuil et pas en cooldown
    // et si une rotation est également détectée (pour confirmer un vrai impact physique)
    if (magnitude > _impactThreshold &&
        impactRatio > 3.0 && // Le pic doit être au moins 3x la moyenne récente
        gyroMagnitude > _gyroThreshold &&
        !_isImpactCooldown) {
      double currentTime = DateTime.now().millisecondsSinceEpoch.toDouble();

      // Éviter les détections multiples trop rapprochées
      if (currentTime - _lastImpactTime > _timeWindowMs) {
        _lastImpactTime = currentTime;
        _isImpactCooldown = true;

        // Faire vibrer l'appareil pour feedback
        _vibrate();

        // Émettre l'événement de tchin détecté
        _tchinDetectedController.add(null);
        debugPrint('TCHIN détecté! Magnitude: $magnitude, Gyro: $gyroMagnitude, Ratio: $impactRatio');

        // Réinitialiser le cooldown après un délai
        Timer(Duration(milliseconds: _timeWindowMs.toInt()), () {
          _isImpactCooldown = false;
        });
      }
    }
  }

  double _calculateMagnitude(List<double> values) {
    return (values[0] * values[0] + values[1] * values[1] + values[2] * values[2]).abs();
  }

  double _calculateAverageMagnitude() {
    if (_recentMagnitudes.isEmpty) return 0;
    double sum = _recentMagnitudes.fold(0, (prev, curr) => prev + curr);
    return sum / _recentMagnitudes.length;
  }

  Future<void> _vibrate() async {
    HapticFeedback.heavyImpact(); // Vibration plus forte pour un feedback plus clair
  }

  void dispose() {
    stopListening();
    _tchinDetectedController.close();
  }
}
