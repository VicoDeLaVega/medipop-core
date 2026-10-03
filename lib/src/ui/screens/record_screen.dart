import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/extraction_service.dart';
import '../../services/stt_service.dart';
import '../../runtime/providers.dart';
import '../widgets/mic_button.dart';
import 'review_screen.dart';

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  late final SttService _stt = ref.read(sttServiceProvider);
  String _transcript = '';
  bool _listening = false;
  bool _processing = false;
  StreamSubscription<String>? _sub;

  void _log(String message) {
    debugPrint('[RecordScreen] $message');
  }

  @override
  void dispose() {
    _sub?.cancel();
    unawaited(_stt.cancel());
    super.dispose();
  }

  Future<void> _start() async {
    _log('Mic button tapped.');
    final stt = _stt;
    _sub?.cancel();
    _sub = stt.transcriptStream.listen((text) {
      _log('Transcript stream emitted ${text.length} characters.');
      if (mounted) setState(() => _transcript = text);
    }, onError: (_) {
      if (mounted) setState(() => _listening = false);
    });
    final ok = await stt.start(
        localeId: ref.read(workspaceProvider).workspace!.package.locale);
    if (!mounted) return;
    _log('stt.start() returned $ok');
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied.')),
      );
      return;
    }
    setState(() => _listening = true);
  }

  Future<void> _stop() async {
    _log('Stop requested from UI.');
    final stt = _stt;
    final finalText = await stt.stop();
    _log('Final transcript length after stop: ${finalText.length}');
    if (!mounted) return;
    setState(() {
      _listening = false;
      _transcript = finalText.isNotEmpty ? finalText : _transcript;
    });
  }

  Future<void> _extract() async {
    if (_transcript.trim().isEmpty) return;
    setState(() => _processing = true);
    try {
      final svc = ref.read(extractionServiceProvider);
      final draft = await svc.extract(_transcript);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReviewScreen(draft: draft)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Extraction failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(extractionServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dictate consultation')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _transcript.isEmpty
                        ? 'Tap the mic and start dictating...'
                        : _transcript,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            MicButton(
              isListening: _listening,
              onStart: _start,
              onStop: _stop,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: (_listening || _processing || _transcript.isEmpty)
                  ? null
                  : _extract,
              icon: _processing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Text(_processing ? 'Extracting...' : 'Extract fields'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
