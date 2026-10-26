import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Wraps `speech_to_text` behind a simple API:
///   - start()     -> begins listening, streams partial transcripts
///   - stop()      -> stops listening, returns the final transcript
///
/// The Flutter plugin itself talks to Apple Speech on iOS/iPadOS and
/// Android's SpeechRecognizer on Android, so no audio bytes leave the device
/// unless the underlying platform STT does so (which for English is typically
/// server-assisted on Android; swap to whisper.cpp later for fully offline).
class SttService {
  SttService();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;

  final _transcriptController = StreamController<String>.broadcast();
  final _levelController = StreamController<double>.broadcast();
  String _lastFinal = '';
  double? _minLevel;
  double? _maxLevel;

  Stream<String> get transcriptStream => _transcriptController.stream;

  /// Microphone input level normalized to 0..1, for a live UI indicator.
  /// Raw values differ by platform (dB on iOS, an unspecified scale on
  /// Android), so they are scaled against the range seen in this session.
  Stream<double> get levelStream => _levelController.stream;
  String get lastFinal => _lastFinal;
  bool get isListening => _speech.isListening;

  final _logController = StreamController<String>.broadcast();
  final List<String> _logLines = [];

  /// Recent diagnostic lines, shown in the dictation screen's console.
  List<String> get logLines => List.unmodifiable(_logLines);
  Stream<String> get logStream => _logController.stream;

  void _log(String message) {
    debugPrint('[SttService] $message');
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    final line = '$time  $message';
    _logLines.add(line);
    if (_logLines.length > 200) _logLines.removeAt(0);
    _logController.add(line);
  }

  /// Logs the microphones the system exposes. speech_to_text always records
  /// from the system default input, so this tells the user which ones exist.
  Future<void> _logInputDevices() async {
    final recorder = AudioRecorder();
    try {
      final devices = await recorder.listInputDevices();
      if (devices.isEmpty) {
        _log('Input devices: none reported by the system.');
      } else {
        _log('Input devices (dictation uses the system default):');
        for (final d in devices) {
          _log('  • ${d.label}');
        }
      }
    } catch (e) {
      _log('Input devices: could not list ($e).');
    } finally {
      await recorder.dispose();
    }
  }

  Future<bool> _ensureInitialized() async {
    if (_initialized) {
      _log('Speech service already initialized.');
      return true;
    }

    _log('Requesting microphone permission...');
    final mic = await Permission.microphone.request();
    _log('Microphone permission status: $mic');
    if (!mic.isGranted) {
      _log('Microphone permission not granted.');
      return false;
    }
    await _logInputDevices();

    final speechBefore = await Permission.speech.status;
    _log('Speech recognition permission before request: $speechBefore');
    if (speechBefore.isDenied) {
      _log('Requesting speech recognition permission...');
      final speechAfterRequest = await Permission.speech.request();
      _log('Speech recognition permission after request: $speechAfterRequest');
    }

    final speechFinal = await Permission.speech.status;
    _log('Speech recognition final status: $speechFinal');

    _log('Initializing speech_to_text...');
    _initialized = await _speech.initialize(
      onStatus: (status) {
        _log('speech_to_text status: $status');
        if (status == stt.SpeechToText.doneStatus) {
          unawaited(_stopDesktopMeter());
        }
      },
      onError: (e) {
        _log('speech_to_text error: ${e.errorMsg} (permanent: ${e.permanent})');
        _transcriptController.addError(e.errorMsg);
      },
    );
    _log('speech_to_text initialize result: $_initialized');
    if (_initialized) {
      final system = await _speech.systemLocale();
      _log('Recognizer system locale: ${system?.localeId ?? 'unknown'}');
    }
    return _initialized;
  }

  Future<bool> start({String localeId = 'en_US'}) async {
    _log('Start requested with localeId=$localeId');
    if (!await _ensureInitialized()) {
      _log('Start aborted because initialization failed.');
      return false;
    }

    _lastFinal = '';
    _minLevel = null;
    _maxLevel = null;
    _log('Calling speech.listen()...');
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: localeId,
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
      ),
      onResult: (result) {
        final text = result.recognizedWords;
        if (result.finalResult) {
          _lastFinal = text;
        }
        _transcriptController.add(text);
      },
      onSoundLevelChange: _onSoundLevel,
    );
    _log('speech.listen() started. isListening=${_speech.isListening}');
    await _startDesktopMeter();
    return true;
  }

  AudioRecorder? _meter;
  StreamSubscription<Uint8List>? _meterSub;

  /// The Windows speech plugin reports no sound level, so on desktop the
  /// meter reads the default input directly (shared mode, alongside the
  /// recognizer). Mobile recognizers own the microphone, so it is skipped
  /// there and their own level callback is used instead.
  Future<void> _startDesktopMeter() async {
    if (kIsWeb || !(Platform.isWindows || Platform.isLinux)) return;
    await _stopDesktopMeter();
    final recorder = _meter = AudioRecorder();
    try {
      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      _log('Level meter: reading the default input directly.');
      _meterSub = stream.listen(_onPcm);
    } catch (e) {
      _log('Level meter unavailable ($e).');
    }
  }

  void _onPcm(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final samples = bytes.lengthInBytes ~/ 2;
    if (samples == 0) return;
    var sum = 0.0;
    for (var i = 0; i < samples; i++) {
      final s = data.getInt16(i * 2, Endian.little) / 32768;
      sum += s * s;
    }
    final rms = math.sqrt(sum / samples);
    final dbfs = rms > 0 ? 20 * math.log(rms) / math.ln10 : -90.0;
    // -60 dBFS (quiet room) .. -10 dBFS (loud voice) mapped to 0..1.
    _levelController.add(((dbfs + 60) / 50).clamp(0.0, 1.0));
  }

  Future<void> _stopDesktopMeter() async {
    await _meterSub?.cancel();
    _meterSub = null;
    final recorder = _meter;
    _meter = null;
    if (recorder != null) {
      try {
        await recorder.stop();
      } catch (_) {}
      await recorder.dispose();
    }
  }

  void _onSoundLevel(double raw) {
    if (raw.isNaN || raw.isInfinite) return;
    if (_minLevel == null) {
      _log('Receiving sound levels (first raw value $raw).');
    }
    final lo = _minLevel = math.min(_minLevel ?? raw, raw);
    final hi = _maxLevel = math.max(_maxLevel ?? raw, raw);
    final range = hi - lo;
    _levelController.add(
      range < 1e-6 ? 0 : ((raw - lo) / range).clamp(0.0, 1.0),
    );
  }

  Future<String> stop() async {
    _log('Stop requested. isListening=${_speech.isListening}');
    await _stopDesktopMeter();
    if (_speech.isListening) {
      await _speech.stop();
    }
    _log('Speech recognition stopped.');
    return _lastFinal;
  }

  Future<void> cancel() async {
    _log('Cancel requested. isListening=${_speech.isListening}');
    await _stopDesktopMeter();
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }

  void dispose() {
    _transcriptController.close();
    _levelController.close();
    _logController.close();
  }
}

final sttServiceProvider = Provider<SttService>((ref) {
  final svc = SttService();
  ref.onDispose(svc.dispose);
  return svc;
});
