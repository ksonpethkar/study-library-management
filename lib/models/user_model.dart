import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, student }

class UserModel {
  final String id;
  final String email;
  final String name;
  final String photoUrl;
  final UserRole role;
  final String? libraryId;
  final String? studentId;
  final bool biometricEnabled;
  final String? pinHash;
  final List<String> fcmTokens;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.photoUrl,
    required this.role,
    this.libraryId,
    this.studentId,
    required this.biometricEnabled,
    this.pinHash,
    required this.fcmTokens,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      photoUrl: json['photoUrl'] as String? ?? '',
      role: _parseUserRole(json['role'] as String?),
      libraryId: json['libraryId'] as String?,
      studentId: json['studentId'] as String?,
      biometricEnabled: json['biometricEnabled'] as bool? ?? false,
      pinHash: json['pinHash'] as String?,
      fcmTokens: (json['fcmTokens'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'role': role.name,
      if (libraryId != null) 'libraryId': libraryId,
      if (studentId != null) 'studentId': studentId,
      'biometricEnabled': biometricEnabled,
      if (pinHash != null) 'pinHash': pinHash,
      'fcmTokens': fcmTokens,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? photoUrl,
    UserRole? role,
    String? libraryId,
    String? studentId,
    bool? biometricEnabled,
    String? pinHash,
    List<String>? fcmTokens,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      libraryId: libraryId ?? this.libraryId,
      studentId: studentId ?? this.studentId,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      pinHash: pinHash ?? this.pinHash,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // SEC-H3 FIX: Default to student (least privilege) instead of admin.
  // Only explicitly set 'admin' role maps to admin — unknown/null = student.
  static UserRole _parseUserRole(String? r) {
    switch (r) {
      case 'admin':
        return UserRole.admin;
      case 'student':
      default:
        return UserRole.student;
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
