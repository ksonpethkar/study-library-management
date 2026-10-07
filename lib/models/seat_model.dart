enum SeatStatus { available, occupied, reserved, maintenance }
enum GenderRestriction { male, female, any }
enum SeatNamingStyle { alphanumeric, numeric, customPrefix, sectionPrefixAlphanumeric }

class SeatModel {
  final String id;
  final String sectionId;
  final int row;
  final int col;
  final String label;
  final SeatStatus status;
  final GenderRestriction genderRestriction;
  final String? studentId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  SeatModel({
    required this.id,
    required this.sectionId,
    required this.row,
    required this.col,
    required this.label,
    required this.status,
    required this.genderRestriction,
    this.studentId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory SeatModel.fromJson(Map<String, dynamic> json) {
    return SeatModel(
      id: json['id'] as String? ?? '',
      sectionId: json['sectionId'] as String? ?? '',
      row: json['row'] as int? ?? 0,
      col: json['col'] as int? ?? 0,
      label: json['label'] as String? ?? '',
      status: _parseSeatStatus(json['status'] as String?),
      genderRestriction: _parseGenderRestriction(json['genderRestriction'] as String?),
      studentId: json['studentId'] as String?,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      deletedAt: _parseDate(json['deletedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sectionId': sectionId,
      'row': row,
      'col': col,
      'label': label,
      'status': status.name,
      'genderRestriction': genderRestriction.name,
      if (studentId != null) 'studentId': studentId,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
    };
  }

  SeatModel copyWith({
    String? id,
    String? sectionId,
    int? row,
    int? col,
    String? label,
    SeatStatus? status,
    GenderRestriction? genderRestriction,
    String? studentId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return SeatModel(
      id: id ?? this.id,
      sectionId: sectionId ?? this.sectionId,
      row: row ?? this.row,
      col: col ?? this.col,
      label: label ?? this.label,
      status: status ?? this.status,
      genderRestriction: genderRestriction ?? this.genderRestriction,
      studentId: studentId ?? this.studentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  static SeatStatus _parseSeatStatus(String? status) {
    switch (status) {
      case 'occupied':
        return SeatStatus.occupied;
      case 'reserved':
        return SeatStatus.reserved;
      case 'maintenance':
        return SeatStatus.maintenance;
      case 'available':
      default:
        return SeatStatus.available;
    }
  }

  static GenderRestriction _parseGenderRestriction(String? res) {
    switch (res) {
      case 'male':
        return GenderRestriction.male;
      case 'female':
        return GenderRestriction.female;
      case 'any':
      default:
        return GenderRestriction.any;
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
