import 'package:cloud_firestore/cloud_firestore.dart';

enum Gender { male, female, other }
enum GovIdType {
  aadhaar,
  pan,
  drivingLicence,
  voterId,
  passport,
  collegeId,
  other,
}

extension GovIdTypeExtension on GovIdType {
  String get displayName {
    switch (this) {
      case GovIdType.aadhaar:
        return 'Aadhaar Card';
      case GovIdType.pan:
        return 'PAN Card';
      case GovIdType.drivingLicence:
        return 'Driving Licence';
      case GovIdType.voterId:
        return 'Voter ID (EPIC)';
      case GovIdType.passport:
        return 'Passport';
      case GovIdType.collegeId:
        return 'College / Student ID';
      case GovIdType.other:
        return 'Other Govt. Photo ID';
    }
  }

  String get shortCode {
    switch (this) {
      case GovIdType.aadhaar:
        return 'AADHAAR';
      case GovIdType.pan:
        return 'PAN';
      case GovIdType.drivingLicence:
        return 'DL';
      case GovIdType.voterId:
        return 'VOTER ID';
      case GovIdType.passport:
        return 'PASSPORT';
      case GovIdType.collegeId:
        return 'COLLEGE ID';
      case GovIdType.other:
        return 'GOV ID';
    }
  }

  String get placeholder {
    switch (this) {
      case GovIdType.aadhaar:
        return 'XXXX XXXX 1234 (12 digits)';
      case GovIdType.pan:
        return 'ABCDE1234F (10 chars)';
      case GovIdType.drivingLicence:
        return 'MH12 20210001234';
      case GovIdType.voterId:
        return 'ABC1234567 (10 chars)';
      case GovIdType.passport:
        return 'A1234567 (8 chars)';
      case GovIdType.collegeId:
        return 'Roll No / Enrollment No';
      case GovIdType.other:
        return 'Govt ID Document Number';
    }
  }

  String get helperText {
    switch (this) {
      case GovIdType.aadhaar:
        return '12-digit UIDAI number (e.g. 1234 5678 9012)';
      case GovIdType.pan:
        return '10-character alphanumeric (e.g. ABCDE1234F)';
      case GovIdType.drivingLicence:
        return '15-16 character state RTO number';
      case GovIdType.voterId:
        return '10-character EPIC number (3 letters + 7 digits)';
      case GovIdType.passport:
        return '8-character passport number (1 letter + 7 digits)';
      case GovIdType.collegeId:
        return 'Student roll number or college registration number';
      case GovIdType.other:
        return 'Official government issued identity card number';
    }
  }

  bool get requiresTwoSides {
    return this == GovIdType.aadhaar ||
        this == GovIdType.drivingLicence ||
        this == GovIdType.passport ||
        this == GovIdType.voterId;
  }
}
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
  final String? govIdBackImageUrl;
  final String photoUrl;
  final String college;
  final String course;
  final String year;
  final String emergencyContact;
  final String? seatId;
  final String? sectionId;
  final String? previousSeatId;
  final String? previousSectionId;
  final String? planId;
  final String? customPlanName;
  final double? customPlanFee;
  final bool isStickyCustomPrice;
  final String? customDiscountReason;
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
  final double? pendingDueBalance;
  final bool pinResetByAdmin;
  final double? securityDepositAmount; // Optional refundable deposit held
  final bool isDepositRefunded;
  final DateTime? depositRefundedAt;

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
    this.govIdBackImageUrl,
    required this.photoUrl,
    required this.college,
    required this.course,
    required this.year,
    required this.emergencyContact,
    this.seatId,
    this.sectionId,
    this.previousSeatId,
    this.previousSectionId,
    this.planId,
    this.customPlanName,
    this.customPlanFee,
    this.isStickyCustomPrice = false,
    this.customDiscountReason,
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
    this.pendingDueBalance,
    this.pinResetByAdmin = false,
    this.securityDepositAmount,
    this.isDepositRefunded = false,
    this.depositRefundedAt,
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
      govIdImageUrl: (json['govIdImageUrl'] ??
              json['govIdDataUrl'] ??
              json['govIdImagePath'] ??
              json['govIdFrontUrl'] ??
              json['govIdFrontDataUrl'] ??
              json['idProofUrl'] ??
              json['documentUrl'] ??
              json['idProof'] ??
              json['govIdUrl'] ??
              json['idCardFrontUrl'] ??
              json['panCardUrl'] ??
              json['aadhaarUrl'] ??
              json['idCardUrl']) as String? ??
          '',
      govIdBackImageUrl: (json['govIdBackImageUrl'] ??
              json['govIdBackDataUrl'] ??
              json['govIdBackImagePath'] ??
              json['govIdBackUrl'] ??
              json['idProofBackUrl'] ??
              json['documentBackUrl'] ??
              json['idCardBackUrl'] ??
              json['aadhaarBackUrl']) as String?,
      photoUrl: json['photoUrl'] as String? ?? '',
      college: json['college'] as String? ?? '',
      course: json['course'] as String? ?? '',
      year: json['year'] as String? ?? '',
      emergencyContact: json['emergencyContact'] as String? ?? '',
      seatId: json['seatId'] as String?,
      sectionId: json['sectionId'] as String?,
      previousSeatId: json['previousSeatId'] as String?,
      previousSectionId: json['previousSectionId'] as String?,
      planId: json['planId'] as String?,
      customPlanName: json['customPlanName'] as String?,
      customPlanFee: (json['customPlanFee'] as num?)?.toDouble() ?? (json['customFee'] as num?)?.toDouble(),
      isStickyCustomPrice: json['isStickyCustomPrice'] == true,
      customDiscountReason: json['customDiscountReason'] as String?,
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
      pendingDueBalance: (json['pendingDueBalance'] as num?)?.toDouble(),
      pinResetByAdmin: json['pinResetByAdmin'] == true,
      securityDepositAmount: (json['securityDepositAmount'] as num?)?.toDouble() ?? (json['securityDeposit'] as num?)?.toDouble(),
      isDepositRefunded: json['isDepositRefunded'] == true,
      depositRefundedAt: _parseDate(json['depositRefundedAt']),
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
      if (govIdBackImageUrl != null) 'govIdBackImageUrl': govIdBackImageUrl,
      'photoUrl': photoUrl,
      'college': college,
      'course': course,
      'year': year,
      'emergencyContact': emergencyContact,
      if (seatId != null) 'seatId': seatId,
      if (sectionId != null) 'sectionId': sectionId,
      if (previousSeatId != null) 'previousSeatId': previousSeatId,
      if (previousSectionId != null) 'previousSectionId': previousSectionId,
      if (planId != null) 'planId': planId,
      if (customPlanName != null) 'customPlanName': customPlanName,
      if (customPlanFee != null) 'customPlanFee': customPlanFee,
      if (isStickyCustomPrice) 'isStickyCustomPrice': true,
      if (customDiscountReason != null) 'customDiscountReason': customDiscountReason,
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
      if (pendingDueBalance != null) 'pendingDueBalance': pendingDueBalance,
      if (pinResetByAdmin) 'pinResetByAdmin': true,
      if (securityDepositAmount != null) 'securityDepositAmount': securityDepositAmount,
      if (isDepositRefunded) 'isDepositRefunded': true,
      if (depositRefundedAt != null) 'depositRefundedAt': depositRefundedAt!.toIso8601String(),
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
    String? govIdBackImageUrl,
    String? photoUrl,
    String? college,
    String? course,
    String? year,
    String? emergencyContact,
    String? seatId,
    String? sectionId,
    String? previousSeatId,
    String? previousSectionId,
    String? planId,
    String? customPlanName,
    double? customPlanFee,
    bool? isStickyCustomPrice,
    String? customDiscountReason,
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
    double? pendingDueBalance,
    bool? pinResetByAdmin,
    double? securityDepositAmount,
    bool? isDepositRefunded,
    DateTime? depositRefundedAt,
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
      govIdBackImageUrl: govIdBackImageUrl ?? this.govIdBackImageUrl,
      photoUrl: photoUrl ?? this.photoUrl,
      college: college ?? this.college,
      course: course ?? this.course,
      year: year ?? this.year,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      seatId: seatId ?? this.seatId,
      sectionId: sectionId ?? this.sectionId,
      previousSeatId: previousSeatId ?? this.previousSeatId,
      previousSectionId: previousSectionId ?? this.previousSectionId,
      planId: planId ?? this.planId,
      customPlanName: customPlanName ?? this.customPlanName,
      customPlanFee: customPlanFee ?? this.customPlanFee,
      isStickyCustomPrice: isStickyCustomPrice ?? this.isStickyCustomPrice,
      customDiscountReason: customDiscountReason ?? this.customDiscountReason,
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
      pendingDueBalance: pendingDueBalance ?? this.pendingDueBalance,
      pinResetByAdmin: pinResetByAdmin ?? this.pinResetByAdmin,
      securityDepositAmount: securityDepositAmount ?? this.securityDepositAmount,
      isDepositRefunded: isDepositRefunded ?? this.isDepositRefunded,
      depositRefundedAt: depositRefundedAt ?? this.depositRefundedAt,
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
    switch (t?.toLowerCase()) {
      case 'pan':
        return GovIdType.pan;
      case 'drivinglicence':
      case 'drivinglicense':
      case 'dl':
        return GovIdType.drivingLicence;
      case 'voterid':
      case 'voter':
      case 'epic':
        return GovIdType.voterId;
      case 'passport':
        return GovIdType.passport;
      case 'collegeid':
      case 'college':
      case 'studentid':
        return GovIdType.collegeId;
      case 'other':
        return GovIdType.other;
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
    if (date is Timestamp) return date.toDate();
    if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
    if (date is String) return DateTime.tryParse(date);
    try {
      final dynamic d = date;
      final res = d.toDate();
      if (res is DateTime) return res;
    } catch (_) { /* intentionally silent */ }
    return null;
  }

  /// Public alias for _parseDate — allows external callers to reuse date parsing logic.
  static DateTime? parseDateStatic(dynamic date) => _parseDate(date);

  /// Real-time dynamic evaluation of student membership status.
  /// Re-evaluates based on current wall-clock time and planEndDate even if
  /// the stored Firestore string has not been updated yet.
  MembershipStatus get effectiveMembershipStatus {
    if (membershipStatus == MembershipStatus.blocked) return MembershipStatus.blocked;
    if (membershipStatus == MembershipStatus.pending) return MembershipStatus.pending;
    if (membershipStatus == MembershipStatus.inactive || membershipStatus == MembershipStatus.archived) {
      return membershipStatus;
    }
    final now = DateTime.now();
    if (planEndDate != null) {
      final planEndInclusive = DateTime(
        planEndDate!.year,
        planEndDate!.month,
        planEndDate!.day,
        23, 59, 59, 999,
      );
      if (now.isAfter(planEndInclusive)) {
        if (graceEndDate != null) {
          final graceEndInclusive = DateTime(
            graceEndDate!.year,
            graceEndDate!.month,
            graceEndDate!.day,
            23, 59, 59, 999,
          );
          if (now.isBefore(graceEndInclusive) || now.isAtSameMomentAs(graceEndInclusive)) {
            return MembershipStatus.grace;
          }
        } else if (membershipStatus == MembershipStatus.grace) {
          return MembershipStatus.grace;
        }
        return MembershipStatus.expired;
      }
    }
    if (membershipStatus == MembershipStatus.grace) {
      return MembershipStatus.grace;
    }
    return MembershipStatus.active;
  }

  /// Dynamic evaluation: student is genuinely active ONLY if:
  /// 1. Status is marked active or grace
  /// 2. Plan end date is in the future (or within grace period)
  bool get isEffectivelyActive {
    if (membershipStatus != MembershipStatus.active &&
        membershipStatus != MembershipStatus.grace) {
      return false;
    }
    if (planEndDate == null) return false;
    final now = DateTime.now();
    final planEndInclusive = DateTime(
      planEndDate!.year,
      planEndDate!.month,
      planEndDate!.day,
      23, 59, 59, 999,
    );
    if (now.isBefore(planEndInclusive) || now.isAtSameMomentAs(planEndInclusive)) {
      return true;
    }
    if (graceEndDate != null) {
      final graceEndInclusive = DateTime(
        graceEndDate!.year,
        graceEndDate!.month,
        graceEndDate!.day,
        23, 59, 59, 999,
      );
      if (now.isBefore(graceEndInclusive) || now.isAtSameMomentAs(graceEndInclusive)) {
        return true;
      }
    } else if (membershipStatus == MembershipStatus.grace) {
      return true;
    }
    return false;
  }

  /// True if the student's plan has expired based on current time and grace period
  bool get isExpired {
    if (membershipStatus == MembershipStatus.expired) return true;
    if (planEndDate == null) return false;
    final now = DateTime.now();
    if (graceEndDate != null) {
      final graceEndInclusive = DateTime(
        graceEndDate!.year,
        graceEndDate!.month,
        graceEndDate!.day,
        23, 59, 59, 999,
      );
      if (now.isBefore(graceEndInclusive) || now.isAtSameMomentAs(graceEndInclusive)) {
        return false;
      }
    } else if (membershipStatus == MembershipStatus.grace) {
      return false;
    }
    final planEndInclusive = DateTime(
      planEndDate!.year,
      planEndDate!.month,
      planEndDate!.day,
      23, 59, 59, 999,
    );
    return now.isAfter(planEndInclusive);
  }

  /// Days remaining until plan expires (negative if already expired)
  int? get daysRemaining {
    if (planEndDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(planEndDate!.year, planEndDate!.month, planEndDate!.day);
    return end.difference(today).inDays;
  }
}
