import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String? reservationType;
  final String? reservedCandidateId;
  final String? reservedCandidateName;
  final DateTime? reservationExpiresAt;
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
    this.reservationType,
    this.reservedCandidateId,
    this.reservedCandidateName,
    this.reservationExpiresAt,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  bool get isCurrentlyReserved {
    if (status == SeatStatus.reserved) {
      if (reservationExpiresAt != null) {
        return reservationExpiresAt!.isAfter(DateTime.now());
      }
      return true;
    }
    return false;
  }

  /// Dynamic effective status: If a seat was marked 'reserved' but its reservation expired,
  /// it automatically behaves as 'available' in memory and UI.
  SeatStatus get effectiveStatus {
    if (status == SeatStatus.reserved && !isCurrentlyReserved) {
      return SeatStatus.available;
    }
    return status;
  }

  /// True if the seat is occupied by an active student
  bool get isOccupied =>
      effectiveStatus == SeatStatus.occupied ||
      (studentId != null && studentId!.isNotEmpty);

  /// True if currently held under a live, non-expired soft-lock
  bool get hasActiveSoftLock =>
      status == SeatStatus.reserved && isCurrentlyReserved;

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
      reservationType: json['reservationType'] as String?,
      reservedCandidateId: json['reservedCandidateId'] as String?,
      reservedCandidateName: json['reservedCandidateName'] as String?,
      reservationExpiresAt: _parseDate(json['reservationExpiresAt']),
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
      if (reservationType != null) 'reservationType': reservationType,
      if (reservedCandidateId != null) 'reservedCandidateId': reservedCandidateId,
      if (reservedCandidateName != null) 'reservedCandidateName': reservedCandidateName,
      if (reservationExpiresAt != null) 'reservationExpiresAt': reservationExpiresAt!.toIso8601String(),
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
    bool clearStudent = false,
    String? reservationType,
    String? reservedCandidateId,
    String? reservedCandidateName,
    DateTime? reservationExpiresAt,
    bool clearReservation = false,
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
      studentId: clearStudent ? null : (studentId ?? this.studentId),
      reservationType: clearReservation ? null : (reservationType ?? this.reservationType),
      reservedCandidateId: clearReservation ? null : (reservedCandidateId ?? this.reservedCandidateId),
      reservedCandidateName: clearReservation ? null : (reservedCandidateName ?? this.reservedCandidateName),
      reservationExpiresAt: clearReservation ? null : (reservationExpiresAt ?? this.reservationExpiresAt),
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
    if (date is Timestamp) return date.toDate();
    if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
    if (date is String) return DateTime.tryParse(date);
    try {
      return (date as dynamic).toDate();
    } catch (_) { /* intentionally silent */ }
    return null;
  }
}
