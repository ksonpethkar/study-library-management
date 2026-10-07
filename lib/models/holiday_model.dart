class HolidayModel {
  final String id;
  final String libraryId;
  final DateTime date;
  final String reason;
  final bool isFullDay;
  final DateTime createdAt;

  HolidayModel({
    required this.id,
    required this.libraryId,
    required this.date,
    required this.reason,
    required this.isFullDay,
    required this.createdAt,
  });

  factory HolidayModel.fromJson(Map<String, dynamic> json) {
    return HolidayModel(
      id: json['id'] as String? ?? '',
      libraryId: json['libraryId'] as String? ?? '',
      date: _parseDate(json['date']) ?? DateTime.now(),
      reason: json['reason'] as String? ?? '',
      isFullDay: json['isFullDay'] as bool? ?? true,
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
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
    };
  }

  HolidayModel copyWith({
    String? id,
    String? libraryId,
    DateTime? date,
    String? reason,
    bool? isFullDay,
    DateTime? createdAt,
  }) {
    return HolidayModel(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      date: date ?? this.date,
      reason: reason ?? this.reason,
      isFullDay: isFullDay ?? this.isFullDay,
      createdAt: createdAt ?? this.createdAt,
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
