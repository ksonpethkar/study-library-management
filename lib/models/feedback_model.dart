class FeedbackModel {
  final String id;
  final String libraryId;
  final String studentId;
  final String? studentName;
  final String message;
  final int? rating;
  final String? adminReply;
  final DateTime? createdAt;
  final DateTime? repliedAt;

  FeedbackModel({
    required this.id,
    required this.libraryId,
    required this.studentId,
    this.studentName,
    required this.message,
    this.rating,
    this.adminReply,
    this.createdAt,
    this.repliedAt,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id: json['id'] as String? ?? '',
      libraryId: json['libraryId'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String?,
      message: json['message'] as String? ?? '',
      rating: json['rating'] as int?,
      adminReply: json['adminReply'] as String?,
      createdAt: _parseDate(json['createdAt']),
      repliedAt: _parseDate(json['repliedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'libraryId': libraryId,
      'studentId': studentId,
      if (studentName != null) 'studentName': studentName,
      'message': message,
      if (rating != null) 'rating': rating,
      if (adminReply != null) 'adminReply': adminReply,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (repliedAt != null) 'repliedAt': repliedAt!.toIso8601String(),
    };
  }

  FeedbackModel copyWith({
    String? id,
    String? libraryId,
    String? studentId,
    String? studentName,
    String? message,
    int? rating,
    String? adminReply,
    DateTime? createdAt,
    DateTime? repliedAt,
  }) {
    return FeedbackModel(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      message: message ?? this.message,
      rating: rating ?? this.rating,
      adminReply: adminReply ?? this.adminReply,
      createdAt: createdAt ?? this.createdAt,
      repliedAt: repliedAt ?? this.repliedAt,
    );
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
