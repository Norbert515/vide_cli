import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Service for voice-to-text input using the device microphone.
///
/// Wraps the speech_to_text plugin with a simple API for the SDK.
class VoiceInputService extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;
  String _currentText = '';
  String? _error;

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;
  String get currentText => _currentText;
  String? get error => _error;

  /// Initialize the speech recognition engine.
  ///
  /// Returns true if speech recognition is available on this device.
  Future<bool> initialize() async {
    _isAvailable = await _speech.initialize(
      onError: (error) {
        _error = error.errorMsg;
        _isListening = false;
        notifyListeners();
      },
      onStatus: (status) {
        _isListening = status == 'listening';
        notifyListeners();
      },
    );
    notifyListeners();
    return _isAvailable;
  }

  /// Start listening for speech input.
  ///
  /// [onResult] is called with the final recognized text when done.
  Future<void> startListening({
    ValueChanged<String>? onResult,
    String localeId = 'en_US',
  }) async {
    if (!_isAvailable) {
      _error = 'Speech recognition not available';
      notifyListeners();
      return;
    }

    _currentText = '';
    _error = null;
    _isListening = true;
    notifyListeners();

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        _currentText = result.recognizedWords;
        notifyListeners();

        if (result.finalResult) {
          _isListening = false;
          notifyListeners();
          onResult?.call(_currentText);
        }
      },
      localeId: localeId,
      listenOptions: SpeechListenOptions(listenMode: ListenMode.dictation),
    );
  }

  /// Stop listening and return whatever was recognized so far.
  Future<String> stopListening() async {
    await _speech.stop();
    _isListening = false;
    notifyListeners();
    return _currentText;
  }

  /// Cancel listening without producing a result.
  Future<void> cancelListening() async {
    await _speech.cancel();
    _isListening = false;
    _currentText = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }
}
