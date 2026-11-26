import 'package:flutter/material.dart';
import '../../models/library_model.dart';
import '../../models/seat_model.dart';
import '../../models/section_model.dart';

/// Canonical definition for a library, section, or desk amenity.
class AmenityItem {
  final String id;
  final String label;
  final String shortLabel;
  final String emoji;
  final IconData icon;
  final String iconKey;
  final String category;
  final List<String> aliases;
  final bool isCustom;
  final bool isEnabled;

  const AmenityItem({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.emoji,
    required this.icon,
    required this.iconKey,
    required this.category,
    this.aliases = const [],
    this.isCustom = false,
    this.isEnabled = true,
  });

  AmenityItem copyWith({
    String? id,
    String? label,
    String? shortLabel,
    String? emoji,
    IconData? icon,
    String? iconKey,
    String? category,
    List<String>? aliases,
    bool? isCustom,
    bool? isEnabled,
  }) {
    return AmenityItem(
      id: id ?? this.id,
      label: label ?? this.label,
      shortLabel: shortLabel ?? this.shortLabel,
      emoji: emoji ?? this.emoji,
      icon: icon ?? this.icon,
      iconKey: iconKey ?? this.iconKey,
      category: category ?? this.category,
      aliases: aliases ?? this.aliases,
      isCustom: isCustom ?? this.isCustom,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'shortLabel': shortLabel,
      'emoji': emoji,
      'icon': iconKey,
      'iconKey': iconKey,
      'category': category,
      'enabled': isEnabled,
      if (isCustom) 'isCustom': true,
    };
  }
}

/// Single canonical source of truth for all library, section, and desk amenities.
///
/// All Admin editors, Student dashboards, Entrance Posters, Fee Receipts,
/// Registration screens, and the Public `/seats` map resolve amenities through
/// this catalog so disabled facilities are never fabricated in UI surfaces.
class AmenityCatalog {
  AmenityCatalog._();

  static const String categoryComfort = 'Comfort & Space';
  static const String categoryTech = 'Tech & Power';
  static const String categorySecurity = 'Security & Access';
  static const String categoryBasics = 'Basics & Wellness';
  static const String categoryOther = 'Other';

  /// Unified 15-item canonical catalog shared across Flutter and `/seats`.
  static const List<AmenityItem> canonicalItems = [
    AmenityItem(
      id: 'wifi',
      label: 'High-Speed Wi-Fi',
      shortLabel: 'Free Wi-Fi',
      emoji: '📶',
      icon: Icons.wifi_rounded,
      iconKey: 'wifi',
      category: categoryTech,
      aliases: [
        'wifi',
        'wi-fi',
        'high-speed wi-fi',
        'high-speed wifi',
        'high-speed 5g wi-fi',
        '5g mesh wi-fi',
        '5g wi-fi',
        'free wi-fi',
        'free wifi',
        'wi-fi zone',
        'wifi zone',
        'unlimited wifi',
        'fiber wifi',
      ],
    ),
    AmenityItem(
      id: 'ac',
      label: 'Air Conditioned Hall',
      shortLabel: 'AC Hall',
      emoji: '❄️',
      icon: Icons.ac_unit_rounded,
      iconKey: 'ac',
      category: categoryComfort,
      aliases: [
        'ac',
        'air conditioned',
        'air conditioned hall',
        'air conditioning',
        'central ac',
        'ac hall',
        'ac study hall',
        'fully ac',
        'ac zone',
      ],
    ),
    AmenityItem(
      id: 'power',
      label: 'Power Sockets at Desk',
      shortLabel: 'Power Socket',
      emoji: '🔌',
      icon: Icons.electrical_services_rounded,
      iconKey: 'power',
      category: categoryTech,
      aliases: [
        'power',
        'power socket',
        'power sockets',
        'power sockets at desk',
        'dedicated power socket',
        'power socket at desk',
        'desk charging socket',
        'charging point',
        'charging port',
        'individual power socket',
        'sockets',
        'plug point',
      ],
    ),
    AmenityItem(
      id: 'desk_lamp',
      label: 'Individual Desk Lamp',
      shortLabel: 'Desk Lamp',
      emoji: '💡',
      icon: Icons.lightbulb_outline_rounded,
      iconKey: 'desk_lamp',
      category: categoryTech,
      aliases: [
        'desk_lamp',
        'desk lamp',
        'individual desk lamp',
        'study lamp',
        'reading lamp',
        'led desk lamp',
        'lamp',
      ],
    ),
    AmenityItem(
      id: 'ro_water',
      label: 'Purified RO Water',
      shortLabel: 'RO Water',
      emoji: '💧',
      icon: Icons.water_drop_rounded,
      iconKey: 'ro_water',
      category: categoryBasics,
      aliases: [
        'ro_water',
        'ro water',
        'purified ro water',
        'chilled ro drinking water',
        'drinking water',
        'chilled water',
        'water cooler',
        'water',
      ],
    ),
    AmenityItem(
      id: 'silence',
      label: 'Silent Study Zone',
      shortLabel: 'Silent Zone',
      emoji: '🤫',
      icon: Icons.volume_off_rounded,
      iconKey: 'silence',
      category: categoryComfort,
      aliases: [
        'silence',
        'silent',
        'silent study zone',
        'silent study',
        'quiet study zone',
        'quiet zone',
        'pin-drop silence',
        'pin-drop silence zone',
        'noise free',
        'noise-free',
      ],
    ),
    AmenityItem(
      id: 'cctv',
      label: '24x7 CCTV Surveillance',
      shortLabel: 'CCTV',
      emoji: '📹',
      icon: Icons.videocam_outlined,
      iconKey: 'cctv',
      category: categorySecurity,
      aliases: [
        'cctv',
        'cctv surveillance',
        '24x7 cctv surveillance',
        '24/7 cctv security',
        '24x7 cctv',
        'cctv security',
        'cctv camera',
        'camera surveillance',
      ],
    ),
    AmenityItem(
      id: 'chairs',
      label: 'Ergonomic Chairs',
      shortLabel: 'Ergonomic Chairs',
      emoji: '🪑',
      icon: Icons.chair_outlined,
      iconKey: 'chairs',
      category: categoryComfort,
      aliases: [
        'chairs',
        'chair',
        'ergonomic chairs',
        'ergonomic study chairs',
        'comfortable chairs',
        'cushioned chairs',
        'seating',
        'spacious desk',
        'spacious cabin',
      ],
    ),
    AmenityItem(
      id: 'locker',
      label: 'Personal Lockers',
      shortLabel: 'Lockers',
      emoji: '🔐',
      icon: Icons.lock_outline_rounded,
      iconKey: 'locker',
      category: categorySecurity,
      aliases: [
        'locker',
        'lockers',
        'personal locker',
        'personal lockers',
        'locker facility',
        'storage locker',
        'book locker',
      ],
    ),
    AmenityItem(
      id: 'power_backup',
      label: '24x7 Power Backup',
      shortLabel: 'Power Backup',
      emoji: '⚡',
      icon: Icons.battery_charging_full_rounded,
      iconKey: 'power_backup',
      category: categoryTech,
      aliases: [
        'power_backup',
        'power backup',
        '24x7 power backup',
        '24/7 power backup',
        'inverter',
        'inverter backup',
        'dg backup',
        'ups backup',
        'generator backup',
        'backup',
      ],
    ),
    AmenityItem(
      id: 'open_24_7',
      label: 'Open 24x7 Access',
      shortLabel: 'Open 24x7',
      emoji: '🕒',
      icon: Icons.access_time_rounded,
      iconKey: 'open_24_7',
      category: categorySecurity,
      aliases: [
        'open_24_7',
        'open 24x7',
        'open 24/7',
        'open 24x7 access',
        '24x7 access',
        '24/7 access',
        '24 hours open',
        '24x7',
      ],
    ),
    AmenityItem(
      id: 'parking',
      label: 'Dedicated Parking',
      shortLabel: 'Parking',
      emoji: '🛵',
      icon: Icons.local_parking_rounded,
      iconKey: 'parking',
      category: categoryBasics,
      aliases: [
        'parking',
        'dedicated parking',
        'two-wheeler parking',
        'two wheeler parking',
        'bike parking',
        'bike & car parking',
        'vehicle parking',
      ],
    ),
    AmenityItem(
      id: 'pantry',
      label: 'Tea / Coffee & Pantry',
      shortLabel: 'Pantry',
      emoji: '☕',
      icon: Icons.local_cafe_outlined,
      iconKey: 'pantry',
      category: categoryBasics,
      aliases: [
        'pantry',
        'tea / coffee',
        'tea / coffee & pantry',
        'tea & coffee',
        'breakout & lunch area',
        'lunch area',
        'cafeteria',
        'canteen',
        'refreshment area',
      ],
    ),
    AmenityItem(
      id: 'newspapers',
      label: 'Newspapers & Magazines',
      shortLabel: 'Newspapers',
      emoji: '📰',
      icon: Icons.newspaper_rounded,
      iconKey: 'newspapers',
      category: categoryBasics,
      aliases: [
        'newspapers',
        'newspaper',
        'newspapers & magazines',
        'daily newspapers',
        'magazines',
        'current affairs',
        'current affairs magazines',
      ],
    ),
    AmenityItem(
      id: 'natural_light',
      label: 'Natural Light & Ventilation',
      shortLabel: 'Natural Light',
      emoji: '☀️',
      icon: Icons.wb_sunny_outlined,
      iconKey: 'natural_light',
      category: categoryComfort,
      aliases: [
        'natural_light',
        'natural light',
        'natural light & ventilation',
        'window view',
        'road facing window',
        'fresh air',
        'ventilation',
        'well ventilated',
      ],
    ),
  ];

  /// Ordered categories for consistent grouping across settings screens.
  static const List<String> categoriesOrder = [
    categoryComfort,
    categoryTech,
    categorySecurity,
    categoryBasics,
    categoryOther,
  ];

  /// Default starter facilities for new libraries (intentionally excludes AC).
  static const List<String> safeDefaultLabels = [
    'High-Speed Wi-Fi',
    'Power Sockets at Desk',
    'Purified RO Water',
    'Silent Study Zone',
    '24x7 CCTV Surveillance',
    'Ergonomic Chairs',
  ];

  /// Looks up a canonical [AmenityItem] by exact ID, alias, label, or keyword.
  static AmenityItem? findItem(String? raw) {
    if (raw == null) return null;
    final clean = raw.trim();
    if (clean.isEmpty) return null;
    final lower = clean.toLowerCase();

    for (final item in canonicalItems) {
      if (item.id == lower ||
          item.label.toLowerCase() == lower ||
          item.shortLabel.toLowerCase() == lower ||
          item.aliases.any((a) => a == lower)) {
        return item;
      }
    }

    // Substring fallback matching (careful to avoid matching "power backup" as "power")
    if (lower.contains('power backup') ||
        lower.contains('inverter') ||
        lower.contains('ups') ||
        lower.contains('generator')) {
      return findById('power_backup');
    }
    if (lower.contains('lamp') || lower.contains('reading light')) {
      return findById('desk_lamp');
    }
    if (lower.contains('wifi') || lower.contains('wi-fi')) {
      return findById('wifi');
    }
    if (lower == 'ac' ||
        lower.contains('air condition') ||
        lower.contains('ac hall') ||
        lower.contains('ac •') ||
        lower.contains('central ac')) {
      return findById('ac');
    }
    if (lower.contains('socket') || lower.contains('charging') || lower.contains('plug')) {
      return findById('power');
    }
    if (lower.contains('water')) return findById('ro_water');
    if (lower.contains('silen') || lower.contains('quiet') || lower.contains('noise')) {
      return findById('silence');
    }
    if (lower.contains('cctv') || lower.contains('surveillance')) return findById('cctv');
    if (lower.contains('chair') || lower.contains('ergonomic')) return findById('chairs');
    if (lower.contains('locker')) return findById('locker');
    if (lower.contains('24x7') || lower.contains('24/7') || lower.contains('24 hour')) {
      return findById('open_24_7');
    }
    if (lower.contains('park')) return findById('parking');
    if (lower.contains('pantry') ||
        lower.contains('tea') ||
        lower.contains('coffee') ||
        lower.contains('lunch') ||
        lower.contains('canteen')) {
      return findById('pantry');
    }
    if (lower.contains('newspaper') || lower.contains('magazine')) {
      return findById('newspapers');
    }
    if (lower.contains('window') ||
        lower.contains('natural light') ||
        lower.contains('ventilat')) {
      return findById('natural_light');
    }
    return null;
  }

  /// Looks up a canonical [AmenityItem] strictly by canonical ID.
  static AmenityItem? findById(String id) {
    final lower = id.trim().toLowerCase();
    for (final item in canonicalItems) {
      if (item.id == lower) return item;
    }
    return null;
  }

  /// Normalizes any label or ID into a canonical ID (or `custom_<slug>`).
  static String normalizeId(String raw) {
    final canonical = findItem(raw);
    if (canonical != null) return canonical.id;
    final slug = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (slug.isEmpty) return 'custom_amenity';
    return slug.startsWith('custom_') ? slug : 'custom_$slug';
  }

  /// Converts a raw string OR structured map into an [AmenityItem].
  static AmenityItem? fromDynamic(dynamic raw, {bool skipDisabled = true}) {
    if (raw == null) return null;
    if (raw is AmenityItem) {
      if (skipDisabled && !raw.isEnabled) return null;
      return raw;
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final enabled = map['enabled'] == null ? true : map['enabled'] == true;
      if (skipDisabled && !enabled) return null;

      final idRaw = map['id']?.toString().trim() ?? '';
      final labelRaw = map['label']?.toString().trim() ?? '';
      final matched = findItem(idRaw.isNotEmpty ? idRaw : labelRaw) ?? findItem(labelRaw);
      if (matched != null) {
        return matched.copyWith(
          label: labelRaw.isNotEmpty ? labelRaw : matched.label,
          emoji: (map['emoji']?.toString().trim().isNotEmpty ?? false)
              ? map['emoji'].toString().trim()
              : matched.emoji,
          isEnabled: enabled,
        );
      }

      final displayLabel = labelRaw.isNotEmpty ? labelRaw : idRaw;
      if (displayLabel.isEmpty) return null;
      return AmenityItem(
        id: idRaw.isNotEmpty ? normalizeId(idRaw) : normalizeId(displayLabel),
        label: displayLabel,
        shortLabel: displayLabel,
        emoji: (map['emoji']?.toString().trim().isNotEmpty ?? false)
            ? map['emoji'].toString().trim()
            : '✨',
        icon: Icons.verified_outlined,
        iconKey: 'custom',
        category: map['category']?.toString() ?? categoryOther,
        isCustom: true,
        isEnabled: enabled,
      );
    }

    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    final matched = findItem(text);
    if (matched != null) return matched;

    return AmenityItem(
      id: normalizeId(text),
      label: text,
      shortLabel: text,
      emoji: '✨',
      icon: Icons.verified_outlined,
      iconKey: 'custom',
      category: categoryOther,
      isCustom: true,
      isEnabled: true,
    );
  }

  /// Parses an ordered, deduplicated list of enabled [AmenityItem]s.
  static List<AmenityItem> parseList(Iterable<dynamic> rawItems, {bool skipDisabled = true}) {
    final result = <AmenityItem>[];
    final seen = <String>{};
    for (final raw in rawItems) {
      final item = fromDynamic(raw, skipDisabled: skipDisabled);
      if (item == null) continue;
      if (seen.add(item.id)) {
        result.add(item);
      }
    }
    return result;
  }

  /// Returns canonical labels from raw IDs/labels/maps while preserving custom labels.
  static List<String> toCanonicalLabels(Iterable<dynamic> rawItems) {
    return parseList(rawItems).map((e) => e.label).toList();
  }

  /// Serializes enabled items (plus any known custom entries) to structured JSON maps.
  static List<Map<String, dynamic>> toStructuredAmenities(Iterable<dynamic> rawItems) {
    return parseList(rawItems, skipDisabled: true).map((e) => e.toJson()).toList();
  }

  /// Resolves the exact Admin-approved amenities for a Library, Section, or Seat.
  ///
  /// Priority & inheritance rules:
  /// 1. Library baseline uses `library.amenities` if provided (honoring `enabled: false`),
  ///    or falls back to `library.facilities` (which honors an explicit empty `[]`).
  /// 2. If `section != null`: starts with Library baseline iff
  ///    `section.inheritLibraryAmenities == true`, then merges `section.amenities`.
  /// 3. If `seat != null`: merges per-seat `seat.amenities`.
  /// 4. Never fabricates unconfigured items (e.g. never invents AC or Desk Lamp).
  static List<AmenityItem> resolveEffectiveAmenities({
    LibraryModel? library,
    SectionModel? section,
    SeatModel? seat,
  }) {
    final merged = <AmenityItem>[];
    final seenIds = <String>{};

    void addAllUnique(Iterable<AmenityItem> items) {
      for (final item in items) {
        if (!item.isEnabled) continue;
        if (seenIds.add(item.id)) {
          merged.add(item);
        }
      }
    }

    final includeLibrary =
        library != null && (section == null || section.inheritLibraryAmenities);

    if (includeLibrary) {
      if (library.amenities.isNotEmpty) {
        addAllUnique(parseList(library.amenities, skipDisabled: true));
      } else {
        addAllUnique(parseList(library.facilities, skipDisabled: true));
      }
    }

    if (section != null && section.amenities.isNotEmpty) {
      addAllUnique(parseList(section.amenities, skipDisabled: true));
    }

    if (seat != null && seat.amenities.isNotEmpty) {
      addAllUnique(parseList(seat.amenities, skipDisabled: true));
    }

    return merged;
  }

  /// Checks whether an amenity ID (or alias) is enabled in [items].
  static bool hasAmenityId(Iterable<dynamic> items, String targetId) {
    final target = findById(targetId)?.id ?? normalizeId(targetId);
    return parseList(items, skipDisabled: true).any((e) => e.id == target);
  }
}
