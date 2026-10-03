import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
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
  String _lastFinal = '';

  Stream<String> get transcriptStream => _transcriptController.stream;
  String get lastFinal => _lastFinal;
  bool get isListening => _speech.isListening;

  void _log(String message) {
    debugPrint('[SttService] $message');
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
      },
      onError: (e) {
        _log('speech_to_text error: ${e.errorMsg} (permanent: ${e.permanent})');
        _transcriptController.addError(e.errorMsg);
      },
    );
    _log('speech_to_text initialize result: $_initialized');
    return _initialized;
  }

  Future<bool> start({String localeId = 'en_US'}) async {
    _log('Start requested with localeId=$localeId');
    if (!await _ensureInitialized()) {
      _log('Start aborted because initialization failed.');
      return false;
    }

    _lastFinal = '';
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
    );
    _log('speech.listen() started. isListening=${_speech.isListening}');
    return true;
  }

  Future<String> stop() async {
    _log('Stop requested. isListening=${_speech.isListening}');
    if (_speech.isListening) {
      await _speech.stop();
    }
    _log('Speech recognition stopped.');
    return _lastFinal;
  }

  Future<void> cancel() async {
    _log('Cancel requested. isListening=${_speech.isListening}');
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }

  void dispose() {
    _transcriptController.close();
  }
}

final sttServiceProvider = Provider<SttService>((ref) {
  final svc = SttService();
  ref.onDispose(svc.dispose);
  return svc;
});
