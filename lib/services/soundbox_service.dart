import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'soundbox_audio_stub.dart' if (dart.library.html) 'soundbox_audio_web.dart';

/// Service for simulating a Paytm / PhonePe / Google Pay Soundbox terminal
/// at library reception counters.
///
/// Provides an ascending melodic payment chime followed by synthesized
/// verbal payment confirmation in English, Hindi, or Marathi.
class SoundboxService {
  static const _kSoundboxEnabled = 'soundbox_audio_enabled';
  static const _kSoundboxLanguage = 'soundbox_audio_language';

  SharedPreferences? _prefs;
  bool _enabled = true;
  String _language = 'en'; // 'en', 'hi', 'mr'

  SoundboxService({SharedPreferences? prefs}) : _prefs = prefs {
    if (prefs != null) {
      _enabled = prefs.getBool(_kSoundboxEnabled) ?? true;
      _language = prefs.getString(_kSoundboxLanguage) ?? 'en';
    } else {
      _initPrefs();
    }
  }

  Future<void> _initPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      if (_prefs != null) {
        _enabled = _prefs!.getBool(_kSoundboxEnabled) ?? _enabled;
        _language = _prefs!.getString(_kSoundboxLanguage) ?? _language;
      }
    } catch (_) {
      // Fallback in test or uninitialized environments
    }
  }

  bool get isEnabled => _enabled;
  String get language => _language;

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _prefs?.setBool(_kSoundboxEnabled, value);
  }

  Future<void> setLanguage(String value) async {
    _language = value;
    await _prefs?.setString(_kSoundboxLanguage, value);
  }

  /// Plays the ascending electronic soundbox payment chime.
  void playChime() {
    playWebSoundboxChime();
  }

  /// Formats the spoken confirmation string for the specified language.
  String formatAnnouncement({
    required double amount,
    String? studentName,
    String? seatLabel,
    String? libraryName,
    String? languageOverride,
  }) {
    final lang = languageOverride ?? _language;
    final libName = (libraryName != null && libraryName.trim().isNotEmpty)
        ? libraryName.trim()
        : 'Cozy Corner';
    final amtFormatted = amount.toStringAsFixed(0);

    switch (lang.toLowerCase()) {
      case 'hi':
        return '$libName पर $amtFormatted रुपये प्राप्त हुए।';
      case 'mr':
        return '$libName वर $amtFormatted रुपये प्राप्त झाले।';
      case 'en':
      default:
        final studentPart = (studentName != null && studentName.trim().isNotEmpty)
            ? ' for ${studentName.trim()}'
            : '';
        String seatPart = '';
        if (seatLabel != null && seatLabel.trim().isNotEmpty) {
          final trimmedSeat = seatLabel.trim();
          seatPart = trimmedSeat.toLowerCase().startsWith('seat')
              ? ' $trimmedSeat'
              : ' Seat $trimmedSeat';
        }
        final detail = (studentPart.isNotEmpty || seatPart.isNotEmpty)
            ? '$studentPart$seatPart'
            : '';
        return 'Payment of $amtFormatted rupees received$detail on $libName.';
    }
  }

  /// Plays the melodic chime and announces the payment verbal confirmation.
  Future<void> announcePayment({
    required double amount,
    String? studentName,
    String? seatLabel,
    String? libraryName,
    String? languageOverride,
  }) async {
    if (!_enabled) return;

    // 1. Play ascending melodic payment chime
    playChime();

    // 2. Short acoustic pause before speech starts
    await Future.delayed(const Duration(milliseconds: 320));

    // 3. Spoken payment readout
    final speechText = formatAnnouncement(
      amount: amount,
      studentName: studentName,
      seatLabel: seatLabel,
      libraryName: libraryName,
      languageOverride: languageOverride,
    );

    speakWebAnnouncement(speechText, languageOverride ?? _language);
  }

  /// Interactive test announcement for settings previews
  Future<void> testAnnouncement(String lang, {String? libraryName}) async {
    playChime();
    await Future.delayed(const Duration(milliseconds: 320));
    final speechText = formatAnnouncement(
      amount: 500,
      studentName: 'Shubham',
      seatLabel: 'Seat 14',
      libraryName: libraryName,
      languageOverride: lang,
    );
    speakWebAnnouncement(speechText, lang);
  }
}

final soundboxServiceProvider = Provider<SoundboxService>((ref) {
  return SoundboxService();
});
