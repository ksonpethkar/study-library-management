import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/font_settings_provider.dart';

/// AppTypography defines the text styles using Google Fonts with scholastic presets.
class AppTypography {
  AppTypography._();

  /// Universal font fallback chain covering all major Indian scripts and world languages:
  /// Devanagari (Hindi, Marathi, Konkani, Sanskrit), Tamil, Telugu, Gujarati, Bengali,
  /// Kannada, Malayalam, Gurmukhi, and global emojis.
  static const List<String> universalFontFallbacks = [
    'Noto Sans',
    'Noto Sans Devanagari',
    'Noto Sans Tamil',
    'Noto Sans Telugu',
    'Noto Sans Gujarati',
    'Noto Sans Bengali',
    'Noto Sans Kannada',
    'Noto Sans Malayalam',
    'Noto Sans Gurmukhi',
    'Noto Color Emoji',
    'sans-serif',
  ];

  static TextTheme getLightTextTheme([AppFontFamily family = AppFontFamily.modern]) {
    TextTheme base;
    switch (family) {
      case AppFontFamily.academic:
        base = TextTheme(
          displayLarge: GoogleFonts.outfit(fontSize: 57, fontWeight: FontWeight.bold, letterSpacing: -0.25),
          displayMedium: GoogleFonts.outfit(fontSize: 45, fontWeight: FontWeight.bold, letterSpacing: 0),
          displaySmall: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 0),
          headlineLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w600, letterSpacing: 0),
          headlineMedium: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: 0),
          headlineSmall: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 0),
          titleLarge: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 0),
          titleMedium: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15),
          titleSmall: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),

          bodyLarge: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.normal, letterSpacing: 0.5),
          bodyMedium: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.normal, letterSpacing: 0.25),
          bodySmall: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.normal, letterSpacing: 0.4),

          labelLarge: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
          labelMedium: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5),
          labelSmall: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
        );
        break;

      case AppFontFamily.warm:
        base = TextTheme(
          displayLarge: GoogleFonts.lexend(fontSize: 57, fontWeight: FontWeight.bold, letterSpacing: -0.25),
          displayMedium: GoogleFonts.lexend(fontSize: 45, fontWeight: FontWeight.bold, letterSpacing: 0),
          displaySmall: GoogleFonts.lexend(fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 0),
          headlineLarge: GoogleFonts.lexend(fontSize: 32, fontWeight: FontWeight.w600, letterSpacing: 0),
          headlineMedium: GoogleFonts.lexend(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: 0),
          headlineSmall: GoogleFonts.lexend(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 0),
          titleLarge: GoogleFonts.lexend(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 0),
          titleMedium: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15),
          titleSmall: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),

          bodyLarge: GoogleFonts.nunitoSans(fontSize: 16, fontWeight: FontWeight.normal, letterSpacing: 0.5),
          bodyMedium: GoogleFonts.nunitoSans(fontSize: 14, fontWeight: FontWeight.normal, letterSpacing: 0.25),
          bodySmall: GoogleFonts.nunitoSans(fontSize: 12, fontWeight: FontWeight.normal, letterSpacing: 0.4),

          labelLarge: GoogleFonts.nunitoSans(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
          labelMedium: GoogleFonts.nunitoSans(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5),
          labelSmall: GoogleFonts.nunitoSans(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
        );
        break;

      case AppFontFamily.modern:
        base = TextTheme(
          displayLarge: GoogleFonts.poppins(fontSize: 57, fontWeight: FontWeight.bold, letterSpacing: -0.25),
          displayMedium: GoogleFonts.poppins(fontSize: 45, fontWeight: FontWeight.bold, letterSpacing: 0),
          displaySmall: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 0),
          headlineLarge: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w600, letterSpacing: 0),
          headlineMedium: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: 0),
          headlineSmall: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 0),
          titleLarge: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 0),
          titleMedium: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15),
          titleSmall: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),

          bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.normal, letterSpacing: 0.5),
          bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.normal, letterSpacing: 0.25),
          bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.normal, letterSpacing: 0.4),

          labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
          labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5),
          labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
        );
        break;
    }
    return base.apply(
      bodyColor: const Color(0xFF0F172A),
      displayColor: const Color(0xFF09090B),
      fontFamilyFallback: universalFontFallbacks,
    );
  }

  static TextTheme getDarkTextTheme([AppFontFamily family = AppFontFamily.modern]) {
    return getLightTextTheme(family).apply(
      bodyColor: const Color(0xFFF1F5F9),
      displayColor: Colors.white,
      fontFamilyFallback: universalFontFallbacks,
    );
  }
}
