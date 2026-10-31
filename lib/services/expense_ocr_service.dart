import 'package:intl/intl.dart';
import 'package:study_library/models/expense_model.dart';

class ExpenseBillScanResult {
  final double? amount;
  final DateTime? date;
  final String? vendorName;
  final ExpenseCategory suggestedCategory;
  final String? invoiceNumber;
  final int confidence;
  final String rawText;

  const ExpenseBillScanResult({
    this.amount,
    this.date,
    this.vendorName,
    this.suggestedCategory = ExpenseCategory.other,
    this.invoiceNumber,
    this.confidence = 0,
    required this.rawText,
  });

  bool get hasValidData => (amount != null && amount! > 0) || (vendorName != null && vendorName!.isNotEmpty);
}

class ExpenseOcrParser {
  static ExpenseBillScanResult parse(String rawText) {
    int confidence = 0;
    final upper = rawText.toUpperCase();

    // 1. Detect Category by Keyword Analysis
    ExpenseCategory category = ExpenseCategory.other;
    if (upper.contains('MSEDCL') ||
        upper.contains('MAHAVITARAN') ||
        upper.contains('POWER') ||
        upper.contains('ELECTRICITY') ||
        upper.contains('ELECTRIC') ||
        upper.contains('DISCOM') ||
        upper.contains('KWH') ||
        upper.contains('METER READING')) {
      category = ExpenseCategory.electricity;
      confidence += 25;
    } else if (upper.contains('AIRTEL') ||
        upper.contains('JIO') ||
        upper.contains('JIOFIBER') ||
        upper.contains('BROADBAND') ||
        upper.contains('INTERNET') ||
        upper.contains('WI-FI') ||
        upper.contains('WIFI') ||
        upper.contains('FIBER')) {
      category = ExpenseCategory.wifi;
      confidence += 25;
    } else if (upper.contains('WATER') ||
        upper.contains('RO WATER') ||
        upper.contains('BISLERI') ||
        upper.contains('AQUAFINA') ||
        upper.contains('CAN WATER')) {
      category = ExpenseCategory.water;
      confidence += 25;
    } else if (upper.contains('RENT') ||
        upper.contains('LEASE') ||
        upper.contains('LANDLORD') ||
        upper.contains('PREMISES')) {
      category = ExpenseCategory.rent;
      confidence += 25;
    } else if (upper.contains('SALARY') ||
        upper.contains('STIPEND') ||
        upper.contains('WAGES') ||
        upper.contains('STAFF')) {
      category = ExpenseCategory.salary;
      confidence += 25;
    } else if (upper.contains('CLEANING') ||
        upper.contains('HOUSEKEEPING') ||
        upper.contains('HARPIC') ||
        upper.contains('LIZOL') ||
        upper.contains('DETERGENT') ||
        upper.contains('SWEEPER')) {
      category = ExpenseCategory.cleaning;
      confidence += 25;
    } else if (upper.contains('STATIONERY') ||
        upper.contains('PAPER') ||
        upper.contains('XEROX') ||
        upper.contains('PRINTING') ||
        upper.contains('CARTRIDGE') ||
        upper.contains('PEN') ||
        upper.contains('NOTEPAD')) {
      category = ExpenseCategory.supplies;
      confidence += 25;
    } else if (upper.contains('REPAIR') ||
        upper.contains('MAINTENANCE') ||
        upper.contains('HARDWARE') ||
        upper.contains('PLUMBER') ||
        upper.contains('ELECTRICIAN') ||
        upper.contains('AC SERVICE')) {
      category = ExpenseCategory.maintenance;
      confidence += 25;
    }

    // 2. Extract Total Amount
    double? amount;
    final amountPatterns = [
      RegExp(r'(?:Total\s*Amount|Grand\s*Total|Net\s*Payable|Total\s*Due|Invoice\s*Amount|Amount\s*Due|Bill\s*Amount)[:\s\-#]*(?:₹|Rs\.?|INR)?\s*([0-9,]+(?:\.[0-9]{2})?)', caseSensitive: false),
      RegExp(r'(?:₹|Rs\.?|INR)\s*([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)'),
    ];

    for (final pattern in amountPatterns) {
      final match = pattern.firstMatch(rawText);
      if (match != null) {
        final cleanAmt = match.group(1)?.replaceAll(',', '');
        final parsed = double.tryParse(cleanAmt ?? '');
        if (parsed != null && parsed > 0 && parsed <= 500000) {
          amount = parsed;
          confidence += 35;
          break;
        }
      }
    }

    // 3. Extract Invoice Date
    DateTime? date;
    final datePatterns = [
      RegExp(r'(?:Bill\s*Date|Invoice\s*Date|Date)[:\s\-]*(\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{4})', caseSensitive: false),
      RegExp(r'(?:Bill\s*Date|Invoice\s*Date|Date)[:\s\-]*(\d{2}[/\-.]\d{2}[/\-.]\d{4})', caseSensitive: false),
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
            confidence += 15;
            break;
          } catch (_) { /* ignore */ }
        }
      }
    }

    // 4. Extract Vendor Name (first prominent non-boilerplate line)
    String? vendorName;
    final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    for (final l in lines.take(5)) {
      final clean = l.replaceAll(RegExp(r'[^A-Za-z0-9\s.\-&]'), '').trim();
      if (clean.length >= 4 && clean.length <= 40 && !clean.toUpperCase().contains('TAX INVOICE') && !clean.toUpperCase().contains('BILL')) {
        vendorName = clean;
        confidence += 15;
        break;
      }
    }

    // 5. Extract Invoice Number
    String? invoiceNumber;
    final invMatch = RegExp(r'(?:Invoice\s*No|Bill\s*No|Receipt\s*No)[:\s\-#]*([A-Za-z0-9/\-]{4,20})', caseSensitive: false).firstMatch(rawText);
    if (invMatch != null) {
      invoiceNumber = invMatch.group(1);
      confidence += 10;
    }

    return ExpenseBillScanResult(
      amount: amount,
      date: date,
      vendorName: vendorName,
      suggestedCategory: category,
      invoiceNumber: invoiceNumber,
      confidence: confidence.clamp(0, 100),
      rawText: rawText,
    );
  }
}
