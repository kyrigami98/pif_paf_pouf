import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';

class MotionDetector {
  static final MotionDetector _instance = MotionDetector._internal();
  factory MotionDetector() => _instance;
  MotionDetector._internal();

  // Seuils de détection pour le mouvement "tchin"
  final double _impactThreshold = 15.0; // Seuil d'accélération pour considérer un impact
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

  void startListening() {
    if (_isListening) return;

    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      _accelerometerValues = [event.x, event.y, event.z];
      _detectTchin();
    });

    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      _gyroscopeValues = [event.x, event.y, event.z];
    });

    _isListening = true;
    debugPrint('Motion detector listening started');
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

    // Vérifier si l'impact est supérieur au seuil et pas en cooldown
    if (magnitude > _impactThreshold && !_isImpactCooldown) {
      double currentTime = DateTime.now().millisecondsSinceEpoch.toDouble();

      // Éviter les détections multiples trop rapprochées
      if (currentTime - _lastImpactTime > _timeWindowMs) {
        _lastImpactTime = currentTime;
        _isImpactCooldown = true;

        // Faire vibrer l'appareil pour feedback
        _vibrate();

        // Émettre l'événement de tchin détecté
        _tchinDetectedController.add(null);
        debugPrint('TCHIN détecté! Magnitude: $magnitude');

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

  Future<void> _vibrate() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 150);
    }
  }

  void dispose() {
    stopListening();
    _tchinDetectedController.close();
  }
}
