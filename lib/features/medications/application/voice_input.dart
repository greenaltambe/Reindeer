import 'package:reindeer/core/i18n/strings.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Thin wrapper over the phone's speech recogniser. Used to say a medicine and
/// its schedule instead of typing it.
class VoiceInput {
  final SpeechToText _speech = SpeechToText();
  bool _ready = false;

  bool get isListening => _speech.isListening;

  /// Starts the recogniser once. False when the phone has no recogniser or the
  /// microphone permission was refused.
  Future<bool> init({void Function(String status)? onStatus}) async {
    if (_ready) return true;
    try {
      _ready = await _speech.initialize(onStatus: onStatus, onError: (_) {});
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  Future<String?> _localeFor(AppLanguage lang) async {
    final wanted = switch (lang) {
      AppLanguage.hi => 'hi_IN',
      AppLanguage.mr => 'mr_IN',
      AppLanguage.en => 'en_IN',
    };
    try {
      final all = await _speech.locales();
      final ids = [for (final l in all) l.localeId];
      bool same(String a, String b) =>
          a.replaceAll('-', '_').toLowerCase() ==
          b.replaceAll('-', '_').toLowerCase();
      for (final id in ids) {
        if (same(id, wanted)) return id;
      }
      final prefix = wanted.substring(0, 2);
      for (final id in ids) {
        if (id.toLowerCase().startsWith(prefix)) return id;
      }
    } catch (_) {}
    return null;
  }

  /// Listens until the person stops talking. [onWords] receives the text so far
  /// and whether it is final.
  Future<void> start({
    required void Function(String words, bool done) onWords,
  }) async {
    final locale = await _localeFor(I18n.current);
    await _speech.listen(
      onResult: (SpeechRecognitionResult r) =>
          onWords(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
        listenFor: const Duration(seconds: 25),
        pauseFor: const Duration(seconds: 4),
        localeId: locale,
      ),
    );
  }

  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
  }

  Future<void> cancel() async {
    try {
      await _speech.cancel();
    } catch (_) {}
  }
}
