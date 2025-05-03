import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pif_paf_pouf/app/app_keys.dart';
import 'package:pif_paf_pouf/app/routes.dart';
import 'package:pif_paf_pouf/services/firebase_service.dart';
import 'package:pif_paf_pouf/services/nearby_service.dart';
import 'package:pif_paf_pouf/services/motion_detector.dart';
import 'package:pif_paf_pouf/theme/colors.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> with SingleTickerProviderStateMixin {
  final NearbyService _nearbyService = NearbyService();
  final MotionDetector _motionDetector = MotionDetector();
  final FirebaseService _firebaseService = FirebaseService();

  late AnimationController _pingController;
  late Animation<double> _pingAnimation;

  String _username = "";
  bool _isLoading = true;
  bool _isTchining = false;
  bool _permissionsGranted = false;
  String _statusMessage = "Initialisation...";

  // Pour suivre les appareils qui ont reçu le tchin
  final Set<String> _tchinReceivedFrom = {};

  @override
  void initState() {
    super.initState();

    // Configuration de l'animation du ping
    _pingController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

    _pingAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _pingController, curve: Curves.easeOut));

    _initializeServices();
  }

  Future<void> _initializeServices() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Vérification de l'authentification...";
    });

    try {
      // Récupérer le nom d'utilisateur
      final username = await _firebaseService.getLocalUsername();
      if (username != null) {
        setState(() {
          _username = username;
          _statusMessage = "Initialisation des services...";
        });
      } else {
        _showErrorMessage("Vous devez être connecté pour utiliser le radar");
        if (mounted) context.go(RouteList.auth);
        return;
      }

      // Initialiser le service nearby
      await _nearbyService.initialize();

      // Vérifier les permissions
      setState(() {
        _statusMessage = "Vérification des permissions...";
      });

      _permissionsGranted = await _nearbyService.checkPermissions();
      if (!_permissionsGranted) {
        setState(() {
          _statusMessage = "Demande des permissions nécessaires...";
        });
        await _nearbyService.requestPermissions();
        _permissionsGranted = await _nearbyService.checkPermissions();
      }

      if (_permissionsGranted) {
        setState(() {
          _statusMessage = "Démarrage de la découverte...";
        });

        // Démarrer l'advertising et discovery
        await _nearbyService.startAdvertising();
        await _nearbyService.startDiscovery();

        // Écouter les événements "tchin"
        _motionDetector.startListening();
        _motionDetector.onTchinDetected.listen(_handleLocalTchin);

        // Écouter les événements de tchin reçus
        _nearbyService.onTchinSuccess.listen(_handleRemoteTchin);

        setState(() {
          _statusMessage = "Radar actif - En attente d'appareils à proximité";
          _isLoading = false;
        });
      } else {
        _showErrorMessage("Permissions refusées. Le radar ne peut pas fonctionner sans ces permissions.");
        setState(() {
          _statusMessage = "Permissions manquantes";
          _isLoading = false;
        });
      }
    } catch (e) {
      _showErrorMessage("Erreur d'initialisation: $e");
      setState(() {
        _statusMessage = "Erreur: $e";
        _isLoading = false;
      });
    }
  }

  // Gérer un tchin détecté localement (par les capteurs)
  void _handleLocalTchin(_) async {
    debugPrint("Tchin local détecté!");

    if (_isTchining) return;

    setState(() {
      _isTchining = true;
      _statusMessage = "TCHIN détecté! Envoi du signal...";
    });

    try {
      // Envoyer le signal à tous les appareils connectés
      await _nearbyService.sendTchinSignal();

      // Vérifier après un délai si on a reçu des réponses
      Future.delayed(const Duration(seconds: 2), () {
        if (_tchinReceivedFrom.isNotEmpty) {
          _handleSuccessfulTchin();
        } else {
          setState(() {
            _isTchining = false;
            _statusMessage = "Aucun appareil n'a répondu au TCHIN. Réessayez!";
          });
        }
      });
    } catch (e) {
      _showErrorMessage("Erreur lors de l'envoi du TCHIN: $e");
      setState(() {
        _isTchining = false;
        _statusMessage = "Radar actif - En attente d'appareils à proximité";
      });
    }
  }

  // Gérer un tchin reçu d'un autre appareil
  void _handleRemoteTchin(String endpointId) {
    debugPrint("Tchin reçu de $endpointId!");

    // Ajouter à la liste des tchin reçus
    setState(() {
      _tchinReceivedFrom.add(endpointId);
      if (!_isTchining) {
        _isTchining = true;
        _statusMessage = "TCHIN reçu! Traitement en cours...";
      }
    });

    // Si ce n'est pas déjà en cours, démarrer le processus de création/jointure de room
    if (_tchinReceivedFrom.length == 1) {
      Future.delayed(const Duration(seconds: 1), () {
        _handleSuccessfulTchin();
      });
    }
  }

  // Traiter un tchin réussi (local ou distant)
  void _handleSuccessfulTchin() async {
    setState(() {
      _statusMessage = "TCHIN réussi! Création de la salle...";
    });

    try {
      // Créer ou rejoindre une room
      final roomId = await _firebaseService.createOrJoinRoom(_username);

      if (roomId != null) {
        // Attendre un moment pour le feedback visuel
        await Future.delayed(const Duration(milliseconds: 500));

        // Naviguer vers le lobby
        if (mounted) {
          context.pushNamed(RouteNames.lobby, queryParameters: {'roomId': roomId});
        }
      } else {
        _showErrorMessage("Impossible de créer ou rejoindre une salle");
        setState(() {
          _isTchining = false;
          _tchinReceivedFrom.clear();
          _statusMessage = "Radar actif - En attente d'appareils à proximité";
        });
      }
    } catch (e) {
      _showErrorMessage("Erreur lors de la création de la salle: $e");
      setState(() {
        _isTchining = false;
        _tchinReceivedFrom.clear();
        _statusMessage = "Radar actif - En attente d'appareils à proximité";
      });
    }
  }

  void _showErrorMessage(String message) {
    alertKey.currentState?.showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  void dispose() {
    _pingController.dispose();
    _nearbyService.stopAdvertising();
    _nearbyService.stopDiscovery();
    _motionDetector.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondaryDark,
      appBar: AppBar(
        title: const Text("Radar", style: TextStyle(color: AppColors.onPrimary)),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        actions: [
          // Bouton pour réinitialiser les services
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.onPrimary),
            onPressed:
                _isLoading
                    ? null
                    : () {
                      _nearbyService.stopAllEndpoints();
                      _tchinReceivedFrom.clear();
                      _initializeServices();
                    },
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 20),
                    Text(_statusMessage, style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
                  ],
                ),
              )
              : Stack(
                children: [
                  // Radar view
                  Center(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _nearbyService.nearbyDevicesStream,
                      initialData: const [],
                      builder: (context, snapshot) {
                        final devices = snapshot.data ?? [];
                        return CustomPaint(
                          painter: RadarPainter(
                            pingValue: _pingAnimation.value,
                            devices: devices,
                            tchinDevices: _tchinReceivedFrom,
                            isTchining: _isTchining,
                          ),
                          size: Size.infinite,
                        );
                      },
                    ),
                  ),

                  // Statut en haut de l'écran
                  Positioned(
                    top: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusMessage,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  // Instructions
                  Positioned(
                    bottom: 30,
                    left: 20,
                    right: 20,
                    child: Column(
                      children: [
                        const Text(
                          "Faites un TCHIN avec un autre joueur\npour créer ou rejoindre une partie!",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        if (_isTchining)
                          const CircularProgressIndicator(color: AppColors.accent)
                        else
                          ElevatedButton(
                            onPressed:
                                !_permissionsGranted ? () => _nearbyService.requestPermissions() : () => _handleLocalTchin(null),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            ),
                            child: Text(
                              !_permissionsGranted ? "Accorder les permissions" : "Simuler un TCHIN",
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }
}

class RadarPainter extends CustomPainter {
  final double pingValue;
  final List<Map<String, dynamic>> devices;
  final Set<String> tchinDevices;
  final bool isTchining;

  RadarPainter({required this.pingValue, required this.devices, required this.tchinDevices, required this.isTchining});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.4;

    // Fond du radar
    final backgroundPaint =
        Paint()
          ..color = AppColors.primary.withOpacity(0.2)
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, backgroundPaint);

    // Cercles concentriques
    final circlePaint =
        Paint()
          ..color = AppColors.primary.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    // 3 cercles pour représenter les distances (1m, 3m, 5m)
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, circlePaint);
    }

    // Lignes croisées
    final linePaint =
        Paint()
          ..color = AppColors.primary.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    // Lignes horizontale et verticale
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), linePaint);

    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), linePaint);

    // Effet de ping
    final pingPaint =
        Paint()
          ..color = isTchining ? AppColors.accent.withOpacity(1 - pingValue) : AppColors.primary.withOpacity(1 - pingValue)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

    // Cercle qui s'agrandit pour simuler le ping radar
    canvas.drawCircle(center, radius * pingValue, pingPaint);

    // Point central
    final centerDotPaint =
        Paint()
          ..color = isTchining ? AppColors.accent : AppColors.primary
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8, centerDotPaint);

    // Dessiner les appareils détectés
    for (var device in devices) {
      final isConnected = device['connected'] == true;
      final isTchinDevice = tchinDevices.contains(device['id']);

      // Couleur basée sur le statut et tchin
      final deviceColor = isTchinDevice ? Colors.green : (isConnected ? AppColors.accent : Colors.grey);

      final devicePaint =
          Paint()
            ..color = deviceColor
            ..style = PaintingStyle.fill;

      final textStyle = TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold);

      // Position basée sur la distance simulée
      final distance = device['distance'] as double? ?? 3.0;
      final normalizedDistance = min(distance / 5.0, 1.0); // Normaliser entre 0 et 1

      // Angle basé sur l'ID de l'appareil
      final angle = (device['id'].hashCode % 360) * pi / 180;

      final x = center.dx + cos(angle) * radius * normalizedDistance;
      final y = center.dy + sin(angle) * radius * normalizedDistance;

      // Dessiner un halo pour les appareils connectés
      if (isConnected) {
        final haloPaint =
            Paint()
              ..color = deviceColor.withOpacity(0.3)
              ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), 20, haloPaint);
      }

      // Dessiner le point représentant l'appareil
      canvas.drawCircle(Offset(x, y), 10, devicePaint);

      // Ligne pointillée vers le centre pour les appareils tchin
      if (isTchinDevice) {
        final dashPaint =
            Paint()
              ..color = Colors.green
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2;

        _drawDashedLine(canvas, Offset(x, y), center, dashPaint);
      }

      // Afficher le nom de l'appareil
      final textSpan = TextSpan(text: device['name'], style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);

      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - 30));
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final path = Path()..moveTo(start.dx, start.dy);

    final double dashWidth = 5;
    final double dashSpace = 5;

    final dX = end.dx - start.dx;
    final dY = end.dy - start.dy;
    final count = sqrt(dX * dX + dY * dY) / (dashWidth + dashSpace);

    final deltaX = dX / count;
    final deltaY = dY / count;

    var dashX = start.dx;
    var dashY = start.dy;

    bool draw = true;
    for (int i = 0; i < count.floor(); i++) {
      if (draw) {
        path.lineTo(dashX + deltaX, dashY + deltaY);
      } else {
        path.moveTo(dashX + deltaX, dashY + deltaY);
      }

      dashX += deltaX;
      dashY += deltaY;
      draw = !draw;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) {
    return oldDelegate.pingValue != pingValue ||
        oldDelegate.devices != devices ||
        oldDelegate.tchinDevices != tchinDevices ||
        oldDelegate.isTchining != isTchining;
  }
}
