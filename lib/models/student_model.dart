enum Gender { male, female, other }
enum GovIdType { aadhaar, pan, drivingLicence, collegeId }
enum MembershipStatus { active, expired, grace, pending, inactive, archived, blocked }

class StudentModel {
  final String id;
  final String name;
  final String fatherName;
  final String phone;
  final String email;
  final DateTime? dob;
  final Gender gender;
  final String address;
  final String pincode;
  final GovIdType govIdType;
  final String govIdNumber; // encrypted ideally
  final String govIdImageUrl;
  final String photoUrl;
  final String college;
  final String course;
  final String year;
  final String emergencyContact;
  final String? seatId;
  final String? sectionId;
  final String? planId;
  final DateTime? planStartDate;
  final DateTime? planEndDate;
  final DateTime? graceEndDate;
  final MembershipStatus membershipStatus;
  final Map<String, dynamic> customFields;
  final String? notes;
  final String? userId;
  final String? idCardUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String? membershipNumber; // e.g. "CC20260001"
  final String? bloodGroup;       // e.g. "A+"
  final String? rollNumber;       // college roll number
  final String? blockedReason;

  StudentModel({
    required this.id,
    required this.name,
    required this.fatherName,
    required this.phone,
    required this.email,
    this.dob,
    required this.gender,
    required this.address,
    required this.pincode,
    required this.govIdType,
    required this.govIdNumber,
    required this.govIdImageUrl,
    required this.photoUrl,
    required this.college,
    required this.course,
    required this.year,
    required this.emergencyContact,
    this.seatId,
    this.sectionId,
    this.planId,
    this.planStartDate,
    this.planEndDate,
    this.graceEndDate,
    required this.membershipStatus,
    required this.customFields,
    this.notes,
    this.userId,
    this.idCardUrl,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.membershipNumber,
    this.bloodGroup,
    this.rollNumber,
    this.blockedReason,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      fatherName: json['fatherName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      dob: _parseDate(json['dob']),
      gender: _parseGender(json['gender'] as String?),
      address: json['address'] as String? ?? '',
      pincode: json['pincode'] as String? ?? '',
      govIdType: _parseGovIdType(json['govIdType'] as String?),
      govIdNumber: json['govIdNumber'] as String? ?? '',
      govIdImageUrl: json['govIdImageUrl'] as String? ?? '',
      photoUrl: json['photoUrl'] as String? ?? '',
      college: json['college'] as String? ?? '',
      course: json['course'] as String? ?? '',
      year: json['year'] as String? ?? '',
      emergencyContact: json['emergencyContact'] as String? ?? '',
      seatId: json['seatId'] as String?,
      sectionId: json['sectionId'] as String?,
      planId: json['planId'] as String?,
      planStartDate: _parseDate(json['planStartDate']),
      planEndDate: _parseDate(json['planEndDate']),
      graceEndDate: _parseDate(json['graceEndDate']),
      membershipStatus: _parseMembershipStatus(json['membershipStatus'] as String?),
      customFields: (json['customFields'] as Map<String, dynamic>?) ?? {},
      notes: json['notes'] as String?,
      userId: json['userId'] as String?,
      idCardUrl: json['idCardUrl'] as String?,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      deletedAt: _parseDate(json['deletedAt']),
      membershipNumber: json['membershipNumber'] as String?,
      bloodGroup: json['bloodGroup'] as String?,
      rollNumber: json['rollNumber'] as String?,
      blockedReason: json['blockedReason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'fatherName': fatherName,
      'phone': phone,
      'email': email,
      if (dob != null) 'dob': dob!.toIso8601String(),
      'gender': gender.name,
      'address': address,
      'pincode': pincode,
      'govIdType': govIdType.name,
      'govIdNumber': govIdNumber,
      'govIdImageUrl': govIdImageUrl,
      'photoUrl': photoUrl,
      'college': college,
      'course': course,
      'year': year,
      'emergencyContact': emergencyContact,
      if (seatId != null) 'seatId': seatId,
      if (sectionId != null) 'sectionId': sectionId,
      if (planId != null) 'planId': planId,
      if (planStartDate != null) 'planStartDate': planStartDate!.toIso8601String(),
      if (planEndDate != null) 'planEndDate': planEndDate!.toIso8601String(),
      if (graceEndDate != null) 'graceEndDate': graceEndDate!.toIso8601String(),
      'membershipStatus': membershipStatus.name,
      'customFields': customFields,
      if (notes != null) 'notes': notes,
      if (userId != null) 'userId': userId,
      if (idCardUrl != null) 'idCardUrl': idCardUrl,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
      if (membershipNumber != null) 'membershipNumber': membershipNumber,
      if (bloodGroup != null) 'bloodGroup': bloodGroup,
      if (rollNumber != null) 'rollNumber': rollNumber,
      if (blockedReason != null) 'blockedReason': blockedReason,
    };
  }

  StudentModel copyWith({
    String? id,
    String? name,
    String? fatherName,
    String? phone,
    String? email,
    DateTime? dob,
    Gender? gender,
    String? address,
    String? pincode,
    GovIdType? govIdType,
    String? govIdNumber,
    String? govIdImageUrl,
    String? photoUrl,
    String? college,
    String? course,
    String? year,
    String? emergencyContact,
    String? seatId,
    String? sectionId,
    String? planId,
    DateTime? planStartDate,
    DateTime? planEndDate,
    DateTime? graceEndDate,
    MembershipStatus? membershipStatus,
    Map<String, dynamic>? customFields,
    String? notes,
    String? userId,
    String? idCardUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? membershipNumber,
    String? bloodGroup,
    String? rollNumber,
    String? blockedReason,
  }) {
    return StudentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      fatherName: fatherName ?? this.fatherName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      pincode: pincode ?? this.pincode,
      govIdType: govIdType ?? this.govIdType,
      govIdNumber: govIdNumber ?? this.govIdNumber,
      govIdImageUrl: govIdImageUrl ?? this.govIdImageUrl,
      photoUrl: photoUrl ?? this.photoUrl,
      college: college ?? this.college,
      course: course ?? this.course,
      year: year ?? this.year,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      seatId: seatId ?? this.seatId,
      sectionId: sectionId ?? this.sectionId,
      planId: planId ?? this.planId,
      planStartDate: planStartDate ?? this.planStartDate,
      planEndDate: planEndDate ?? this.planEndDate,
      graceEndDate: graceEndDate ?? this.graceEndDate,
      membershipStatus: membershipStatus ?? this.membershipStatus,
      customFields: customFields ?? this.customFields,
      notes: notes ?? this.notes,
      userId: userId ?? this.userId,
      idCardUrl: idCardUrl ?? this.idCardUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      membershipNumber: membershipNumber ?? this.membershipNumber,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      rollNumber: rollNumber ?? this.rollNumber,
      blockedReason: blockedReason ?? this.blockedReason,
    );
  }

  static Gender _parseGender(String? g) {
    switch (g) {
      case 'female':
        return Gender.female;
      case 'other':
        return Gender.other;
      case 'male':
      default:
        return Gender.male;
    }
  }

  static GovIdType _parseGovIdType(String? t) {
    switch (t) {
      case 'pan':
        return GovIdType.pan;
      case 'drivingLicence':
        return GovIdType.drivingLicence;
      case 'collegeId':
        return GovIdType.collegeId;
      case 'aadhaar':
      default:
        return GovIdType.aadhaar;
    }
  }

  static MembershipStatus _parseMembershipStatus(String? s) {
    switch (s) {
      case 'expired':
        return MembershipStatus.expired;
      case 'grace':
        return MembershipStatus.grace;
      case 'pending':
        return MembershipStatus.pending;
      case 'inactive':
        return MembershipStatus.inactive;
      case 'archived':
        return MembershipStatus.archived;
      case 'blocked':
        return MembershipStatus.blocked;
      case 'active':
      default:
        return MembershipStatus.active;
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

  /// Public alias for _parseDate — allows external callers to reuse date parsing logic.
  static DateTime? parseDateStatic(dynamic date) => _parseDate(date);
}
