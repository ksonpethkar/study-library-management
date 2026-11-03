/// Utility helper to format and resolve human-friendly seat labels and numbers
/// across the entire application (avoiding raw database IDs like `1790647291016_r0_c4`).
class SeatHelper {
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
}
