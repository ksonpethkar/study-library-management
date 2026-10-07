enum DurationUnit { days, weeks, months }

class PlanModel {
  final String id;
  final String libraryId;
  final String name;
  final int duration;
  final DurationUnit durationUnit;
  final double price;
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
