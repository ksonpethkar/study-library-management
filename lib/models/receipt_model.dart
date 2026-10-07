enum ReceiptStatus { active, voided }

class ReceiptModel {
  final String id;
  final String libraryId;
  final String receiptNumber;
  final String studentId;
  final String? studentUserId;
  final String planId;
  final double amount;
  final String paymentMethod;
  final DateTime validFrom;
  final DateTime validTo;
  final String? pdfUrl;
  final Map<String, dynamic> customFields;
  final ReceiptStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  ReceiptModel({
    required this.id,
    required this.libraryId,
    required this.receiptNumber,
    required this.studentId,
    this.studentUserId,
    required this.planId,
    required this.amount,
    required this.paymentMethod,
    required this.validFrom,
    required this.validTo,
    this.pdfUrl,
    required this.customFields,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory ReceiptModel.fromJson(Map<String, dynamic> json) {
    return ReceiptModel(
      id: json['id'] as String? ?? '',
      libraryId: json['libraryId'] as String? ?? '',
      receiptNumber: json['receiptNumber'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      studentUserId: json['studentUserId'] as String?,
      planId: json['planId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod'] as String? ?? '',
      validFrom: _parseDate(json['validFrom']) ?? DateTime.now(),
      validTo: _parseDate(json['validTo']) ?? DateTime.now(),
      pdfUrl: json['pdfUrl'] as String?,
      customFields: (json['customFields'] as Map<String, dynamic>?) ?? {},
      status: _parseReceiptStatus(json['status'] as String?),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      deletedAt: _parseDate(json['deletedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'libraryId': libraryId,
      'receiptNumber': receiptNumber,
      'studentId': studentId,
      if (studentUserId != null) 'studentUserId': studentUserId,
      'planId': planId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'validFrom': validFrom.toIso8601String(),
      'validTo': validTo.toIso8601String(),
      if (pdfUrl != null) 'pdfUrl': pdfUrl,
      'customFields': customFields,
      'status': status.name,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
    };
  }

  ReceiptModel copyWith({
    String? id,
    String? libraryId,
    String? receiptNumber,
    String? studentId,
    String? studentUserId,
    String? planId,
    double? amount,
    String? paymentMethod,
    DateTime? validFrom,
    DateTime? validTo,
    String? pdfUrl,
    Map<String, dynamic>? customFields,
    ReceiptStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return ReceiptModel(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      studentId: studentId ?? this.studentId,
      studentUserId: studentUserId ?? this.studentUserId,
      planId: planId ?? this.planId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      validFrom: validFrom ?? this.validFrom,
      validTo: validTo ?? this.validTo,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      customFields: customFields ?? this.customFields,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  static ReceiptStatus _parseReceiptStatus(String? s) {
    switch (s) {
      case 'voided':
        return ReceiptStatus.voided;
      case 'active':
      default:
        return ReceiptStatus.active;
    }
  }

  static DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is DateTime) return date;
    if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
    if (date is String) return DateTime.tryParse(date);
    if (date.runtimeType.toString() == 'Timestamp') {
      try {
        return date.toDate();
      } catch (_) {}
    }
    return null;
  }
}
