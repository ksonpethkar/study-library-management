import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'soundbox_audio_stub.dart' if (dart.library.js_interop) 'soundbox_audio_web.dart';

/// Service for simulating a Paytm / PhonePe / Google Pay Soundbox terminal
/// at library reception counters.
///
/// Provides an ascending melodic payment chime followed by synthesized
/// verbal payment confirmation in English, Hindi, or Marathi.
class SoundboxService {
  static const _kSoundboxEnabled = 'soundbox_audio_enabled';
  static const _kSoundboxLanguage = 'soundbox_audio_language';
  static const _kSoundboxPrivacyMode = 'soundbox_privacy_mode';
  static const _kSoundboxChimeOnly = 'soundbox_chime_only';

  SharedPreferences? _prefs;
  bool _enabled = true;
  String _language = 'en'; // 'en', 'hi', 'mr'
  bool _privacyMode = false; // Announce amount only (no student name/seat aloud)
  bool _chimeOnly = false; // Play ascending chime without TTS voice

  SoundboxService({SharedPreferences? prefs}) : _prefs = prefs {
    if (prefs != null) {
      _enabled = prefs.getBool(_kSoundboxEnabled) ?? true;
      _language = prefs.getString(_kSoundboxLanguage) ?? 'en';
      _privacyMode = prefs.getBool(_kSoundboxPrivacyMode) ?? false;
      _chimeOnly = prefs.getBool(_kSoundboxChimeOnly) ?? false;
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
        _privacyMode = _prefs!.getBool(_kSoundboxPrivacyMode) ?? _privacyMode;
        _chimeOnly = _prefs!.getBool(_kSoundboxChimeOnly) ?? _chimeOnly;
      }
    } catch (_) {
      // Fallback in test or uninitialized environments
    }
  }

  bool get isEnabled => _enabled;
  String get language => _language;
  bool get isPrivacyMode => _privacyMode;
  bool get isChimeOnly => _chimeOnly;

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _prefs?.setBool(_kSoundboxEnabled, value);
  }

  Future<void> setLanguage(String value) async {
    _language = value;
    await _prefs?.setString(_kSoundboxLanguage, value);
  }

  Future<void> setPrivacyMode(bool value) async {
    _privacyMode = value;
    await _prefs?.setBool(_kSoundboxPrivacyMode, value);
  }

  Future<void> setChimeOnly(bool value) async {
    _chimeOnly = value;
    await _prefs?.setBool(_kSoundboxChimeOnly, value);
  }

  /// Syncs soundbox preferences from Firestore across all reception devices.
  Future<void> syncFromLibrary(String libraryId) async {
    if (libraryId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('soundbox')
          .get();
      if (doc.exists && doc.data() != null) {
        final d = doc.data()!;
        await setEnabled(d['enabled'] as bool? ?? _enabled);
        await setLanguage(d['language'] as String? ?? _language);
        await setPrivacyMode(d['privacyMode'] as bool? ?? _privacyMode);
        await setChimeOnly(d['chimeOnly'] as bool? ?? _chimeOnly);
      }
    } catch (_) {}
  }

  /// Persists soundbox preferences to Firestore for multi-device reception sync.
  Future<void> saveToLibrary(String libraryId) async {
    if (libraryId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('soundbox')
          .set({
        'enabled': _enabled,
        'language': _language,
        'privacyMode': _privacyMode,
        'chimeOnly': _chimeOnly,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
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
        if (_privacyMode) {
          return 'Payment of $amtFormatted rupees received on $libName.';
        }
        final studentPart = (studentName != null && studentName.trim().isNotEmpty)
            ? ' for ${studentName.trim()}'
            : '';
        String seatPart = '';
        if (seatLabel != null && seatLabel.trim().isNotEmpty) {
          final trimmedSeat = seatLabel.trim();
          if (trimmedSeat.toLowerCase().startsWith('seat') ||
              trimmedSeat.toLowerCase().startsWith('desk')) {
            seatPart = ' $trimmedSeat';
          } else {
            seatPart = ' Seat $trimmedSeat';
          }
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
    if (_chimeOnly) return;

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
