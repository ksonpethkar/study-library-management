import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:study_library/core/constants/amenity_catalog.dart';
import 'package:study_library/models/library_model.dart';

class PosterLayoutConfig {
  final bool showTagline;
  final bool showHours;
  final bool showUrgency;
  final String urgencyText;
  final bool showLiveSeatCount;
  final bool showHowToSteps;
  final String qrSizeMode; // 'standard' | 'large'
  final int maxAmenities;

  const PosterLayoutConfig({
    this.showTagline = true,
    this.showHours = true,
    this.showUrgency = true,
    this.urgencyText = 'Hurry! Limited Seats Left',
    this.showLiveSeatCount = true,
    this.showHowToSteps = true,
    this.qrSizeMode = 'large',
    this.maxAmenities = 9,
  });

  factory PosterLayoutConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PosterLayoutConfig();
    final rawUrgency = (json['urgencyText'] ?? '').toString().trim();
    final rawMode = (json['qrSizeMode'] ?? 'large').toString().trim().toLowerCase();
    final rawMax = json['maxAmenities'];
    final parsedMax = rawMax is int
        ? rawMax.clamp(3, 9)
        : (int.tryParse(rawMax?.toString() ?? '')?.clamp(3, 9) ?? 9);
    return PosterLayoutConfig(
      showTagline: json['showTagline'] != false,
      showHours: json['showHours'] != false,
      showUrgency: json['showUrgency'] != false,
      urgencyText: rawUrgency.isNotEmpty ? rawUrgency : 'Hurry! Limited Seats Left',
      showLiveSeatCount: json['showLiveSeatCount'] != false,
      showHowToSteps: json['showHowToSteps'] != false,
      qrSizeMode: rawMode == 'standard' ? 'standard' : 'large',
      maxAmenities: parsedMax,
    );
  }

  Map<String, dynamic> toJson() => {
        'showTagline': showTagline,
        'showHours': showHours,
        'showUrgency': showUrgency,
        'urgencyText': urgencyText.trim().isNotEmpty ? urgencyText.trim() : 'Hurry! Limited Seats Left',
        'showLiveSeatCount': showLiveSeatCount,
        'showHowToSteps': showHowToSteps,
        'qrSizeMode': qrSizeMode,
        'maxAmenities': maxAmenities,
      };

  PosterLayoutConfig copyWith({
    bool? showTagline,
    bool? showHours,
    bool? showUrgency,
    String? urgencyText,
    bool? showLiveSeatCount,
    bool? showHowToSteps,
    String? qrSizeMode,
    int? maxAmenities,
  }) {
    return PosterLayoutConfig(
      showTagline: showTagline ?? this.showTagline,
      showHours: showHours ?? this.showHours,
      showUrgency: showUrgency ?? this.showUrgency,
      urgencyText: urgencyText ?? this.urgencyText,
      showLiveSeatCount: showLiveSeatCount ?? this.showLiveSeatCount,
      showHowToSteps: showHowToSteps ?? this.showHowToSteps,
      qrSizeMode: qrSizeMode ?? this.qrSizeMode,
      maxAmenities: maxAmenities ?? this.maxAmenities,
    );
  }

  /// Avoids repeating `"Welcome To <Library Name>"` right under the WELCOME TO pill.
  static String resolveTagline(String rawTagline, String libName) {
    final trimmed = rawTagline.trim();
    if (trimmed.isEmpty) return 'Smart Study Center & Silent Reading Hall';
    final lower = trimmed.toLowerCase();
    final nameLower = libName.trim().toLowerCase();
    if (lower.startsWith('welcome to') || (nameLower.isNotEmpty && lower == nameLower)) {
      return 'Smart Study Center & Silent Reading Hall';
    }
    return trimmed;
  }

  /// Picks 1, 2, or 3 columns dynamically based on amenity count so rows look balanced.
  static int resolveAmenityColumns(int count) {
    if (count <= 1) return 1;
    if (count == 2 || count == 4) return 2;
    return 3;
  }
}

class PosterConfigService {
  static List<Map<String, dynamic>> get defaultAmenities =>
      AmenityCatalog.toStructuredAmenities(AmenityCatalog.safeDefaultLabels);

  static Stream<PosterLayoutConfig> streamPosterConfig(String libraryId) {
    if (libraryId.isEmpty) return Stream.value(const PosterLayoutConfig());
    return FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .collection('settings')
        .doc('poster')
        .snapshots()
        .map((snap) => PosterLayoutConfig.fromJson(snap.data()));
  }

  static Future<PosterLayoutConfig> fetchPosterConfig(String libraryId) async {
    if (libraryId.isEmpty) return const PosterLayoutConfig();
    try {
      final snap = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('poster')
          .get();
      if (snap.exists) {
        return PosterLayoutConfig.fromJson(snap.data());
      }
    } catch (_) {
      /* intentionally silent */
    }
    return const PosterLayoutConfig();
  }

  static List<Map<String, dynamic>> _extractLibraryAmenities(
    String libraryId,
    Map<String, dynamic>? libData,
  ) {
    if (libData == null) return defaultAmenities;
    final lib = LibraryModel.fromJson({...libData, 'id': libraryId});
    return AmenityCatalog.resolveEffectiveAmenities(library: lib)
        .map((e) => e.toJson())
        .toList();
  }

  static Stream<List<Map<String, dynamic>>> streamAmenities(String libraryId) {
    if (libraryId.isEmpty) return Stream.value(defaultAmenities);
    return FirebaseFirestore.instance
        .collection('libraries')
        .doc(libraryId)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return defaultAmenities;
      return _extractLibraryAmenities(libraryId, snap.data());
    });
  }

  static Future<List<Map<String, dynamic>>> fetchAmenities(String libraryId) async {
    if (libraryId.isEmpty) return defaultAmenities;
    try {
      final libSnap = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .get();
      if (libSnap.exists && libSnap.data() != null) {
        return _extractLibraryAmenities(libraryId, libSnap.data());
      }
      final posterSnap = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('settings')
          .doc('poster')
          .get();
      if (posterSnap.exists && posterSnap.data() != null) {
        final raw = posterSnap.data()!['amenities'] as List<dynamic>?;
        if (raw != null) {
          return AmenityCatalog.parseList(raw, skipDisabled: true)
              .map((e) => e.toJson())
              .toList();
        }
      }
    } catch (_) { /* intentionally silent */ }
    return defaultAmenities;
  }

  static Future<void> saveAmenities(String libraryId, List<Map<String, dynamic>> amenities) async {
    await savePosterSettings(libraryId, amenities: amenities);
  }

  static Future<void> savePosterSettings(
    String libraryId, {
    required List<Map<String, dynamic>> amenities,
    PosterLayoutConfig? config,
  }) async {
    if (libraryId.isEmpty) return;
    final activeItems = AmenityCatalog.parseList(amenities, skipDisabled: true);
    final structuredActive = activeItems.map((e) => e.toJson()).toList();
    final canonicalLabels = activeItems.map((e) => e.label).toList();

    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final libRef = db.collection('libraries').doc(libraryId);
    final posterRef = libRef.collection('settings').doc('poster');

    batch.set(libRef, {
      'facilities': canonicalLabels,
      'amenities': structuredActive,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(posterRef, {
      'amenities': structuredActive,
      if (config != null) ...config.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// Opens the Poster & Amenity Badges Customizer Sheet for Admins.
  static Future<void> showCustomizer(BuildContext context, String libraryId) async {
    if (libraryId.isEmpty) return;
    final results = await Future.wait([
      fetchAmenities(libraryId),
      fetchPosterConfig(libraryId),
    ]);
    final active = results[0] as List<Map<String, dynamic>>;
    final config = results[1] as PosterLayoutConfig;
    final activeIds = active.map((a) => AmenityCatalog.normalizeId(a['id']?.toString() ?? a['label']?.toString() ?? '')).toSet();

    final merged = <Map<String, dynamic>>[
      ...active.map((m) => {...m, 'enabled': true}),
      for (final item in AmenityCatalog.canonicalItems)
        if (!activeIds.contains(item.id))
          {...item.toJson(), 'enabled': false},
    ];
    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AmenityCustomizerSheet(
        libraryId: libraryId,
        initialAmenities: merged,
        initialConfig: config,
      ),
    );
  }
}

class _AmenityCustomizerSheet extends StatefulWidget {
  final String libraryId;
  final List<Map<String, dynamic>> initialAmenities;
  final PosterLayoutConfig initialConfig;

  const _AmenityCustomizerSheet({
    required this.libraryId,
    required this.initialAmenities,
    required this.initialConfig,
  });

  @override
  State<_AmenityCustomizerSheet> createState() => _AmenityCustomizerSheetState();
}

class _AmenityCustomizerSheetState extends State<_AmenityCustomizerSheet> {
  late List<Map<String, dynamic>> _amenities;
  late PosterLayoutConfig _config;
  late TextEditingController _urgencyCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amenities = List<Map<String, dynamic>>.from(
      widget.initialAmenities.map((m) => Map<String, dynamic>.from(m)),
    );
    _config = widget.initialConfig;
    _urgencyCtrl = TextEditingController(text: _config.urgencyText);
  }

  @override
  void dispose() {
    _urgencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final updatedConfig = _config.copyWith(
        urgencyText: _urgencyCtrl.text.trim().isNotEmpty
            ? _urgencyCtrl.text.trim()
            : 'Hurry! Limited Seats Left',
      );
      await PosterConfigService.savePosterSettings(
        widget.libraryId,
        amenities: _amenities,
        config: updatedConfig,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Poster layout & amenity badges updated!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save poster settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addCustomAmenity() {
    final titleCtrl = TextEditingController();
    final iconCtrl = TextEditingController(text: '✨');

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Add Custom Amenity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: iconCtrl,
              decoration: const InputDecoration(
                labelText: 'Icon / Emoji',
                hintText: 'e.g. 🔒, ☕, 🪑, 📹',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Amenity Title',
                hintText: 'e.g. Personal Locker, Discussion Room',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final title = titleCtrl.text.trim();
              if (title.isNotEmpty) {
                setState(() {
                  _amenities.add({
                    'id': 'amenity_${DateTime.now().millisecondsSinceEpoch}',
                    'label': title,
                    'icon': iconCtrl.text.trim().isNotEmpty ? iconCtrl.text.trim() : '✨',
                    'enabled': true,
                  });
                });
                Navigator.pop(dCtx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Switch(
            value: value,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1.0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customize Standee & Poster',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Live preview & A4 PDF adjust automatically',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                const Text(
                  'Poster Sections & Layout',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                _buildToggleTile(
                  'Show Live Seat Availability Pill',
                  _config.showLiveSeatCount,
                  (v) => setState(() => _config = _config.copyWith(showLiveSeatCount: v)),
                ),
                _buildToggleTile(
                  'Show 3-Step Scan Guide',
                  _config.showHowToSteps,
                  (v) => setState(() => _config = _config.copyWith(showHowToSteps: v)),
                ),
                _buildToggleTile(
                  'Show Operating Hours Badge',
                  _config.showHours,
                  (v) => setState(() => _config = _config.copyWith(showHours: v)),
                ),
                _buildToggleTile(
                  'Show Tagline Subtitle',
                  _config.showTagline,
                  (v) => setState(() => _config = _config.copyWith(showTagline: v)),
                ),
                _buildToggleTile(
                  'Show Urgency Callout',
                  _config.showUrgency,
                  (v) => setState(() => _config = _config.copyWith(showUrgency: v)),
                ),
                if (_config.showUrgency) ...[
                  const SizedBox(height: 6),
                  TextField(
                    controller: _urgencyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Urgency Banner Text',
                      hintText: 'e.g. Hurry! Limited Seats Left',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'QR Code Size',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'standard', label: Text('Standard')),
                        ButtonSegment(value: 'large', label: Text('Large')),
                      ],
                      selected: {_config.qrSizeMode},
                      onSelectionChanged: (sel) {
                        setState(() => _config = _config.copyWith(qrSizeMode: sel.first));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 10),
                const Text(
                  'Visual Amenity Badges (Up to 9)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _amenities.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = _amenities[index];
                      final enabled = item['enabled'] == true;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: enabled ? Colors.indigo.shade200 : Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Text(item['icon']?.toString() ?? '✨', style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item['label']?.toString() ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: enabled ? Colors.black87 : Colors.grey,
                                  decoration: enabled ? null : TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                            Switch(
                              value: enabled,
                              onChanged: (val) {
                                setState(() {
                                  item['enabled'] = val;
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _amenities.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _addCustomAmenity,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Custom'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save & Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
