import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final double scaleDownFactor; // Quanto si rimpicciolisce (es. 0.95)

  const BouncyButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.scaleDownFactor = 0.95,
  });

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Quando tocchi: Schiaccia e Vibra
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.lightImpact(); // Feedback tattile immediato
      },
      // Quando rilasci o cancelli (es. scorri via): Torna normale
      onTapUp: (_) {
        setState(() => _isPressed = false);
        // Ritarda l'azione per far vedere l'animazione di rilascio
        Future.delayed(const Duration(milliseconds: 100), () {
          widget.onPressed();
        });
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      
      // L'animazione vera e propria
      child: AnimatedScale(
        scale: _isPressed ? widget.scaleDownFactor : 1.0,
        duration: const Duration(milliseconds: 100), // Molto veloce
        curve: Curves.easeInOut, // Curva morbida
        child: widget.child,
      ),
    );
  }
}