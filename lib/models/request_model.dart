enum RequestType { newRegistration, renewal, seatChange }
enum RequestStatus { pending, approved, rejected }

class RequestModel {
  final String id;
  final String libraryId;
  final RequestType type;
  final Map<String, dynamic> studentData;
  final String? seatId;
  final String? planId;
  final RequestStatus status;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? processedAt;

  RequestModel({
    required this.id,
    required this.libraryId,
    required this.type,
    required this.studentData,
    this.seatId,
    this.planId,
    required this.status,
    this.rejectionReason,
    this.createdAt,
    this.processedAt,
  });

  factory RequestModel.fromJson(Map<String, dynamic> json) {
    return RequestModel(
      id: json['id'] as String? ?? '',
      libraryId: json['libraryId'] as String? ?? '',
      type: _parseRequestType(json['type'] as String?),
      studentData: (json['studentData'] as Map<String, dynamic>?) ?? {},
      seatId: json['seatId'] as String?,
      planId: json['planId'] as String?,
      status: _parseRequestStatus(json['status'] as String?),
      rejectionReason: json['rejectionReason'] as String?,
      createdAt: _parseDate(json['createdAt']),
      processedAt: _parseDate(json['processedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'libraryId': libraryId,
      'type': type.name,
      'studentData': studentData,
      if (seatId != null) 'seatId': seatId,
      if (planId != null) 'planId': planId,
      'status': status.name,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (processedAt != null) 'processedAt': processedAt!.toIso8601String(),
    };
  }

  RequestModel copyWith({
    String? id,
    String? libraryId,
    RequestType? type,
    Map<String, dynamic>? studentData,
    String? seatId,
    String? planId,
    RequestStatus? status,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? processedAt,
  }) {
    return RequestModel(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      type: type ?? this.type,
      studentData: studentData ?? this.studentData,
      seatId: seatId ?? this.seatId,
      planId: planId ?? this.planId,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
    );
  }

  static RequestType _parseRequestType(String? t) {
    switch (t) {
      case 'renewal':
        return RequestType.renewal;
      case 'seatChange':
        return RequestType.seatChange;
      case 'newRegistration':
      default:
        return RequestType.newRegistration;
    }
  }

  static RequestStatus _parseRequestStatus(String? s) {
    switch (s) {
      case 'approved':
        return RequestStatus.approved;
      case 'rejected':
        return RequestStatus.rejected;
      case 'pending':
      default:
        return RequestStatus.pending;
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
