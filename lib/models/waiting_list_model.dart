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
  });

  factory WaitingListEntry.fromJson(Map<String, dynamic> json) {
    return WaitingListEntry(
      id: json['id'] ?? '',
      libraryId: json['libraryId'] ?? '',
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'] ?? '',
      studentPhone: json['studentPhone'] ?? '',
      preferredSectionId: json['preferredSectionId'],
      genderPreference: json['genderPreference'] ?? 'none',
      position: json['position'] ?? 0,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      notifiedAt: json['notifiedAt'] != null ? DateTime.parse(json['notifiedAt']) : null,
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
      'createdAt': createdAt?.toIso8601String(),
      'notifiedAt': notifiedAt?.toIso8601String(),
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
    );
  }
}
