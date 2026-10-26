import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/stt_service.dart';

/// Small scrolling console with the dictation diagnostics (permissions,
/// microphones, recognizer status, errors), newest line at the bottom.
class SttConsole extends StatefulWidget {
  const SttConsole({super.key, required this.stt, this.height = 120});

  final SttService stt;
  final double height;

  @override
  State<SttConsole> createState() => _SttConsoleState();
}

class _SttConsoleState extends State<SttConsole> {
  late final List<String> _lines = [...widget.stt.logLines];
  final _scroll = ScrollController();
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.stt.logStream.listen((line) {
      if (!mounted) return;
      setState(() => _lines.add(line));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _lines.isEmpty
          ? const Text(
              'Dictation log — tap the mic to start.',
              style: TextStyle(
                color: Color(0xFF8A8A8A),
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            )
          : ListView.builder(
              controller: _scroll,
              itemCount: _lines.length,
              itemBuilder: (_, i) => Text(
                _lines[i],
                style: const TextStyle(
                  color: Color(0xFFB5E3B5),
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
    );
  }
}
