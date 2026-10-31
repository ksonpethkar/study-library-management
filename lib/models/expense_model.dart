import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpenseCategory {
  rent,
  electricity,
  wifi,
  maintenance,
  salary,
  cleaning,
  supplies,
  water,
  marketing,
  software,
  other;

  String get displayName {
    switch (this) {
      case ExpenseCategory.rent:
        return 'Rent & Lease';
      case ExpenseCategory.electricity:
        return 'Electricity & Power';
      case ExpenseCategory.wifi:
        return 'Internet & Wi-Fi';
      case ExpenseCategory.maintenance:
        return 'Maintenance & Repairs';
      case ExpenseCategory.salary:
        return 'Staff Salaries';
      case ExpenseCategory.cleaning:
        return 'Housekeeping & Cleaning';
      case ExpenseCategory.supplies:
        return 'Supplies & Stationery';
      case ExpenseCategory.water:
        return 'Drinking Water & RO';
      case ExpenseCategory.marketing:
        return 'Marketing & Posters';
      case ExpenseCategory.software:
        return 'Software & Cloud';
      case ExpenseCategory.other:
        return 'Miscellaneous';
    }
  }

  String get iconEmoji {
    switch (this) {
      case ExpenseCategory.rent:
        return '🏢';
      case ExpenseCategory.electricity:
        return '⚡';
      case ExpenseCategory.wifi:
        return '📶';
      case ExpenseCategory.maintenance:
        return '🛠️';
      case ExpenseCategory.salary:
        return '👥';
      case ExpenseCategory.cleaning:
        return '🧹';
      case ExpenseCategory.supplies:
        return '📦';
      case ExpenseCategory.water:
        return '💧';
      case ExpenseCategory.marketing:
        return '📢';
      case ExpenseCategory.software:
        return '💻';
      case ExpenseCategory.other:
        return '🧾';
    }
  }

  static ExpenseCategory fromString(String? val) {
    if (val == null) return ExpenseCategory.other;
    return ExpenseCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => ExpenseCategory.other,
    );
  }
}

class ExpenseModel {
  final String id;
  final String libraryId;
  final String title;
  final ExpenseCategory category;
  final double amount;
  final DateTime date;
  final String paymentMethod;
  final String paidTo;
  final String? receiptUrl;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;

  ExpenseModel({
    required this.id,
    required this.libraryId,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    this.paidTo = '',
    this.receiptUrl,
    this.notes,
    this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic d) {
      if (d is Timestamp) return d.toDate();
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      if (d is int) return DateTime.fromMillisecondsSinceEpoch(d);
      return DateTime.now();
    }

    return ExpenseModel(
      id: json['id'] as String? ?? '',
      libraryId: json['libraryId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: ExpenseCategory.fromString(json['category'] as String?),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: parseDate(json['date']),
      paymentMethod: json['paymentMethod'] as String? ?? 'Cash',
      paidTo: json['paidTo'] as String? ?? '',
      receiptUrl: json['receiptUrl'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['createdBy'] as String?,
      createdAt: parseDate(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? parseDate(json['updatedAt']) : null,
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'libraryId': libraryId,
      'title': title,
      'category': category.name,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'paymentMethod': paymentMethod,
      'paidTo': paidTo,
      'receiptUrl': receiptUrl,
      'notes': notes,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'isDeleted': isDeleted,
    };
  }

  ExpenseModel copyWith({
    String? id,
    String? libraryId,
    String? title,
    ExpenseCategory? category,
    double? amount,
    DateTime? date,
    String? paymentMethod,
    String? paidTo,
    String? receiptUrl,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidTo: paidTo ?? this.paidTo,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
