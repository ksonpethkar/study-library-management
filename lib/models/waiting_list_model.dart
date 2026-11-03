class WaitingListEntry {
  final String id;
  final String libraryId;
  final String studentId;
  final String studentName;
  final String studentPhone;
  final String? preferredSectionId;
  final String genderPreference; // Use string or enum mapping
  final int position;
  final DateTime? createdAt;
  final DateTime? notifiedAt;
  final String status; // 'waiting', 'offered', 'accepted', 'offer_expired', 'cancelled'
  final DateTime? reservationExpiresAt;
  final String? suggestedSeatId;
  final String? suggestedSectionId;
  final String? suggestedSeatLabel;
  final String? offeredSeatId;
  final String? offeredSectionId;
  final String? offeredSeatLabel;
  final String? notes;

  WaitingListEntry({
    required this.id,
    required this.libraryId,
    required this.studentId,
    required this.studentName,
    required this.studentPhone,
    this.preferredSectionId,
    this.genderPreference = 'none',
    required this.position,
    this.createdAt,
    this.notifiedAt,
    this.status = 'waiting',
    this.reservationExpiresAt,
    this.suggestedSeatId,
    this.suggestedSectionId,
    this.suggestedSeatLabel,
    this.offeredSeatId,
    this.offeredSectionId,
    this.offeredSeatLabel,
    this.notes,
  });

  factory WaitingListEntry.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d);
      try { return (d as dynamic).toDate(); } catch (_) {}
      return null;
    }

    return WaitingListEntry(
      id: json['id'] ?? '',
      libraryId: json['libraryId'] ?? '',
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'] ?? '',
      studentPhone: json['studentPhone'] ?? '',
      preferredSectionId: json['preferredSectionId'],
      genderPreference: json['genderPreference'] ?? 'none',
      position: json['position'] ?? 0,
      createdAt: parseDate(json['createdAt']),
      notifiedAt: parseDate(json['notifiedAt']),
      status: json['status'] ?? 'waiting',
      reservationExpiresAt: parseDate(json['reservationExpiresAt']),
      suggestedSeatId: json['suggestedSeatId'] as String?,
      suggestedSectionId: json['suggestedSectionId'] as String?,
      suggestedSeatLabel: json['suggestedSeatLabel'] as String?,
      offeredSeatId: json['offeredSeatId'] as String?,
      offeredSectionId: json['offeredSectionId'] as String?,
      offeredSeatLabel: json['offeredSeatLabel'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'libraryId': libraryId,
      'studentId': studentId,
      'studentName': studentName,
      'studentPhone': studentPhone,
      'preferredSectionId': preferredSectionId,
      'genderPreference': genderPreference,
      'position': position,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'notifiedAt': notifiedAt?.toIso8601String(),
      if (reservationExpiresAt != null) 'reservationExpiresAt': reservationExpiresAt!.toIso8601String(),
      if (suggestedSeatId != null) 'suggestedSeatId': suggestedSeatId,
      if (suggestedSectionId != null) 'suggestedSectionId': suggestedSectionId,
      if (suggestedSeatLabel != null) 'suggestedSeatLabel': suggestedSeatLabel,
      if (offeredSeatId != null) 'offeredSeatId': offeredSeatId,
      if (offeredSectionId != null) 'offeredSectionId': offeredSectionId,
      if (offeredSeatLabel != null) 'offeredSeatLabel': offeredSeatLabel,
      if (notes != null) 'notes': notes,
    };
  }

  WaitingListEntry copyWith({
    String? id,
    String? libraryId,
    String? studentId,
    String? studentName,
    String? studentPhone,
    String? preferredSectionId,
    String? genderPreference,
    int? position,
    DateTime? createdAt,
    DateTime? notifiedAt,
    String? status,
    DateTime? reservationExpiresAt,
    String? suggestedSeatId,
    String? suggestedSectionId,
    String? suggestedSeatLabel,
    String? offeredSeatId,
    String? offeredSectionId,
    String? offeredSeatLabel,
    String? notes,
  }) {
    return WaitingListEntry(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentPhone: studentPhone ?? this.studentPhone,
      preferredSectionId: preferredSectionId ?? this.preferredSectionId,
      genderPreference: genderPreference ?? this.genderPreference,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      notifiedAt: notifiedAt ?? this.notifiedAt,
      status: status ?? this.status,
      reservationExpiresAt: reservationExpiresAt ?? this.reservationExpiresAt,
      suggestedSeatId: suggestedSeatId ?? this.suggestedSeatId,
      suggestedSectionId: suggestedSectionId ?? this.suggestedSectionId,
      suggestedSeatLabel: suggestedSeatLabel ?? this.suggestedSeatLabel,
      offeredSeatId: offeredSeatId ?? this.offeredSeatId,
      offeredSectionId: offeredSectionId ?? this.offeredSectionId,
      offeredSeatLabel: offeredSeatLabel ?? this.offeredSeatLabel,
      notes: notes ?? this.notes,
    );
  }
}
