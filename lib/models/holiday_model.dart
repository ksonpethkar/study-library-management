import 'package:cloud_firestore/cloud_firestore.dart';

class HolidayModel {
  final String id;
  final String libraryId;
  final DateTime date;
  final String reason;
  final bool isFullDay;
  final DateTime createdAt;
  final bool membershipExtended;
  final int extensionDays;

  HolidayModel({
    required this.id,
    required this.libraryId,
    required this.date,
    required this.reason,
    required this.isFullDay,
    required this.createdAt,
    this.membershipExtended = false,
    this.extensionDays = 0,
  });

  factory HolidayModel.fromJson(Map<String, dynamic> json) {
    return HolidayModel(
      id: json['id'] as String? ?? '',
      libraryId: json['libraryId'] as String? ?? '',
      date: _parseDate(json['date']) ?? DateTime.now(),
      reason: json['reason'] as String? ?? '',
      isFullDay: json['isFullDay'] as bool? ?? true,
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      membershipExtended: json['membershipExtended'] as bool? ?? false,
      extensionDays: (json['extensionDays'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'libraryId': libraryId,
      'date': date.toIso8601String(),
      'reason': reason,
      'isFullDay': isFullDay,
      'createdAt': createdAt.toIso8601String(),
      'membershipExtended': membershipExtended,
      'extensionDays': extensionDays,
    };
  }

  HolidayModel copyWith({
    String? id,
    String? libraryId,
    DateTime? date,
    String? reason,
    bool? isFullDay,
    DateTime? createdAt,
    bool? membershipExtended,
    int? extensionDays,
  }) {
    return HolidayModel(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      date: date ?? this.date,
      reason: reason ?? this.reason,
      isFullDay: isFullDay ?? this.isFullDay,
      createdAt: createdAt ?? this.createdAt,
      membershipExtended: membershipExtended ?? this.membershipExtended,
      extensionDays: extensionDays ?? this.extensionDays,
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
