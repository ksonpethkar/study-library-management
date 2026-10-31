import 'package:cloud_firestore/cloud_firestore.dart';

class RecycleBinItem {
  final String id;
  final String type;
  final Map<String, dynamic> originalData;
  final String deletedBy;
  final DateTime deletedAt;
  final DateTime expiresAt;
  final String displayName;

  RecycleBinItem({
    required this.id,
    required this.type,
    required this.originalData,
    required this.deletedBy,
    required this.deletedAt,
    required this.expiresAt,
    required this.displayName,
  });

  factory RecycleBinItem.fromJson(Map<String, dynamic> json) {
    return RecycleBinItem(
      id: json['id'] ?? '',
      type: json['type'] ?? 'unknown',
      originalData: json['originalData'] ?? {},
      deletedBy: json['deletedBy'] ?? 'system',
      deletedAt: _parseDate(json['deletedAt']) ?? DateTime.now(),
      expiresAt: _parseDate(json['expiresAt']) ?? DateTime.now().add(const Duration(days: 30)),
      displayName: json['displayName'] ?? 'Deleted Item',
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'originalData': originalData,
      'deletedBy': deletedBy,
      'deletedAt': Timestamp.fromDate(deletedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'displayName': displayName,
    };
  }
}
