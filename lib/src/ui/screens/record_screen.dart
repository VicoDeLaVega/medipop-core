import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/extraction_service.dart';
import '../../services/stt_service.dart';
import '../../runtime/providers.dart';
import '../widgets/mic_button.dart';
import '../widgets/stt_console.dart';
import '../widgets/vu_meter.dart';
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
  StreamSubscription<double>? _levelSub;
  Timer? _decay;
  double _level = 0;
  DateTime? _lastSound;
  late final _package = ref.read(workspaceProvider).workspace!.package;
  late String _locale = _package.locale;
  String get _localeKey => 'medipop_dictation_locale_${_package.id}';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getString(_localeKey);
      if (mounted && saved != null && _package.locales.contains(saved)) {
        setState(() => _locale = saved);
      }
    });
  }

  Future<void> _chooseLocale(String locale) async {
    setState(() => _locale = locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale);
  }

  void _log(String message) {
    debugPrint('[RecordScreen] $message');
  }

  @override
  void dispose() {
    _sub?.cancel();
    _stopLevel();
    unawaited(_stt.cancel());
    super.dispose();
  }

  /// Follows the microphone level. Partial transcripts also count as sound,
  /// so the indicator still reacts on platforms that report no level.
  void _startLevel() {
    _lastSound = null;
    _levelSub?.cancel();
    _levelSub = _stt.levelStream.listen((l) => _heard(l));
    _decay?.cancel();
    _decay = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted) setState(() => _level *= 0.8);
    });
  }

  void _heard(double level) {
    if (level > 0.15) _lastSound = DateTime.now();
    if (mounted && level > _level) setState(() => _level = level);
  }

  void _stopLevel() {
    _levelSub?.cancel();
    _levelSub = null;
    _decay?.cancel();
    _decay = null;
    _level = 0;
  }

  bool get _silent =>
      _listening &&
      (_lastSound == null ||
          DateTime.now().difference(_lastSound!) > const Duration(seconds: 4));

  Future<void> _start() async {
    _log('Mic button tapped.');
    final stt = _stt;
    _sub?.cancel();
    _sub = stt.transcriptStream.listen(
      (text) {
        _log('Transcript stream emitted ${text.length} characters.');
        if (mounted) setState(() => _transcript = text);
        _heard(0.6);
      },
      onError: (_) {
        _stopLevel();
        if (mounted) setState(() => _listening = false);
      },
    );
    final ok = await stt.start(localeId: _locale);
    if (!mounted) return;
    _log('stt.start() returned $ok');
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied.')),
      );
      return;
    }
    _startLevel();
    setState(() => _listening = true);
  }

  Future<void> _stop() async {
    _log('Stop requested from UI.');
    final stt = _stt;
    final finalText = await stt.stop();
    _log('Final transcript length after stop: ${finalText.length}');
    if (!mounted) return;
    _stopLevel();
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
      final draft = await svc.extract(_transcript, locale: _locale);
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => ReviewScreen(draft: draft)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Extraction failed: $e')));
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
            if (_package.locales.length > 1) ...[
              SegmentedButton<String>(
                segments: [
                  for (final l in _package.locales)
                    ButtonSegment(value: l, label: Text(_languageName(l))),
                ],
                selected: {_locale},
                onSelectionChanged: _listening || _processing
                    ? null
                    : (s) => _chooseLocale(s.single),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
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
            MicButton(isListening: _listening, onStart: _start, onStop: _stop),
            const SizedBox(height: 16),
            VuMeter(level: _level, active: _listening),
            const SizedBox(height: 8),
            SizedBox(
              height: 24,
              child: _listening
                  ? Text(
                      _silent
                          ? 'No sound detected — check the microphone'
                          : 'Listening…',
                      style: TextStyle(
                        color: _silent
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  : null,
            ),
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
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 8,
                ),
                child: Text(_processing ? 'Extracting...' : 'Extract fields'),
              ),
            ),
            const SizedBox(height: 16),
            SttConsole(stt: _stt),
          ],
        ),
      ),
    );
  }
}

const _knownLanguages = {
  'en': 'English',
  'fr': 'Français',
  'es': 'Español',
  'pt': 'Português',
  'de': 'Deutsch',
  'it': 'Italiano',
};

String _languageName(String locale) {
  final parts = locale.split('_');
  final name = _knownLanguages[parts.first] ?? parts.first.toUpperCase();
  return parts.length > 1 ? '$name (${parts[1]})' : name;
}
