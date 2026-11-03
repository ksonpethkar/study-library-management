import 'package:cloud_firestore/cloud_firestore.dart';

enum DurationUnit { days, weeks, months }

class PlanModel {
  final String id;
  final String libraryId;
  final String name;
  final int duration;
  final DurationUnit durationUnit;
  final double price;
  final double? originalPrice; // MRP / Cut price for discount display (e.g. ~~₹2400~~ ₹2000)
  final bool hasSecurityDeposit; // Optional refundable security deposit configured by admin
  final double? securityDepositAmount; // Amount in ₹ (e.g. ₹500 or ₹1000)
  final String description;
  final int gracePeriodDays;
  final bool isActive;
  final bool isFeatured;
  final DateTime? availableFrom;
  final DateTime? availableTo;
  final int displayOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  PlanModel({
    required this.id,
    required this.libraryId,
    required this.name,
    required this.duration,
    required this.durationUnit,
    required this.price,
    this.originalPrice,
    this.hasSecurityDeposit = false,
    this.securityDepositAmount,
    required this.description,
    required this.gracePeriodDays,
    required this.isActive,
    required this.isFeatured,
    this.availableFrom,
    this.availableTo,
    required this.displayOrder,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: json['id'] as String? ?? '',
      libraryId: json['libraryId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      duration: json['duration'] as int? ?? 1,
      durationUnit: _parseDurationUnit(json['durationUnit'] as String?),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (json['originalPrice'] as num?)?.toDouble() ?? (json['cutPrice'] as num?)?.toDouble() ?? (json['mrp'] as num?)?.toDouble(),
      hasSecurityDeposit: json['hasSecurityDeposit'] as bool? ?? (((json['securityDepositAmount'] as num?)?.toDouble() ?? 0.0) > 0),
      securityDepositAmount: (json['securityDepositAmount'] as num?)?.toDouble() ?? (json['securityDeposit'] as num?)?.toDouble(),
      description: json['description'] as String? ?? '',
      gracePeriodDays: json['gracePeriodDays'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      isFeatured: json['isFeatured'] as bool? ?? false,
      availableFrom: _parseDate(json['availableFrom']),
      availableTo: _parseDate(json['availableTo']),
      displayOrder: json['displayOrder'] as int? ?? 0,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      deletedAt: _parseDate(json['deletedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'libraryId': libraryId,
      'name': name,
      'duration': duration,
      'durationUnit': durationUnit.name,
      'price': price,
      if (originalPrice != null) 'originalPrice': originalPrice,
      'hasSecurityDeposit': hasSecurityDeposit,
      if (securityDepositAmount != null) 'securityDepositAmount': securityDepositAmount,
      'description': description,
      'gracePeriodDays': gracePeriodDays,
      'isActive': isActive,
      'isFeatured': isFeatured,
      if (availableFrom != null) 'availableFrom': availableFrom!.toIso8601String(),
      if (availableTo != null) 'availableTo': availableTo!.toIso8601String(),
      'displayOrder': displayOrder,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
    };
  }

  PlanModel copyWith({
    String? id,
    String? libraryId,
    String? name,
    int? duration,
    DurationUnit? durationUnit,
    double? price,
    double? originalPrice,
    bool? hasSecurityDeposit,
    double? securityDepositAmount,
    bool clearSecurityDeposit = false,
    String? description,
    int? gracePeriodDays,
    bool? isActive,
    bool? isFeatured,
    DateTime? availableFrom,
    DateTime? availableTo,
    int? displayOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return PlanModel(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      name: name ?? this.name,
      duration: duration ?? this.duration,
      durationUnit: durationUnit ?? this.durationUnit,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      hasSecurityDeposit: hasSecurityDeposit ?? this.hasSecurityDeposit,
      securityDepositAmount: clearSecurityDeposit
          ? null
          : (securityDepositAmount ?? this.securityDepositAmount),
      description: description ?? this.description,
      gracePeriodDays: gracePeriodDays ?? this.gracePeriodDays,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      availableFrom: availableFrom ?? this.availableFrom,
      availableTo: availableTo ?? this.availableTo,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  /// Total upfront collection required for fresh admission (Plan Price + Refundable Security Deposit)
  double get totalInitialAdmissionFee {
    final deposit = (hasSecurityDeposit && securityDepositAmount != null) ? securityDepositAmount! : 0.0;
    return price + deposit;
  }

  /// Returns a clean display name, automatically normalizing common typos like "Quaterly" -> "Quarterly"
  String get displayName {
    final trimmed = name.trim();
    if (trimmed.toLowerCase() == 'quaterly') {
      return 'Quarterly';
    }
    return trimmed.isNotEmpty ? trimmed : 'Plan';
  }

  /// Returns the effective original (cut) price:
  /// Either the explicitly set originalPrice, or if not set,
  /// calculated from baseMonthlyPrice * duration (if multi-month).
  double? getEffectiveOriginalPrice({double? baseMonthlyPrice}) {
    if (originalPrice != null && originalPrice! > price) {
      return originalPrice;
    }
    if (baseMonthlyPrice != null && baseMonthlyPrice > 0) {
      int months = 1;
      if (durationUnit == DurationUnit.months) {
        months = duration;
      } else if (durationUnit == DurationUnit.weeks) {
        months = (duration / 4).round();
      } else if (durationUnit == DurationUnit.days) {
        months = (duration / 30).round();
      }
      if (months > 1) {
        final regular = baseMonthlyPrice * months;
        if (regular > price) return regular;
      }
    }
    return null;
  }

  /// Calculates discount percentage (e.g. 17 for 17% OFF)
  int? getDiscountPercent({double? baseMonthlyPrice}) {
    final orig = getEffectiveOriginalPrice(baseMonthlyPrice: baseMonthlyPrice);
    if (orig != null && orig > price && orig > 0) {
      return (((orig - price) / orig) * 100).round();
    }
    return null;
  }

  /// Calculates amount saved (e.g. 400 for Save ₹400)
  double? getSavingsAmount({double? baseMonthlyPrice}) {
    final orig = getEffectiveOriginalPrice(baseMonthlyPrice: baseMonthlyPrice);
    if (orig != null && orig > price) {
      return orig - price;
    }
    return null;
  }

  static DurationUnit _parseDurationUnit(String? u) {
    switch (u) {
      case 'weeks':
        return DurationUnit.weeks;
      case 'months':
        return DurationUnit.months;
      case 'days':
      default:
        return DurationUnit.days;
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
