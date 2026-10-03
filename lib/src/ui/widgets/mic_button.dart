import 'package:flutter/material.dart';

class MicButton extends StatelessWidget {
  const MicButton({
    super.key,
    required this.isListening,
    required this.onStart,
    required this.onStop,
  });

  final bool isListening;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final color =
        isListening ? Colors.red : Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: isListening ? onStop : onStart,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: isListening ? 28 : 12,
              spreadRadius: isListening ? 4 : 0,
            ),
          ],
        ),
        child: Icon(
          isListening ? Icons.stop_rounded : Icons.mic_rounded,
          color: Colors.white,
          size: 52,
        ),
      ),
    );
  }
}
