enum PaymentStatus { paid, partial, pending, overdue }

class PaymentModel {
  final String id;
  final String studentId;
  final double amount;
  final String method;
  final String? methodDetails;
  final DateTime date;
  final String? referenceNumber;
  final String? screenshotUrl;
  final String? screenshotCompressed;
  final String? notes;
  final String? receiptId;
  final PaymentStatus status;
  final DateTime createdAt;

  PaymentModel({
    required this.id,
    required this.studentId,
    required this.amount,
    required this.method,
    this.methodDetails,
    required this.date,
    this.referenceNumber,
    this.screenshotUrl,
    this.screenshotCompressed,
    this.notes,
    this.receiptId,
    required this.status,
    required this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      method: json['method'] as String? ?? '',
      methodDetails: json['methodDetails'] as String?,
      date: _parseDate(json['date']) ?? DateTime.now(),
      referenceNumber: json['referenceNumber'] as String?,
      screenshotUrl: json['screenshotUrl'] as String?,
      screenshotCompressed: json['screenshotCompressed'] as String?,
      notes: json['notes'] as String?,
      receiptId: json['receiptId'] as String?,
      status: _parsePaymentStatus(json['status'] as String?),
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'amount': amount,
      'method': method,
      if (methodDetails != null) 'methodDetails': methodDetails,
      'date': date.toIso8601String(),
      if (referenceNumber != null) 'referenceNumber': referenceNumber,
      if (screenshotUrl != null) 'screenshotUrl': screenshotUrl,
      if (screenshotCompressed != null) 'screenshotCompressed': screenshotCompressed,
      if (notes != null) 'notes': notes,
      if (receiptId != null) 'receiptId': receiptId,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  PaymentModel copyWith({
    String? id,
    String? studentId,
    double? amount,
    String? method,
    String? methodDetails,
    DateTime? date,
    String? referenceNumber,
    String? screenshotUrl,
    String? screenshotCompressed,
    String? notes,
    String? receiptId,
    PaymentStatus? status,
    DateTime? createdAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      methodDetails: methodDetails ?? this.methodDetails,
      date: date ?? this.date,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      screenshotUrl: screenshotUrl ?? this.screenshotUrl,
      screenshotCompressed: screenshotCompressed ?? this.screenshotCompressed,
      notes: notes ?? this.notes,
      receiptId: receiptId ?? this.receiptId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static PaymentStatus _parsePaymentStatus(String? s) {
    switch (s) {
      case 'partial':
        return PaymentStatus.partial;
      case 'pending':
        return PaymentStatus.pending;
      case 'overdue':
        return PaymentStatus.overdue;
      case 'paid':
      default:
        return PaymentStatus.paid;
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
