import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

FlutterTts? _ttsInstance;

FlutterTts _getTts() {
  _ttsInstance ??= FlutterTts();
  return _ttsInstance!;
}

/// Non-web implementation of soundbox audio chime and native speech synthesis.
void playWebSoundboxChime() {
  try {
    SystemSound.play(SystemSoundType.click).catchError((_) {});
  } catch (_) {
    // Graceful fallback in test or headless environments
  }
}

void speakWebAnnouncement(String text, String languageCode) {
  try {
    final tts = _getTts();
    String ttsLang = 'en-IN';
    if (languageCode == 'hi') {
      ttsLang = 'hi-IN';
    } else if (languageCode == 'mr') {
      ttsLang = 'mr-IN';
    }
    tts.setLanguage(ttsLang).then((_) {
      tts.setSpeechRate(0.5);
      tts.setVolume(1.0);
      tts.setPitch(1.0);
      tts.speak(text);
    }).catchError((_) {
      // Fallback to default
      tts.speak(text);
    });
  } catch (_) {
    // Graceful fallback in test or unsupported hardware
  }
}
