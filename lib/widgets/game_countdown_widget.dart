import 'package:flutter/material.dart';
import 'package:pif_paf_pouf/theme/colors.dart';

class GameCountdown extends StatelessWidget {
  final double progress;
  final int secondsRemaining;
  final String message;
  final bool isActive;

  const GameCountdown({
    Key? key,
    required this.progress,
    required this.secondsRemaining,
    this.message = "Choix automatique dans",
    this.isActive = true,
  }) : super(key: key);

  Color _getProgressColor() {
    if (progress > 0.6) return AppColors.success;
    if (progress > 0.3) return Colors.orange;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    if (!isActive) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          height: 8,
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: _getProgressColor(),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [BoxShadow(color: _getProgressColor().withOpacity(0.5), blurRadius: 5, offset: const Offset(0, 2))],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("$message ", style: const TextStyle(fontSize: 13, color: Colors.grey)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: _getProgressColor().withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
              child: Row(
                children: [
                  Icon(Icons.timer, size: 12, color: _getProgressColor()),
                  const SizedBox(width: 4),
                  Text(
                    "$secondsRemaining s",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _getProgressColor()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
