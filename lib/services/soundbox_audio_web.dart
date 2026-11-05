// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;

/// Web implementation of soundbox audio chime and speech synthesis.
/// Uses Web Audio API AudioContext via JS interop for zero-asset ascending chime
/// and Web Speech API SpeechSynthesis for vocal payment confirmation.

void playWebSoundboxChime() {
  try {
    js.context.callMethod('eval', [r'''
      (function() {
        try {
          var AudioCtx = window.AudioContext || window.webkitAudioContext;
          if (!AudioCtx) return;
          var ctx = new AudioCtx();
          var freqs = [523.25, 659.25, 783.99, 1046.50];
          var step = 0.075;
          var now = ctx.currentTime;
          for (var i = 0; i < freqs.length; i++) {
            var osc = ctx.createOscillator();
            var gain = ctx.createGain();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(freqs[i], now + (i * step));
            var st = now + (i * step);
            var et = st + 0.16;
            gain.gain.setValueAtTime(0.01, st);
            gain.gain.linearRampToValueAtTime(0.28, st + 0.015);
            gain.gain.exponentialRampToValueAtTime(0.001, et);
            osc.connect(gain);
            gain.connect(ctx.destination);
            osc.start(st);
            osc.stop(et);
          }
        } catch(e) {}
      })();
    ''']);
  } catch (_) {
    // Graceful fallback
  }
}

void speakWebAnnouncement(String text, String languageCode) {
  try {
    if (html.window.speechSynthesis == null) return;

    html.window.speechSynthesis?.cancel(); // Cancel any queued utterance
    final utterance = html.SpeechSynthesisUtterance(text);

    if (languageCode == 'hi') {
      utterance.lang = 'hi-IN';
    } else if (languageCode == 'mr') {
      utterance.lang = 'mr-IN';
    } else {
      utterance.lang = 'en-IN';
    }

    utterance.rate = 0.95; // Clear and polite pacing
    utterance.pitch = 1.05; // Friendly clarity
    utterance.volume = 1.0;

    html.window.speechSynthesis?.speak(utterance);
  } catch (_) {
    // Graceful fallback
  }
}
