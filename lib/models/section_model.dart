import 'package:cloud_firestore/cloud_firestore.dart';

class SectionModel {
  final String id;
  final String libraryId;
  final String name;
  final int rows;
  final int cols;
  final int color;
  final int order;
  final bool isActive;
  final String? notes;
  final String sectionType; // 'normal', 'window', 'ac', 'premium'
  final String? genderRestriction; // 'any', 'male', 'female'
  final String? floor; // e.g. 'Ground Floor', '1st Floor'
  final List<String> amenities; // ['ac', 'power', 'wifi']
  final bool inheritLibraryAmenities;
  final int? totalSeats;
  final double priceModifier;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  SectionModel({
    required this.id,
    required this.libraryId,
    required this.name,
    required this.rows,
    required this.cols,
    required this.color,
    required this.order,
    required this.isActive,
    this.notes,
    this.sectionType = 'normal',
    this.genderRestriction = 'any',
    this.floor,
    this.amenities = const [],
    this.inheritLibraryAmenities = true,
    this.totalSeats,
    this.priceModifier = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  int get capacity => (totalSeats != null && totalSeats! > 0) ? totalSeats! : (rows * cols);

  factory SectionModel.fromJson(Map<String, dynamic> json) {
    return SectionModel(
      id: json['id'] as String? ?? '',
      libraryId: json['libraryId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      rows: json['rows'] as int? ?? 1,
      cols: json['cols'] as int? ?? 1,
      color: json['color'] as int? ?? 0xFF5D4037,
      order: json['order'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      notes: json['notes'] as String?,
      sectionType: json['sectionType'] as String? ?? 'normal',
      genderRestriction: json['genderRestriction'] as String? ?? 'any',
      floor: json['floor'] as String?,
      amenities: json['amenities'] is List
          ? (json['amenities'] as List).map((e) => e.toString()).toList()
          : const [],
      inheritLibraryAmenities: json['inheritLibraryAmenities'] as bool? ?? true,
      totalSeats: json['totalSeats'] as int? ?? json['seatCount'] as int? ?? json['capacity'] as int?,
      priceModifier: (json['priceModifier'] as num?)?.toDouble() ?? 0.0,
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updatedAt']) ?? DateTime.now(),
      deletedAt: _parseDate(json['deletedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'libraryId': libraryId,
      'name': name,
      'rows': rows,
      'cols': cols,
      'color': color,
      'order': order,
      'isActive': isActive,
      'notes': notes,
      'sectionType': sectionType,
      'genderRestriction': genderRestriction,
      if (floor != null) 'floor': floor,
      'amenities': amenities,
      'inheritLibraryAmenities': inheritLibraryAmenities,
      if (totalSeats != null) 'totalSeats': totalSeats,
      if (priceModifier != 0) 'priceModifier': priceModifier,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
    };
  }

  SectionModel copyWith({
    String? id,
    String? libraryId,
    String? name,
    int? rows,
    int? cols,
    int? color,
    int? order,
    bool? isActive,
    String? notes,
    String? sectionType,
    String? genderRestriction,
    String? floor,
    List<String>? amenities,
    bool? inheritLibraryAmenities,
    int? totalSeats,
    double? priceModifier,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return SectionModel(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      name: name ?? this.name,
      rows: rows ?? this.rows,
      cols: cols ?? this.cols,
      color: color ?? this.color,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      sectionType: sectionType ?? this.sectionType,
      genderRestriction: genderRestriction ?? this.genderRestriction,
      floor: floor ?? this.floor,
      amenities: amenities ?? this.amenities,
      inheritLibraryAmenities: inheritLibraryAmenities ?? this.inheritLibraryAmenities,
      totalSeats: totalSeats ?? this.totalSeats,
      priceModifier: priceModifier ?? this.priceModifier,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
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
