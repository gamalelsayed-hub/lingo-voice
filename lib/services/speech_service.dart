import 'dart:async';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Wraps the phone's speech recognizer. Android stops listening after each
/// pause, so continuous mode restarts it until [stop] is called.
class SpeechService {
  SpeechService._();

  static final instance = SpeechService._();

  final _stt = SpeechToText();
  bool _ready = false;
  bool _continuous = false;
  bool _paused = false;
  String _locale = 'ar_EG';
  void Function(String sentence)? _onSentence;
  void Function(String partial)? _onPartial;
  Completer<String>? _single;
  String _lastWords = '';

  /// Words heard but not yet delivered as a sentence. Android often ends a
  /// session without a final result, so these are delivered when it stops.
  String _undelivered = '';

  bool get isListening => _stt.isListening;

  Future<bool> init() async {
    if (_ready) return true;
    _ready = await _stt.initialize(
      onStatus: _handleStatus,
      onError: (_) => _handleStatus(SpeechToText.doneStatus),
    );
    return _ready;
  }

  /// Listens until [stop], calling [onSentence] for each finished sentence.
  Future<void> startContinuous({
    required String locale,
    required void Function(String sentence) onSentence,
    void Function(String partial)? onPartial,
  }) async {
    _locale = locale;
    _single = null;
    _undelivered = '';
    _onSentence = onSentence;
    _onPartial = onPartial;
    _continuous = true;
    _paused = false;
    await _listen();
  }

  /// Stops the microphone for a moment, e.g. while the app is speaking, so
  /// the app does not hear itself.
  Future<void> pause() async {
    _paused = true;
    await _stt.stop();
    flush();
  }

  /// Delivers whatever was heard so far as a sentence, even if incomplete.
  void flush() {
    final words = _undelivered.trim();
    _undelivered = '';
    if (words.isNotEmpty) _onSentence?.call(words);
  }

  Future<void> resume() async {
    _paused = false;
    if (_continuous && !_stt.isListening) await _listen();
  }

  Future<void> stop() async {
    _continuous = false;
    _paused = false;
    await _stt.stop();
    flush();
  }

  /// Listens for one utterance (used by the placement test).
  Future<String> listenOnce(String locale) async {
    _continuous = false;
    _locale = locale;
    _onSentence = null;
    _onPartial = null;
    _single = Completer<String>();
    _lastWords = '';
    await _listen();
    return _single!.future;
  }

  Future<void> _listen() => _stt.listen(
    onResult: _handleResult,
    listenOptions: SpeechListenOptions(
      localeId: _locale,
      listenMode: ListenMode.dictation,
      partialResults: true,
      cancelOnError: false,
      pauseFor: const Duration(seconds: 4),
      listenFor: const Duration(minutes: 1),
    ),
  );

  void _handleResult(SpeechRecognitionResult r) {
    _lastWords = r.recognizedWords;
    if (!r.finalResult) {
      _undelivered = r.recognizedWords;
      _onPartial?.call(r.recognizedWords);
      return;
    }
    _undelivered = '';
    final single = _single;
    if (single != null && !single.isCompleted) {
      single.complete(r.recognizedWords);
    } else if (r.recognizedWords.trim().isNotEmpty) {
      _onSentence?.call(r.recognizedWords.trim());
    }
  }

  void _handleStatus(String status) {
    if (status != SpeechToText.doneStatus &&
        status != SpeechToText.notListeningStatus) {
      return;
    }
    final single = _single;
    if (single != null && !single.isCompleted) {
      single.complete(_lastWords);
      return;
    }
    flush();
    if (_continuous && !_paused) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_continuous && !_paused && !_stt.isListening) _listen();
      });
    }
  }
}
