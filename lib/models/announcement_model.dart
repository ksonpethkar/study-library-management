import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum AnnouncementType { broadcast, banner }

enum AnnouncementPriority {
  urgent,
  maintenance,
  holiday,
  general;

  String get label => switch (this) {
    AnnouncementPriority.urgent => 'Urgent',
    AnnouncementPriority.maintenance => 'Maintenance',
    AnnouncementPriority.holiday => 'Holiday',
    AnnouncementPriority.general => 'General',
  };

  IconData get icon => switch (this) {
    AnnouncementPriority.urgent => Icons.warning_amber_rounded,
    AnnouncementPriority.maintenance => Icons.build_circle_outlined,
    AnnouncementPriority.holiday => Icons.celebration_rounded,
    AnnouncementPriority.general => Icons.campaign_rounded,
  };

  Color get color => switch (this) {
    AnnouncementPriority.urgent => const Color(0xFFDC2626), // Crimson
    AnnouncementPriority.maintenance => const Color(0xFFD97706), // Amber
    AnnouncementPriority.holiday => const Color(0xFF059669), // Emerald
    AnnouncementPriority.general => const Color(0xFF2563EB), // Blue
  };

  Color get containerColor => switch (this) {
    AnnouncementPriority.urgent => const Color(0xFFFEE2E2),
    AnnouncementPriority.maintenance => const Color(0xFFFEF3C7),
    AnnouncementPriority.holiday => const Color(0xFFD1FAE5),
    AnnouncementPriority.general => const Color(0xFFDBEAFE),
  };

  Color get onContainerColor => switch (this) {
    AnnouncementPriority.urgent => const Color(0xFF991B1B),
    AnnouncementPriority.maintenance => const Color(0xFF92400E),
    AnnouncementPriority.holiday => const Color(0xFF065F46),
    AnnouncementPriority.general => const Color(0xFF1E40AF),
  };
}

class AnnouncementModel {
  final String id;
  final String libraryId;
  final String title;
  final String message;
  final AnnouncementType type;
  final AnnouncementPriority priority;
  final String targetAudience;
  final bool isActive;
  final List<String> readBy;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  AnnouncementModel({
    required this.id,
    required this.libraryId,
    required this.title,
    required this.message,
    required this.type,
    this.priority = AnnouncementPriority.general,
    this.targetAudience = 'all',
    required this.isActive,
    this.readBy = const [],
    this.createdAt,
    this.expiresAt,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool isReadBy(String studentId) => readBy.contains(studentId);

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'] as String? ?? '',
      libraryId: json['libraryId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: _parseType(json['type'] as String?),
      priority: _parsePriority(json['priority'] as String?),
      targetAudience: json['targetAudience'] as String? ?? 'all',
      isActive: json['isActive'] as bool? ?? true,
      readBy: (json['readBy'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
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
      'priority': priority.name,
      'targetAudience': targetAudience,
      'isActive': isActive,
      'readBy': readBy,
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
    AnnouncementPriority? priority,
    String? targetAudience,
    bool? isActive,
    List<String>? readBy,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      targetAudience: targetAudience ?? this.targetAudience,
      isActive: isActive ?? this.isActive,
      readBy: readBy ?? this.readBy,
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

  static AnnouncementPriority _parsePriority(String? p) {
    switch (p) {
      case 'urgent':
        return AnnouncementPriority.urgent;
      case 'maintenance':
        return AnnouncementPriority.maintenance;
      case 'holiday':
        return AnnouncementPriority.holiday;
      case 'general':
      default:
        return AnnouncementPriority.general;
    }
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
