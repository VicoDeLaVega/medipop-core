import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Segmented level meter (green → yellow → red) with a falling peak marker,
/// so the clinician can see at a glance that the microphone hears them.
class VuMeter extends StatefulWidget {
  const VuMeter({
    super.key,
    required this.level,
    required this.active,
    this.segments = 24,
  });

  /// Input level in 0..1.
  final double level;
  final bool active;
  final int segments;

  @override
  State<VuMeter> createState() => _VuMeterState();
}

class _VuMeterState extends State<VuMeter> {
  double _peak = 0;
  Timer? _fall;

  @override
  void didUpdateWidget(VuMeter old) {
    super.didUpdateWidget(old);
    if (widget.level > _peak) _peak = widget.level;
    if (widget.active) {
      _fall ??= Timer.periodic(const Duration(milliseconds: 60), (_) {
        if (mounted) setState(() => _peak = math.max(0, _peak - 0.02));
      });
    } else {
      _fall?.cancel();
      _fall = null;
      _peak = 0;
    }
  }

  @override
  void dispose() {
    _fall?.cancel();
    super.dispose();
  }

  Color _segmentColor(double position) {
    if (position > 0.85) return Colors.red;
    if (position > 0.65) return Colors.amber;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.segments;
    final lit = widget.active ? (widget.level * n).ceil() : 0;
    final peak = widget.active ? (_peak * n).ceil() - 1 : -1;
    final off = Theme.of(context).colorScheme.surfaceContainerHighest;

    return SizedBox(
      height: 28,
      child: Row(
        children: [
          for (var i = 0; i < n; i++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: i < lit || (i == peak && peak > 0)
                      ? _segmentColor(i / (n - 1))
                      : off,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
