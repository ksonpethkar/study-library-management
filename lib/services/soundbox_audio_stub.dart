import 'package:flutter/services.dart';

/// Non-web stub implementation of soundbox audio and speech announcement.
void playWebSoundboxChime() {
  try {
    SystemSound.play(SystemSoundType.click).catchError((_) {});
  } catch (_) {
    // Graceful fallback in test or headless environments
  }
}

void speakWebAnnouncement(String text, String languageCode) {
  // Speech synthesis is handled by native platform or web-only audio APIs.
}
