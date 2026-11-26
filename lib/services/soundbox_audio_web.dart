import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Web implementation of soundbox audio chime and speech synthesis.
/// Uses typed Web Audio API (AudioContext) and Web Speech API (SpeechSynthesis)
/// via `package:web` + `dart:js_interop` (Wasm & modern JS-interop ready).

web.AudioContext? _soundboxAudioCtx;

@JS('_activeSoundboxUtterance')
external set _jsActiveSoundboxUtterance(web.SpeechSynthesisUtterance? value);

void _playAscendingChimeNotes(web.AudioContext ctx) {
  const freqs = [523.25, 659.25, 783.99, 1046.50];
  const step = 0.075;
  final now = ctx.currentTime;
  for (var i = 0; i < freqs.length; i++) {
    final st = now + (i * step);
    final et = st + 0.16;
    final osc = ctx.createOscillator();
    final gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(freqs[i], st);
    gain.gain.setValueAtTime(0.01, st);
    gain.gain.linearRampToValueAtTime(0.35, st + 0.015);
    gain.gain.exponentialRampToValueAtTime(0.001, et);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(st);
    osc.stop(et);
  }
}

void playWebSoundboxChime() {
  try {
    final ctx = _soundboxAudioCtx ??= web.AudioContext();
    if (ctx.state == 'suspended') {
      ctx.resume().toDart.then((_) {
        _playAscendingChimeNotes(ctx);
      }).catchError((_) {});
    } else {
      _playAscendingChimeNotes(ctx);
    }
  } catch (_) {
    // Graceful fallback
  }
}

void speakWebAnnouncement(String text, String languageCode) {
  try {
    final synth = web.window.speechSynthesis;
    if (synth.speaking) {
      synth.cancel();
    }
    if (synth.paused) {
      synth.resume();
    }

    final utterance = web.SpeechSynthesisUtterance(text);

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

    // Retain global reference on window to prevent premature Chrome garbage collection
    _jsActiveSoundboxUtterance = utterance;
    utterance.onend = ((web.Event _) {
      _jsActiveSoundboxUtterance = null;
    }).toJS;
    utterance.onerror = ((web.Event _) {
      _jsActiveSoundboxUtterance = null;
    }).toJS;

    // Small delay ensures previous cancel event does not clobber speech
    Future.delayed(const Duration(milliseconds: 60), () {
      try {
        if (synth.paused) synth.resume();
        synth.speak(utterance);
      } catch (_) {}
    });
  } catch (_) {
    // Graceful fallback
  }
}
