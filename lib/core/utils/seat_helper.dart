import 'dart:math';
import 'package:study_library/models/seat_model.dart';

/// Utility helper to format and resolve human-friendly seat labels and numbers
/// across the entire application (avoiding raw database IDs like `1790647291016_r0_c4`).
class SeatHelper {
  /// Formats strictly the numeric or code portion of a seat identifier without any
  /// "Seat", "Desk", or "#" prefix (e.g. "7", "24", "60", "A-12").
  /// Ideal for small desk tiles and dense seating matrices where horizontal width is constrained.
  static String formatSeatNumberOnly({
    String? seatId,
    String? rawLabel,
    int? cols,
  }) {
    final formatted = formatSeatLabel(
      seatId: seatId,
      rawLabel: rawLabel,
      cols: cols,
      includePrefix: false,
    );
    return formatted.replaceFirst(RegExp(r'^[#\s]+'), '');
  }

  /// Converts a raw seat ID, database label, or composite coordinates into a clean human string.
  /// Examples:
  /// - `1790647291016_r0_c4` -> `Seat #5`
  /// - `r0_c4` -> `Seat #5`
  /// - `CAB-05` -> `Seat CAB-05`
  /// - `A2` -> `Seat A2`
  /// - `5` -> `Seat #5`
  /// - `seat_15` -> `Seat #15`
  /// - `1790647291016_15` -> `Seat #15`
  static String formatSeatLabel({
    String? seatId,
    String? rawLabel,
    String? sectionName,
    int? cols,
    bool includePrefix = true,
  }) {
    String? input = (rawLabel != null && rawLabel.trim().isNotEmpty) ? rawLabel.trim() : seatId?.trim();
    if (input == null || input.isEmpty) {
      return includePrefix ? 'Allocated Desk' : 'Desk';
    }

    // Strip prefixes like "Seat #", "Seat:", "Seat_", "Seat-", "Desk #", "Desk_", "#", etc.
    var clean = input
        .replaceFirst(RegExp(r'^(Seat|Desk)[\s#_\-:]*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^[#_\-:\s]+'), '')
        .trim();

    // 1. Check if it's a composite ID containing _r{row}_c{col} or r{row}_c{col}
    final match = RegExp(r'(?:^|_)r(\d+)_c(\d+)$', caseSensitive: false).firstMatch(clean);
    if (match != null) {
      final r = int.tryParse(match.group(1)!) ?? 0;
      final c = int.tryParse(match.group(2)!) ?? 0;
      final totalCols = (cols != null && cols > 0) ? cols : (r > 0 ? 6 : 0);
      final seatIndex = totalCols > 0 ? (r * totalCols + c + 1) : (c + 1);
      return includePrefix ? 'Seat #$seatIndex' : '#$seatIndex';
    }

    // 1b. Check if it's a 0-indexed column identifier e.g. "c0", "c1", "desk_c0"
    final colMatch = RegExp(r'^(?:desk[_\-]?c|seat[_\-]?c|c)(\d+)$', caseSensitive: false).firstMatch(clean);
    if (colMatch != null) {
      final c = int.tryParse(colMatch.group(1)!) ?? 0;
      final seatIndex = c + 1;
      return includePrefix ? 'Seat #$seatIndex' : '#$seatIndex';
    }

    // 2. Pure digits e.g. "5"
    if (RegExp(r'^\d+$').hasMatch(clean)) {
      return includePrefix ? 'Seat #$clean' : '#$clean';
    }

    // 3. Clean custom alphanumeric code with hyphen or prefix e.g. "CAB-05", "A-12", "ROW-1"
    if (clean.length <= 12 && RegExp(r'^[A-Za-z0-9\-]+$').hasMatch(clean) && !clean.contains('_')) {
      return includePrefix ? 'Seat $clean' : clean;
    }

    // 4. Trailing number after underscore delimiter e.g. "sec_01_seat_15", "1790647291016_15"
    final trailingNumMatch = RegExp(r'_(\d+)$').firstMatch(clean);
    if (trailingNumMatch != null) {
      final numStr = trailingNumMatch.group(1)!;
      return includePrefix ? 'Seat #$numStr' : '#$numStr';
    }

    // 5. Clean alphanumeric label fallback
    if (clean.length <= 12 && !clean.contains('_')) {
      return includePrefix ? 'Seat $clean' : clean;
    }

    return includePrefix ? 'Allocated Desk' : 'Desk';
  }

  /// Returns full badge string including section name if available
  /// e.g. "Cozy Hall • Seat #5" or "Seat #5"
  static String formatSeatWithSection({
    String? seatId,
    String? rawLabel,
    String? sectionName,
    int? cols,
  }) {
    final seatText = formatSeatLabel(
      seatId: seatId,
      rawLabel: rawLabel,
      cols: cols,
      includePrefix: true,
    );

    if (sectionName != null && sectionName.trim().isNotEmpty) {
      return '${sectionName.trim()} • $seatText';
    }
    return seatText;
  }

  /// Normalizes a seat label or ID for natural sequential sorting by removing common prefixes
  /// like "Seat #", "Seat", "Desk #", "Desk", "#".
  static String normalizeForComparison(String input) {
    if (input.isEmpty) return input;
    final cleaned = input
        .replaceFirst(RegExp(r'^(?:Seat|Desk)[\s#_\-:]*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^[#_\-:\s]+'), '')
        .trim();
    return cleaned.isNotEmpty ? cleaned : input;
  }

  /// Naturally compares two strings alphanumeric-wise so that numeric segments are compared
  /// as values rather than ASCII characters (e.g. "2" < "12", "A2" < "A10", "Desk 2" < "Desk 12").
  static int compareNatural(String a, String b) {
    if (a == b) return 0;
    final normA = normalizeForComparison(a);
    final normB = normalizeForComparison(b);

    final regex = RegExp(r'(\d+|\D+)');
    final matchesA = regex.allMatches(normA).map((m) => m.group(0)!).toList();
    final matchesB = regex.allMatches(normB).map((m) => m.group(0)!).toList();
    final len = min(matchesA.length, matchesB.length);

    for (int i = 0; i < len; i++) {
      final partA = matchesA[i];
      final partB = matchesB[i];

      final isDigitA = partA.isNotEmpty && partA.codeUnitAt(0) >= 48 && partA.codeUnitAt(0) <= 57;
      final isDigitB = partB.isNotEmpty && partB.codeUnitAt(0) >= 48 && partB.codeUnitAt(0) <= 57;

      if (isDigitA && isDigitB) {
        final numA = BigInt.tryParse(partA);
        final numB = BigInt.tryParse(partB);
        if (numA != null && numB != null) {
          final cmp = numA.compareTo(numB);
          if (cmp != 0) return cmp;
        } else {
          final cmp = partA.compareTo(partB);
          if (cmp != 0) return cmp;
        }
      } else {
        final cmp = partA.toLowerCase().compareTo(partB.toLowerCase());
        if (cmp != 0) return cmp;
        final rawCmp = partA.compareTo(partB);
        if (rawCmp != 0) return rawCmp;
      }
    }
    return matchesA.length.compareTo(matchesB.length);
  }

  /// Naturally compares two SeatModel instances sequentially.
  /// If both seats belong to different sections, compares section IDs.
  /// Then naturally compares seat labels (e.g. 1, 2, ... 10, 11, 12).
  /// Falls back to row/col coordinate sorting if labels are identical or empty.
  static int compareSeats(SeatModel a, SeatModel b) {
    if (a.sectionId.isNotEmpty && b.sectionId.isNotEmpty && a.sectionId != b.sectionId) {
      final secCmp = compareNatural(a.sectionId, b.sectionId);
      if (secCmp != 0) return secCmp;
    }
    final labelA = a.label.trim().isNotEmpty ? a.label : a.id;
    final labelB = b.label.trim().isNotEmpty ? b.label : b.id;
    final cmp = compareNatural(labelA, labelB);
    if (cmp != 0) return cmp;

    final rowCmp = a.row.compareTo(b.row);
    if (rowCmp != 0) return rowCmp;
    return a.col.compareTo(b.col);
  }

  /// Naturally compares two seat maps (e.g. from Firestore JSON) sequentially.
  static int compareSeatMaps(Map<String, dynamic> a, Map<String, dynamic> b) {
    final secA = (a['sectionId'] ?? '').toString();
    final secB = (b['sectionId'] ?? '').toString();
    if (secA.isNotEmpty && secB.isNotEmpty && secA != secB) {
      final secCmp = compareNatural(secA, secB);
      if (secCmp != 0) return secCmp;
    }
    final labelA = (a['label'] ?? a['id'] ?? '').toString();
    final labelB = (b['label'] ?? b['id'] ?? '').toString();
    final cmp = compareNatural(labelA, labelB);
    if (cmp != 0) return cmp;

    final rA = (a['row'] as num?)?.toInt() ?? 0;
    final rB = (b['row'] as num?)?.toInt() ?? 0;
    if (rA != rB) return rA.compareTo(rB);
    final cA = (a['col'] as num?)?.toInt() ?? 0;
    final cB = (b['col'] as num?)?.toInt() ?? 0;
    return cA.compareTo(cB);
  }
}
