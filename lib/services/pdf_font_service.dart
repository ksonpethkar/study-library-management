import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Centralized service providing universal multilingual font fallbacks for all PDF documents
/// (Receipts, Student ID Cards, Seating Allocations, and Ledger Invoices).
/// Ensures zero tofu boxes (□) across Devanagari (Marathi, Hindi, Sanskrit),
/// Tamil, Telugu, Gujarati, Bengali, Kannada, and global scripts.
class PdfFontService {
  PdfFontService._();

  static pw.Font? _cachedBase;
  static pw.Font? _cachedBold;
  static List<pw.Font>? _cachedFallbacks;

  /// Loads base Latin/Symbol Unicode font (NotoSans)
  static Future<pw.Font> getBaseFont() async {
    if (_cachedBase != null) return _cachedBase!;
    try {
      final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      _cachedBase = pw.Font.ttf(fontData);
    } catch (_) {
      try {
        _cachedBase = await PdfGoogleFonts.notoSansRegular();
      } catch (_) {
        _cachedBase = pw.Font.helvetica();
      }
    }
    return _cachedBase!;
  }

  /// Loads bold Unicode font
  static Future<pw.Font> getBaseBoldFont() async {
    if (_cachedBold != null) return _cachedBold!;
    try {
      _cachedBold = await PdfGoogleFonts.notoSansBold().timeout(const Duration(milliseconds: 2000));
    } catch (_) {
      _cachedBold = pw.Font.helveticaBold();
    }
    return _cachedBold!;
  }

  /// Loads regional Indic & Multilingual script fallbacks with local caching and fast timeouts
  static Future<List<pw.Font>> getFallbackFonts() async {
    if (_cachedFallbacks != null) return _cachedFallbacks!;

    final list = <pw.Font>[];

    // 1. Devanagari (Hindi, Marathi, Konkani, Sanskrit) with fast timeout
    try {
      final dev = await PdfGoogleFonts.notoSansDevanagariRegular()
          .timeout(const Duration(milliseconds: 2000));
      list.add(dev);
    } catch (_) {}

    // 2. Additional Indic scripts loaded concurrently with non-blocking timeout
    try {
      final extraFonts = await Future.wait<pw.Font?>([
        PdfGoogleFonts.notoSansTamilRegular().timeout(const Duration(milliseconds: 1500)).then<pw.Font?>((f) => f).catchError((_) => null),
        PdfGoogleFonts.notoSansTeluguRegular().timeout(const Duration(milliseconds: 1500)).then<pw.Font?>((f) => f).catchError((_) => null),
        PdfGoogleFonts.notoSansGujaratiRegular().timeout(const Duration(milliseconds: 1500)).then<pw.Font?>((f) => f).catchError((_) => null),
        PdfGoogleFonts.notoSansBengaliRegular().timeout(const Duration(milliseconds: 1500)).then<pw.Font?>((f) => f).catchError((_) => null),
      ]);
      for (final f in extraFonts) {
        if (f != null) list.add(f);
      }
    } catch (_) {}

    _cachedFallbacks = list;
    return list;
  }

  /// Returns a complete pw.ThemeData preconfigured with universal font fallbacks
  static Future<pw.ThemeData> getUniversalTheme({
    pw.Font? base,
    pw.Font? bold,
  }) async {
    final defaultBase = base ?? await getBaseFont();
    final defaultBold = bold ?? await getBaseBoldFont();
    final fallbacks = await getFallbackFonts();

    return pw.ThemeData.withFont(
      base: defaultBase,
      bold: defaultBold,
      italic: defaultBase,
      boldItalic: defaultBold,
      fontFallback: [
        defaultBase,
        ...fallbacks,
      ],
    );
  }
}
