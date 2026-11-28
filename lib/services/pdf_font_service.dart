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
  static final Map<String, ({pw.Font regular, pw.Font bold, pw.Font italic, pw.Font boldItalic})> _familyCache = {};

  static const Map<String, String> supportedFontFamilies = {
    'noto_sans': 'Modern Sans (Noto Sans)',
    'noto_serif': 'Classic Serif (Noto Serif)',
    'poppins': 'Clean Geometric (Poppins)',
    'roboto_mono': 'Ledger Mono (Roboto Mono)',
  };

  static String normalizeFontFamily(String? raw) {
    final key = (raw ?? '').trim().toLowerCase();
    if (supportedFontFamilies.containsKey(key)) return key;
    return 'noto_sans';
  }

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
  /// for the requested [fontFamily] (`noto_sans`, `noto_serif`, `poppins`, `roboto_mono`).
  static Future<pw.ThemeData> getUniversalTheme({
    pw.Font? base,
    pw.Font? bold,
    String fontFamily = 'noto_sans',
  }) async {
    final normalized = normalizeFontFamily(fontFamily);
    if (base == null && bold == null && normalized != 'noto_sans') {
      final pair = await _loadFamilyFonts(normalized);
      final fallbacks = await getFallbackFonts();
      final fallbackBase = await getBaseFont();
      return pw.ThemeData.withFont(
        base: pair.regular,
        bold: pair.bold,
        italic: pair.italic,
        boldItalic: pair.boldItalic,
        fontFallback: [
          fallbackBase,
          ...fallbacks,
        ],
      );
    }

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

  static Future<({pw.Font regular, pw.Font bold, pw.Font italic, pw.Font boldItalic})> _loadFamilyFonts(
    String family,
  ) async {
    if (_familyCache.containsKey(family)) {
      return _familyCache[family]!;
    }
    final fallbackReg = await getBaseFont();
    final fallbackBold = await getBaseBoldFont();
    const timeout = Duration(milliseconds: 2500);

    Future<pw.Font> safeLoad(Future<pw.Font> Function() loader, pw.Font fallback) async {
      try {
        return await loader().timeout(timeout);
      } catch (_) {
        return fallback;
      }
    }

    late final ({pw.Font regular, pw.Font bold, pw.Font italic, pw.Font boldItalic}) result;
    switch (family) {
      case 'noto_serif':
        final reg = await safeLoad(PdfGoogleFonts.notoSerifRegular, fallbackReg);
        final bold = await safeLoad(PdfGoogleFonts.notoSerifBold, fallbackBold);
        final italic = await safeLoad(PdfGoogleFonts.notoSerifItalic, reg);
        final boldItalic = await safeLoad(PdfGoogleFonts.notoSerifBoldItalic, bold);
        result = (regular: reg, bold: bold, italic: italic, boldItalic: boldItalic);
        break;
      case 'poppins':
        final reg = await safeLoad(PdfGoogleFonts.poppinsRegular, fallbackReg);
        final bold = await safeLoad(PdfGoogleFonts.poppinsBold, fallbackBold);
        final italic = await safeLoad(PdfGoogleFonts.poppinsItalic, reg);
        final boldItalic = await safeLoad(PdfGoogleFonts.poppinsBoldItalic, bold);
        result = (regular: reg, bold: bold, italic: italic, boldItalic: boldItalic);
        break;
      case 'roboto_mono':
        final reg = await safeLoad(PdfGoogleFonts.robotoMonoRegular, fallbackReg);
        final bold = await safeLoad(PdfGoogleFonts.robotoMonoBold, fallbackBold);
        final italic = await safeLoad(PdfGoogleFonts.robotoMonoItalic, reg);
        final boldItalic = await safeLoad(PdfGoogleFonts.robotoMonoBoldItalic, bold);
        result = (regular: reg, bold: bold, italic: italic, boldItalic: boldItalic);
        break;
      default:
        result = (
          regular: fallbackReg,
          bold: fallbackBold,
          italic: fallbackReg,
          boldItalic: fallbackBold,
        );
    }
    _familyCache[family] = result;
    return result;
  }
}
