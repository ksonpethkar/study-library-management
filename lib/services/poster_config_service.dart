import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:study_library/core/constants/amenity_catalog.dart';
import 'package:study_library/models/library_model.dart';

class PosterConfigService {
  static List<Map<String, dynamic>> get defaultAmenities =>
      AmenityCatalog.toStructuredAmenities(AmenityCatalog.safeDefaultLabels);

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
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// Opens the Amenity Badges Customizer Sheet for Admins using the canonical catalog.
  static Future<void> showCustomizer(BuildContext context, String libraryId) async {
    if (libraryId.isEmpty) return;
    final active = await fetchAmenities(libraryId);
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
      builder: (ctx) => _AmenityCustomizerSheet(libraryId: libraryId, initialAmenities: merged),
    );
  }
}

class _AmenityCustomizerSheet extends StatefulWidget {
  final String libraryId;
  final List<Map<String, dynamic>> initialAmenities;

  const _AmenityCustomizerSheet({
    required this.libraryId,
    required this.initialAmenities,
  });

  @override
  State<_AmenityCustomizerSheet> createState() => _AmenityCustomizerSheetState();
}

class _AmenityCustomizerSheetState extends State<_AmenityCustomizerSheet> {
  late List<Map<String, dynamic>> _amenities;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amenities = List<Map<String, dynamic>>.from(
      widget.initialAmenities.map((m) => Map<String, dynamic>.from(m)),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await PosterConfigService.saveAmenities(widget.libraryId, _amenities);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Amenity badges updated successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save amenities: $e')),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Visual Amenity Badges', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Manage badges on Entrance Poster & Seat Map', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _amenities.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final item = _amenities[index];
                final enabled = item['enabled'] == true;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save & Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
