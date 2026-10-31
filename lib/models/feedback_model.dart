import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackModel {
  final String id;
  final String libraryId;
  final String studentId;
  final String? studentName;
  final String? studentPhone;
  final String message;
  final String? category;
  final String? feedbackType; // 'feedback', 'suggestion', 'issue'
  final int? rating;
  final String? adminReply;
  final String status; // 'unread', 'pending', 'resolved'
  final DateTime? createdAt;
  final DateTime? repliedAt;

  FeedbackModel({
    required this.id,
    required this.libraryId,
    required this.studentId,
    this.studentName,
    this.studentPhone,
    required this.message,
    this.category,
    this.feedbackType,
    this.rating,
    this.adminReply,
    this.status = 'pending',
    this.createdAt,
    this.repliedAt,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id: json['id'] as String? ?? '',
      libraryId: json['libraryId'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String?,
      studentPhone: json['studentPhone'] as String?,
      message: json['message'] as String? ?? '',
      category: json['category'] as String?,
      feedbackType: json['feedbackType'] as String?,
      rating: json['rating'] as int?,
      adminReply: json['adminReply'] as String? ?? json['reply'] as String?,
      status: json['status'] as String? ?? 'pending',
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
      if (studentPhone != null) 'studentPhone': studentPhone,
      'message': message,
      if (category != null) 'category': category,
      if (feedbackType != null) 'feedbackType': feedbackType,
      if (rating != null) 'rating': rating,
      if (adminReply != null) 'adminReply': adminReply,
      'status': status,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (repliedAt != null) 'repliedAt': repliedAt!.toIso8601String(),
    };
  }

  FeedbackModel copyWith({
    String? id,
    String? libraryId,
    String? studentId,
    String? studentName,
    String? studentPhone,
    String? message,
    String? category,
    int? rating,
    String? adminReply,
    String? status,
    DateTime? createdAt,
    DateTime? repliedAt,
  }) {
    return FeedbackModel(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentPhone: studentPhone ?? this.studentPhone,
      message: message ?? this.message,
      category: category ?? this.category,
      rating: rating ?? this.rating,
      adminReply: adminReply ?? this.adminReply,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      repliedAt: repliedAt ?? this.repliedAt,
    );
  }

  static DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is DateTime) return date;
    if (date is Timestamp) return date.toDate();
    if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
    if (date is String) return DateTime.tryParse(date);
    try {
      return (date as dynamic).toDate();
    } catch (_) { /* intentionally silent */ }
    return null;
  }
}
