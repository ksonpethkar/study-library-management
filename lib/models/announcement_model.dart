enum AnnouncementType { broadcast, banner }

class AnnouncementModel {
  final String id;
  final String libraryId;
  final String title;
  final String message;
  final AnnouncementType type;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  AnnouncementModel({
    required this.id,
    required this.libraryId,
    required this.title,
    required this.message,
    required this.type,
    required this.isActive,
    this.createdAt,
    this.expiresAt,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'] as String? ?? '',
      libraryId: json['libraryId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: _parseType(json['type'] as String?),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: _parseDate(json['createdAt']),
      expiresAt: _parseDate(json['expiresAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'libraryId': libraryId,
      'title': title,
      'message': message,
      'type': type.name,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    };
  }

  AnnouncementModel copyWith({
    String? id,
    String? libraryId,
    String? title,
    String? message,
    AnnouncementType? type,
    bool? isActive,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  static AnnouncementType _parseType(String? t) {
    switch (t) {
      case 'banner':
        return AnnouncementType.banner;
      case 'broadcast':
      default:
        return AnnouncementType.broadcast;
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
