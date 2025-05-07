import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AnimationUtils {
  // Appliquer un feedback haptique avec animation d'échelle
  static Widget withTapEffect({
    required Widget child,
    required VoidCallback onTap,
    double scaleFactor = 0.95,
    Duration duration = const Duration(milliseconds: 150),
    bool enableFeedback = true,
  }) {
    return TapEffect(onTap: onTap, scaleFactor: scaleFactor, duration: duration, enableFeedback: enableFeedback, child: child);
  }

  // Créer une animation de rebond
  static Animation<double> createBounceAnimation({
    required AnimationController controller,
    double begin = 0.0,
    double end = 1.0,
    Curve curve = Curves.elasticOut,
  }) {
    return Tween<double>(begin: begin, end: end).animate(CurvedAnimation(parent: controller, curve: curve));
  }

  // Animation de texte dactylographié
  static Widget typingText({
    required String text,
    required AnimationController controller,
    TextStyle? style,
    TextAlign? textAlign,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final int charCount = (text.length * controller.value).round();
        return Text(text.substring(0, charCount), style: style, textAlign: textAlign);
      },
    );
  }
}

class TapEffect extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleFactor;
  final Duration duration;
  final bool enableFeedback;

  const TapEffect({
    Key? key,
    required this.child,
    required this.onTap,
    this.scaleFactor = 0.95,
    this.duration = const Duration(milliseconds: 150),
    this.enableFeedback = true,
  }) : super(key: key);

  @override
  State<TapEffect> createState() => _TapEffectState();
}

class _TapEffectState extends State<TapEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        if (widget.enableFeedback) {
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) {
        _controller.reverse();
      },
      onTapCancel: () {
        _controller.reverse();
      },
      onTap: () {
        widget.onTap();
      },
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}
