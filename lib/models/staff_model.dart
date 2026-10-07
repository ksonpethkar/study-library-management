enum StaffRole { owner, manager, operator }

class StaffModel {
  final String id;
  final String libraryId;
  final String userId;
  final String email;
  final String name;
  final StaffRole role;
  final bool canManageSeats;
  final bool canRecordPayments;
  final bool canManageStudents;
  final bool canDeleteStudents;
  final bool canViewRevenue;
  final bool canManageSettings;
  final DateTime createdAt;
  final DateTime? updatedAt;

  StaffModel({
    required this.id,
    required this.libraryId,
    required this.userId,
    required this.email,
    required this.name,
    required this.role,
    required this.canManageSeats,
    required this.canRecordPayments,
    required this.canManageStudents,
    required this.canDeleteStudents,
    required this.canViewRevenue,
    required this.canManageSettings,
    required this.createdAt,
    this.updatedAt,
  });

  factory StaffModel.defaultForRole({
    required String id,
    required String libraryId,
    required String userId,
    required String email,
    required String name,
    required StaffRole role,
  }) {
    switch (role) {
      case StaffRole.owner:
        return StaffModel(
          id: id,
          libraryId: libraryId,
          userId: userId,
          email: email,
          name: name,
          role: role,
          canManageSeats: true,
          canRecordPayments: true,
          canManageStudents: true,
          canDeleteStudents: true,
          canViewRevenue: true,
          canManageSettings: true,
          createdAt: DateTime.now(),
        );
      case StaffRole.manager:
        return StaffModel(
          id: id,
          libraryId: libraryId,
          userId: userId,
          email: email,
          name: name,
          role: role,
          canManageSeats: true,
          canRecordPayments: true,
          canManageStudents: true,
          canDeleteStudents: false,
          canViewRevenue: true,
          canManageSettings: false,
          createdAt: DateTime.now(),
        );
      case StaffRole.operator:
        return StaffModel(
          id: id,
          libraryId: libraryId,
          userId: userId,
          email: email,
          name: name,
          role: role,
          canManageSeats: true,
          canRecordPayments: true,
          canManageStudents: false,
          canDeleteStudents: false,
          canViewRevenue: false,
          canManageSettings: false,
          createdAt: DateTime.now(),
        );
    }
  }

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      id: json['id'] as String? ?? '',
      libraryId: json['libraryId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: _parseRole(json['role'] as String?),
      canManageSeats: json['canManageSeats'] as bool? ?? true,
      canRecordPayments: json['canRecordPayments'] as bool? ?? true,
      canManageStudents: json['canManageStudents'] as bool? ?? true,
      canDeleteStudents: json['canDeleteStudents'] as bool? ?? false,
      canViewRevenue: json['canViewRevenue'] as bool? ?? false,
      canManageSettings: json['canManageSettings'] as bool? ?? false,
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'libraryId': libraryId,
      'userId': userId,
      'email': email,
      'name': name,
      'role': role.name,
      'canManageSeats': canManageSeats,
      'canRecordPayments': canRecordPayments,
      'canManageStudents': canManageStudents,
      'canDeleteStudents': canDeleteStudents,
      'canViewRevenue': canViewRevenue,
      'canManageSettings': canManageSettings,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  StaffModel copyWith({
    String? id,
    String? libraryId,
    String? userId,
    String? email,
    String? name,
    StaffRole? role,
    bool? canManageSeats,
    bool? canRecordPayments,
    bool? canManageStudents,
    bool? canDeleteStudents,
    bool? canViewRevenue,
    bool? canManageSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StaffModel(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      canManageSeats: canManageSeats ?? this.canManageSeats,
      canRecordPayments: canRecordPayments ?? this.canRecordPayments,
      canManageStudents: canManageStudents ?? this.canManageStudents,
      canDeleteStudents: canDeleteStudents ?? this.canDeleteStudents,
      canViewRevenue: canViewRevenue ?? this.canViewRevenue,
      canManageSettings: canManageSettings ?? this.canManageSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static StaffRole _parseRole(String? val) {
    switch (val) {
      case 'owner':
        return StaffRole.owner;
      case 'manager':
        return StaffRole.manager;
      case 'operator':
      default:
        return StaffRole.operator;
    }
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is String) return DateTime.tryParse(val);
    return null;
  }
}
