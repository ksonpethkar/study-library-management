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
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  int get capacity => rows * cols;

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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
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
