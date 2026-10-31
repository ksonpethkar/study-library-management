import 'package:intl/intl.dart';

class UpiScanResult {
  final String? utr;
  final double? amount;
  final DateTime? date;
  final String? appName;
  final String? senderName;
  final int confidence;
  final String rawText;

  const UpiScanResult({
    this.utr,
    this.amount,
    this.date,
    this.appName,
    this.senderName,
    this.confidence = 0,
    required this.rawText,
  });

  bool get hasValidData => (utr != null && utr!.length == 12) || (amount != null && amount! > 0);
}

class UpiPaymentOcrParser {
  static UpiScanResult parse(String rawText) {
    int confidence = 0;

    // 1. Detect App
    String? appName;
    final upper = rawText.toUpperCase();
    if (upper.contains('GOOGLE PAY') || upper.contains('GPAY')) {
      appName = 'Google Pay';
      confidence += 15;
    } else if (upper.contains('PHONEPE') || upper.contains('PHONE PE')) {
      appName = 'PhonePe';
      confidence += 15;
    } else if (upper.contains('PAYTM')) {
      appName = 'Paytm';
      confidence += 15;
    } else if (upper.contains('BHIM')) {
      appName = 'BHIM UPI';
      confidence += 15;
    } else if (upper.contains('CRED')) {
      appName = 'CRED';
      confidence += 15;
    } else if (upper.contains('AMAZON PAY')) {
      appName = 'Amazon Pay';
      confidence += 15;
    } else if (upper.contains('UPI')) {
      appName = 'UPI';
      confidence += 10;
    }

    // 2. Extract 12-Digit UTR / UPI Reference Number
    String? utr;
    final utrPatterns = [
      RegExp(r'(?:UPI\s*(?:Ref|Transaction|Txn)\s*(?:ID|No|Number)?|UTR(?:\s*No)?|Ref\s*No)[:\s\-#]*([0-9]{12})\b', caseSensitive: false),
      RegExp(r'(?:Google\s*transaction\s*ID)[:\s\-#]*([0-9A-Za-z\-_]{10,25})', caseSensitive: false),
      RegExp(r'\b([0-9]{12})\b'), // Standalone 12 digits
    ];

    for (final pattern in utrPatterns) {
      final match = pattern.firstMatch(rawText);
      if (match != null) {
        final candidate = match.group(1);
        if (candidate != null && RegExp(r'^\d{12}$').hasMatch(candidate)) {
          // Avoid matching 12-digit timestamps or date combinations
          if (!candidate.startsWith('202') && !candidate.startsWith('199')) {
            utr = candidate;
            confidence += 40;
            break;
          }
        }
      }
    }

    // Fallback search for 12 contiguous digits in lines
    if (utr == null) {
      final lines = rawText.split('\n');
      for (final line in lines) {
        final match = RegExp(r'\b([0-9]{12})\b').firstMatch(line);
        if (match != null) {
          utr = match.group(1);
          confidence += 25;
          break;
        }
      }
    }

    // 3. Extract Amount (₹)
    double? amount;
    final amountPatterns = [
      RegExp(r'(?:₹|Rs\.?|INR)\s*([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)'),
      RegExp(r'(?:Paid|Amount|Transfer(?:red)?|Debited)\s*(?:of)?\s*(?:₹|Rs\.?|INR)?\s*([0-9,]+(?:\.[0-9]{2})?)', caseSensitive: false),
      RegExp(r'\b([1-9][0-9]{2,5}(?:\.[0-9]{2})?)\b'), // Standalone plausible library fee (100 - 999999)
    ];

    for (final pattern in amountPatterns) {
      final match = pattern.firstMatch(rawText);
      if (match != null) {
        final cleanAmt = match.group(1)?.replaceAll(',', '');
        final parsed = double.tryParse(cleanAmt ?? '');
        if (parsed != null && parsed >= 50 && parsed <= 100000) {
          amount = parsed;
          confidence += 35;
          break;
        }
      }
    }

    // 4. Extract Date & Time
    DateTime? date;
    final datePatterns = [
      RegExp(r'\b(\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{4})\b', caseSensitive: false),
      RegExp(r'\b(\d{2}[/\-.]\d{2}[/\-.]\d{4})\b'),
    ];

    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(rawText);
      if (match != null) {
        final dateStr = match.group(1);
        if (dateStr != null) {
          try {
            if (dateStr.contains('/')) {
              final parts = dateStr.split('/');
              date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
            } else if (dateStr.contains('-')) {
              final parts = dateStr.split('-');
              date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
            } else {
              date = DateFormat('d MMM yyyy').parse(dateStr);
            }
            confidence += 10;
            break;
          } catch (_) { /* ignore format parse errors */ }
        }
      }
    }

    return UpiScanResult(
      utr: utr,
      amount: amount,
      date: date,
      appName: appName,
      confidence: confidence.clamp(0, 100),
      rawText: rawText,
    );
  }
}
