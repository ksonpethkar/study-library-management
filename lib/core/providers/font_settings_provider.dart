import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppFontScale {
  compact(factor: 0.88, label: 'Compact', percentage: '88%', description: 'High data density · Roster & seat matrix'),
  standard(factor: 1.00, label: 'Standard', percentage: '100%', description: 'Default balanced modern reading'),
  comfort(factor: 1.12, label: 'Comfort', percentage: '112%', description: 'Relaxed reading · Reduced eye fatigue'),
  large(factor: 1.25, label: 'Large', percentage: '125%', description: 'Maximum legibility · Easy scanning');

  final double factor;
  final String label;
  final String percentage;
  final String description;

  const AppFontScale({
    required this.factor,
    required this.label,
    required this.percentage,
    required this.description,
  });
}

enum AppFontFamily {
  modern(
    id: 'modern',
    name: 'Modern Clean',
    headingFamily: 'Poppins',
    bodyFamily: 'Inter',
    badge: 'DEFAULT',
    description: 'Crisp geometric headings & high-clarity UI body',
  ),
  academic(
    id: 'academic',
    name: 'Academic Elite',
    headingFamily: 'Outfit',
    bodyFamily: 'Plus Jakarta Sans',
    badge: 'PRESTIGE',
    description: 'Authoritative scholastic look for competitive prep',
  ),
  warm(
    id: 'warm',
    name: 'Warm Scholar',
    headingFamily: 'Lexend',
    bodyFamily: 'Nunito Sans',
    badge: 'EYE COMFORT',
    description: 'Fluency engineered & gentle on tired study eyes',
  );

  final String id;
  final String name;
  final String headingFamily;
  final String bodyFamily;
  final String badge;
  final String description;

  const AppFontFamily({
    required this.id,
    required this.name,
    required this.headingFamily,
    required this.bodyFamily,
    required this.badge,
    required this.description,
  });
}

class FontSettingsState {
  final AppFontScale scale;
  final AppFontFamily family;

  const FontSettingsState({
    this.scale = AppFontScale.standard,
    this.family = AppFontFamily.modern,
  });

  FontSettingsState copyWith({
    AppFontScale? scale,
    AppFontFamily? family,
  }) {
    return FontSettingsState(
      scale: scale ?? this.scale,
      family: family ?? this.family,
    );
  }
}

class FontSettingsNotifier extends Notifier<FontSettingsState> {
  static const String _scaleKey = 'app_font_scale_index';
  static const String _familyKey = 'app_font_family_index';

  @override
  FontSettingsState build() {
    _loadFromPrefs();
    return const FontSettingsState();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scaleIndex = prefs.getInt(_scaleKey) ?? AppFontScale.standard.index;
      final familyIndex = prefs.getInt(_familyKey) ?? AppFontFamily.modern.index;

      final safeScale = (scaleIndex >= 0 && scaleIndex < AppFontScale.values.length)
          ? AppFontScale.values[scaleIndex]
          : AppFontScale.standard;

      final safeFamily = (familyIndex >= 0 && familyIndex < AppFontFamily.values.length)
          ? AppFontFamily.values[familyIndex]
          : AppFontFamily.modern;

      state = FontSettingsState(scale: safeScale, family: safeFamily);
    } catch (_) {
      // Graceful fallback to default
    }
  }

  Future<void> setFontScale(AppFontScale scale) async {
    state = state.copyWith(scale: scale);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_scaleKey, scale.index);
    } catch (_) {}
  }

  Future<void> setFontFamily(AppFontFamily family) async {
    state = state.copyWith(family: family);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_familyKey, family.index);
    } catch (_) {}
  }

  Future<void> resetToDefaults() async {
    state = const FontSettingsState(
      scale: AppFontScale.standard,
      family: AppFontFamily.modern,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_scaleKey);
      await prefs.remove(_familyKey);
    } catch (_) {}
  }
}

final fontSettingsProvider =
    NotifierProvider<FontSettingsNotifier, FontSettingsState>(FontSettingsNotifier.new);
