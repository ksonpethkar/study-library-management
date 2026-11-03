import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/core/utils/app_validators.dart';

import '../providers/seat_providers.dart';

import 'package:study_library/models/section_model.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/core/providers/library_provider.dart';

class AddSectionScreen extends ConsumerStatefulWidget {
  final String libraryId;
  final SectionModel? section; // if null, creating new

  const AddSectionScreen({super.key, required this.libraryId, this.section});

  @override
  ConsumerState<AddSectionScreen> createState() => _AddSectionScreenState();
}

class _AddSectionScreenState extends ConsumerState<AddSectionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  final _addSeatsController = TextEditingController(text: '0');

  // Seat numbering fields
  SeatNamingStyle _namingStyle = SeatNamingStyle.numeric;
  final _startNumberController = TextEditingController(text: '1');
  final _endNumberController = TextEditingController(text: '50');
  final _customPrefixController = TextEditingController(text: 'CAB');
  final _rowsController = TextEditingController(text: '5');
  final _colsController = TextEditingController(text: '10');

  // Gender restriction
  GenderRestriction _genderRestriction = GenderRestriction.any;

  int _selectedColor = 0xFF3498DB;
  String _sectionType = 'normal';
  String _floor = 'Ground Floor';
  List<String> _selectedAmenities = [];
  bool _isLoading = false;

  final List<Map<String, dynamic>> _colorOptions = [
    {'hex': 0xFF3498DB, 'name': 'Blue'},
    {'hex': 0xFFE74C3C, 'name': 'Red'},
    {'hex': 0xFF2ECC71, 'name': 'Green'},
    {'hex': 0xFFF1C40F, 'name': 'Yellow'},
    {'hex': 0xFF9B59B6, 'name': 'Purple'},
    {'hex': 0xFFE67E22, 'name': 'Orange'},
    {'hex': 0xFF34495E, 'name': 'Dark'},
    {'hex': 0xFF1ABC9C, 'name': 'Teal'},
  ];

  static const List<String> _floorOptions = [
    'Ground Floor',
    '1st Floor',
    '2nd Floor',
    '3rd Floor',
    'Basement',
    'Cabin Area',
    'Terrace Wing',
  ];

  static const List<Map<String, String>> _availableAmenities = [
    {'id': 'AC', 'label': 'AC Zone ❄️'},
    {'id': 'Power Sockets', 'label': 'Power Sockets 🔌'},
    {'id': 'Ergonomic Chairs', 'label': 'Ergonomic Chairs 🪑'},
    {'id': 'High-Speed Wi-Fi', 'label': 'Wi-Fi 📶'},
    {'id': 'Locker Attached', 'label': 'Locker 🛅'},
    {'id': 'Silent Zone', 'label': 'Silent Zone 🤫'},
    {'id': 'CCTV Monitored', 'label': 'CCTV 📹'},
    {'id': 'Natural Light', 'label': 'Natural Light ☀️'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.section?.name ?? '');
    _notesController = TextEditingController(text: widget.section?.notes ?? '');
    if (widget.section != null) {
      _selectedColor = widget.section!.color;
      _sectionType = widget.section!.sectionType;
      _rowsController.text = widget.section!.rows.toString();
      _colsController.text = widget.section!.cols.toString();
      _floor = widget.section!.floor ?? 'Ground Floor';
      _selectedAmenities = List.from(widget.section!.amenities);
      if (widget.section!.genderRestriction == 'male') {
        _genderRestriction = GenderRestriction.male;
      } else if (widget.section!.genderRestriction == 'female') {
        _genderRestriction = GenderRestriction.female;
      } else {
        _genderRestriction = GenderRestriction.any;
      }
    } else {
      _loadSavedNamingStyle();
    }
  }

  Future<void> _loadSavedNamingStyle() async {
    if (widget.section != null) return;
    try {
      final libraryId = ref.read(currentLibraryIdProvider);
      if (libraryId == null || libraryId.isEmpty) return;
      final doc = await FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .get();
      if (!mounted) return;
      final saved = (doc.data() ?? {})['seatNumberingFormat'] as String?;
      if (saved != null) {
        final style = SeatNamingStyle.values.firstWhere(
          (s) => s.name == saved,
          orElse: () => SeatNamingStyle.numeric,
        );
        setState(() => _namingStyle = style);
      }
    } catch (_) { /* intentionally silent */ }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _addSeatsController.dispose();
    _startNumberController.dispose();
    _endNumberController.dispose();
    _customPrefixController.dispose();
    _rowsController.dispose();
    _colsController.dispose();
    super.dispose();
  }

  int _getTotalSeats() {
    if (_namingStyle == SeatNamingStyle.numeric ||
        _namingStyle == SeatNamingStyle.customPrefix) {
      final start = int.tryParse(_startNumberController.text) ?? 1;
      final end = int.tryParse(_endNumberController.text) ?? 50;
      return (end - start + 1).clamp(1, 2500);
    }
    final (r, c) = _computeRowsCols();
    return r * c;
  }

  (int, int) _computeRowsCols() {
    switch (_namingStyle) {
      case SeatNamingStyle.numeric:
      case SeatNamingStyle.customPrefix:
        final start = int.tryParse(_startNumberController.text) ?? 1;
        final end = int.tryParse(_endNumberController.text) ?? 50;
        final total = (end - start + 1).clamp(1, 2500);
        if (total <= 10) return (1, total);
        const cols = 10;
        final rows = (total / cols).ceil().clamp(1, 100);
        return (rows, cols);
      case SeatNamingStyle.alphanumeric:
      case SeatNamingStyle.sectionPrefixAlphanumeric:
        final r = int.tryParse(_rowsController.text) ?? 5;
        final c = int.tryParse(_colsController.text) ?? 10;
        return (r.clamp(1, 50), c.clamp(1, 50));
    }
  }

  String _getEndLabel() {
    final start = int.tryParse(_startNumberController.text) ?? 1;
    final totalSeats = _getTotalSeats();
    final prefix = _customPrefixController.text.trim().isNotEmpty
        ? _customPrefixController.text.trim().toUpperCase()
        : 'CAB';
    final sectionName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Main';

    switch (_namingStyle) {
      case SeatNamingStyle.alphanumeric:
        final (rows, cols) = _computeRowsCols();
        final lastRow = String.fromCharCode('A'.codeUnitAt(0) + rows - 1);
        return '$lastRow$cols';
      case SeatNamingStyle.numeric:
        final end =
            int.tryParse(_endNumberController.text) ?? (start + totalSeats - 1);
        return '$end';
      case SeatNamingStyle.customPrefix:
        return '$prefix-${totalSeats.toString().padLeft(2, '0')}';
      case SeatNamingStyle.sectionPrefixAlphanumeric:
        final (rows, cols) = _computeRowsCols();
        final sCode = sectionName.substring(0, 1).toUpperCase();
        final lastRow = String.fromCharCode('A'.codeUnitAt(0) + rows - 1);
        return '$sCode-$lastRow$cols';
    }
  }

  List<String> _getSampleSeatLabels() {
    final start = int.tryParse(_startNumberController.text) ?? 1;
    final totalSeats = _getTotalSeats();
    final prefix = _customPrefixController.text.trim().isNotEmpty
        ? _customPrefixController.text.trim().toUpperCase()
        : 'CAB';
    final sectionName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Main';

    switch (_namingStyle) {
      case SeatNamingStyle.alphanumeric:
        final (rows, cols) = _computeRowsCols();
        final samples = <String>[];
        outer:
        for (int r = 0; r < rows; r++) {
          for (int c = 1; c <= cols; c++) {
            samples.add('${String.fromCharCode('A'.codeUnitAt(0) + r)}$c');
            if (samples.length >= 3) break outer;
          }
        }
        return [...samples, '...', _getEndLabel()];
      case SeatNamingStyle.numeric:
        if (totalSeats <= 4) {
          return List.generate(totalSeats, (i) => '${start + i}');
        }
        return [
          '$start',
          '${start + 1}',
          '${start + 2}',
          '...',
          _getEndLabel(),
        ];
      case SeatNamingStyle.customPrefix:
        if (totalSeats <= 4) {
          return List.generate(
            totalSeats,
            (i) => '$prefix-${(i + 1).toString().padLeft(2, '0')}',
          );
        }
        return [
          '$prefix-01',
          '$prefix-02',
          '$prefix-03',
          '...',
          _getEndLabel(),
        ];
      case SeatNamingStyle.sectionPrefixAlphanumeric:
        final sCode = sectionName.substring(0, 1).toUpperCase();
        return ['$sCode-A1', '$sCode-A2', '$sCode-A3', '...', _getEndLabel()];
    }
  }

  Future<void> _saveSection() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.libraryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Library not loaded yet. Please go back and try again.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repository = ref.read(seatRepositoryProvider);
      final (rows, cols) = _computeRowsCols();
      final totalSeats = _getTotalSeats();

      if (widget.section == null) {
        if (totalSeats > 2500) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Maximum 2,500 seats per section supported.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
          return;
        }

        final newSection = SectionModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          libraryId: widget.libraryId,
          name: _nameController.text.trim(),
          rows: rows,
          cols: cols,
          color: _selectedColor,
          order: 0,
          isActive: true,
          notes: _notesController.text.trim(),
          sectionType: _sectionType,
          genderRestriction: _genderRestriction.name,
          floor: _floor,
          amenities: _selectedAmenities,
          totalSeats: totalSeats,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.createSection(
          libraryId: widget.libraryId,
          section: newSection,
          namingStyle: _namingStyle,
          startNumber: int.tryParse(_startNumberController.text) ?? 1,
          customPrefix: _customPrefixController.text.trim(),
          totalSeats: totalSeats,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Section created with $totalSeats seats!')),
          );
        }
      } else {
        final realSeats = await repository.getSeatsOnce(widget.libraryId, widget.section!.id);
        final currentSeatCount = realSeats.isNotEmpty
            ? realSeats.where((s) => !s.id.startsWith('missing_')).length
            : (ref.read(seatsProvider(widget.section!.id)).value?.length ?? widget.section!.capacity);
        final updatedSection = widget.section!.copyWith(
          name: _nameController.text.trim(),
          color: _selectedColor,
          notes: _notesController.text.trim(),
          sectionType: _sectionType,
          genderRestriction: _genderRestriction.name,
          floor: _floor,
          amenities: _selectedAmenities,
          totalSeats: currentSeatCount,
          rows: (currentSeatCount <= 10) ? 1 : (currentSeatCount / 10).ceil(),
          cols: 10,
          updatedAt: DateTime.now(),
        );
        await repository.updateSection(
          libraryId: widget.libraryId,
          section: updatedSection,
        );

        // Check if admin requested additional seats
        final additionalCount = int.tryParse(_addSeatsController.text.trim()) ?? 0;
        if (additionalCount > 0) {
          await repository.appendSeatsToSection(
            libraryId: widget.libraryId,
            sectionId: widget.section!.id,
            additionalCount: additionalCount,
            genderRestriction: _genderRestriction,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                additionalCount > 0
                    ? 'Section updated and added $additionalCount new seats!'
                    : 'Section updated successfully.',
              ),
            ),
          );
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildNumericRangeFields() {
    final start = int.tryParse(_startNumberController.text) ?? 1;
    final currentEnd = int.tryParse(_endNumberController.text) ?? 50;
    final currentTotal = (currentEnd - start + 1).clamp(0, 5000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_namingStyle == SeatNamingStyle.customPrefix) ...[
          TextFormField(
            controller: _customPrefixController,
            decoration: const InputDecoration(
              labelText: 'Seat Prefix *',
              hintText: 'e.g. CAB, VIP, AC, DESK',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label_rounded),
            ),
            textCapitalization: TextCapitalization.characters,
            inputFormatters: AppValidators.seatLabelFormatters,
            onChanged: (_) => setState(() {}),
            validator: (v) => AppValidators.seatLabel(v, required: true),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _startNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [AppValidators.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Start From',
                  hintText: '1',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.first_page_rounded),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1) return 'Enter valid start (≥ 1)';
                  return null;
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.arrow_forward_rounded),
            ),
            Expanded(
              child: TextFormField(
                controller: _endNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [AppValidators.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Ending With',
                  hintText: '50',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.last_page_rounded),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final s = int.tryParse(_startNumberController.text) ?? 1;
                  final end = int.tryParse(v ?? '');
                  if (end == null || end < s) return 'Must be >= start';
                  if (end - s + 1 > 2500) return 'Max 2500 seats';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Capacity Quick Presets
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Text(
                'Quick Presets:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 8),
              ...[25, 30, 50, 75, 100, 150, 200, 300].map((seatPreset) {
                final isSelected = currentTotal == seatPreset;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text('$seatPreset seats'),
                    backgroundColor: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    side: isSelected
                        ? BorderSide(color: Theme.of(context).colorScheme.primary)
                        : null,
                    onPressed: () {
                      final s = int.tryParse(_startNumberController.text) ?? 1;
                      _endNumberController.text = '${s + seatPreset - 1}';
                      setState(() {});
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGridRowColFields(ThemeData theme, int totalSeats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _rowsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Rows',
                  hintText: '5',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.table_rows_rounded),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1 || n > 100) return '1–100';
                  return null;
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  const Icon(Icons.close_rounded, size: 20),
                  Text(
                    '$totalSeats\nseats',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TextFormField(
                controller: _colsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Columns',
                  hintText: '10',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.view_column_rounded),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1 || n > 100) return '1–100';
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreviewCard(ThemeData theme) {
    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.remove_red_eye_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'First seat  →  Last seat:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _getSampleSeatLabels().map((sample) {
                final isDot = sample == '...';
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDot
                        ? Colors.transparent
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: isDot
                        ? null
                        : Border.all(
                            color: Color(_selectedColor).withValues(alpha: 0.6),
                          ),
                  ),
                  child: Text(
                    sample,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDot
                          ? theme.colorScheme.outline
                          : Color(_selectedColor),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalChip(int totalSeats) {
    return Align(
      alignment: Alignment.centerRight,
      child: Chip(
        avatar: const Icon(Icons.event_seat_rounded, size: 16),
        label: Text(
          'Total: $totalSeats seats',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        visualDensity: VisualDensity.compact,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCreating = widget.section == null;
    final totalSeats = _getTotalSeats();
    final actualSeatsAsync = widget.section != null
        ? ref.watch(seatsProvider(widget.section!.id))
        : null;
    final liveSeatCount = actualSeatsAsync?.value
            ?.where((s) => !s.id.startsWith('missing_'))
            .length ??
        widget.section?.capacity ??
        totalSeats;

    return Scaffold(
      appBar: AppBar(
        title: Text(isCreating ? 'Add Section' : 'Edit Section'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── STEP 1: Section Details ──────────────────────────
                    _StepHeader(number: '1', label: 'Section Details'),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Section Name *',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Main Hall, Quiet Zone, AC Cabins',
                        prefixIcon: Icon(Icons.meeting_room_rounded),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Please enter a section name.'
                              : null,
                    ),
                    const SizedBox(height: 14),

                    // Floor / Wing Selector
                    DropdownButtonFormField<String>(
                      initialValue: _floor,
                      decoration: const InputDecoration(
                        labelText: 'Floor / Wing',
                        prefixIcon: Icon(Icons.apartment_rounded),
                        border: OutlineInputBorder(),
                      ),
                      items: _floorOptions
                          .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                          .toList(),
                      onChanged: (v) => setState(() => _floor = v ?? 'Ground Floor'),
                    ),
                    const SizedBox(height: 14),

                    // Section Type Selector
                    DropdownButtonFormField<String>(
                      initialValue: _sectionType,
                      decoration: const InputDecoration(
                        labelText: 'Section Type',
                        prefixIcon: Icon(Icons.chair_alt_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'normal', child: Text('Normal (Standard Hall)')),
                        DropdownMenuItem(value: 'window', child: Text('Window Side 🪟')),
                        DropdownMenuItem(value: 'ac', child: Text('AC Zone ❄️')),
                        DropdownMenuItem(value: 'premium', child: Text('Premium Cabin 🌟')),
                      ],
                      onChanged: (v) => setState(() => _sectionType = v ?? 'normal'),
                    ),
                    const SizedBox(height: 14),

                    // Gender Access Selector (In BOTH Add & Edit!)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gender Access Restriction',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              avatar: const Icon(Icons.people_rounded, size: 16),
                              label: const Text('All (Co-ed)'),
                              selected: _genderRestriction == GenderRestriction.any,
                              onSelected: (_) => setState(
                                  () => _genderRestriction = GenderRestriction.any),
                            ),
                            ChoiceChip(
                              avatar: const Icon(Icons.male_rounded, size: 16),
                              label: const Text('Boys Only'),
                              selected: _genderRestriction == GenderRestriction.male,
                              onSelected: (_) => setState(
                                  () => _genderRestriction = GenderRestriction.male),
                            ),
                            ChoiceChip(
                              avatar: const Icon(Icons.female_rounded, size: 16),
                              label: const Text('Girls Only'),
                              selected: _genderRestriction == GenderRestriction.female,
                              onSelected: (_) => setState(
                                  () => _genderRestriction = GenderRestriction.female),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── SEAT NUMBERING & CAPACITY ──────────────────────────
                    if (isCreating) ...[
                      _StepHeader(number: '2', label: 'Seat Numbering & Capacity'),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<SeatNamingStyle>(
                        initialValue: _namingStyle,
                        decoration: const InputDecoration(
                          labelText: 'Numbering Style',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.format_list_numbered_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: SeatNamingStyle.numeric,
                            child: Text('🔢 Continuous Numbers (1, 2, 3...)'),
                          ),
                          DropdownMenuItem(
                            value: SeatNamingStyle.customPrefix,
                            child: Text('🏷️ Custom Prefix (CAB-01, CAB-02...)'),
                          ),
                          DropdownMenuItem(
                            value: SeatNamingStyle.alphanumeric,
                            child: Text('🔤 Grid Layout (A1, A2, B1, B2...)'),
                          ),
                          DropdownMenuItem(
                            value: SeatNamingStyle.sectionPrefixAlphanumeric,
                            child: Text('🏢 Section Code + Grid (M-A1, M-A2...)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _namingStyle = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      if (_namingStyle == SeatNamingStyle.numeric ||
                          _namingStyle == SeatNamingStyle.customPrefix)
                        _buildNumericRangeFields()
                      else
                        _buildGridRowColFields(theme, totalSeats),

                      const SizedBox(height: 10),
                      if (_namingStyle == SeatNamingStyle.numeric ||
                          _namingStyle == SeatNamingStyle.customPrefix)
                        _buildTotalChip(totalSeats),
                      const SizedBox(height: 14),

                      _StepHeader(number: '3', label: 'Numbering Preview'),
                      const SizedBox(height: 8),
                      _buildPreviewCard(theme),
                      const SizedBox(height: 24),
                    ] else ...[
                      // EDIT MODE CAPACITY & EXPANSION
                      _StepHeader(number: '2', label: 'Seat Capacity & Expansion'),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Current Capacity:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text(
                                        'Physical Desks: $liveSeatCount',
                                        style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                                      ),
                                    ],
                                  ),
                                  Chip(
                                    avatar: const Icon(Icons.event_seat_rounded, size: 16),
                                    label: Text('$liveSeatCount Seats', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              if (widget.section!.capacity != liveSeatCount) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.sync_problem_rounded, color: Colors.amber, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Stored capacity is ${widget.section!.capacity}, but only $liveSeatCount desks exist. Tapping "Update Section" will synchronize capacity to $liveSeatCount.',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _addSeatsController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Add More Desks (Optional)',
                                  hintText: 'e.g., 5 or 10',
                                  prefixIcon: Icon(Icons.add_circle_outline_rounded),
                                  border: OutlineInputBorder(),
                                  helperText: 'Appends new available desks with continuous numbering without affecting existing allocations.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ── AMENITIES CHECKLIST ────────────────────────────────
                    _StepHeader(number: isCreating ? '4' : '3', label: 'Section Amenities & Features'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableAmenities.map((amenity) {
                        final id = amenity['id']!;
                        final label = amenity['label']!;
                        final isSelected = _selectedAmenities.contains(id);
                        return FilterChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedAmenities.add(id);
                              } else {
                                _selectedAmenities.remove(id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // ── SECTION THEME COLOR ────────────────────────────────
                    _StepHeader(number: isCreating ? '5' : '4', label: 'Section Badge Color'),
                    const SizedBox(height: 4),
                    Text(
                      'Used for the section badge and header accent (Seat status colors always stay standard green/red).',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: _colorOptions.map((c) {
                        final colorHex = c['hex'] as int;
                        final isSelected = _selectedColor == colorHex;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = colorHex),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Color(colorHex),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: theme.colorScheme.onSurface,
                                      width: 3,
                                    )
                                  : Border.all(
                                      color: Colors.transparent,
                                      width: 3,
                                    ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Color(colorHex).withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // ── NOTES & GUIDELINES ─────────────────────────────────
                    _StepHeader(number: isCreating ? '6' : '5', label: 'Notes & Guidelines (Optional)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Silent area, power outlets at every desk, reserved for UPSC aspirants',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── SUBMIT BUTTON ──────────────────────────────────────
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _saveSection,
                      icon: Icon(
                        isCreating ? Icons.add_rounded : Icons.save_rounded,
                      ),
                      label: Text(
                        _isLoading
                            ? 'Saving...'
                            : (isCreating
                                ? 'Create Section & Generate $totalSeats Seats'
                                : 'Update Section'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final String number;
  final String label;
  const _StepHeader({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: theme.colorScheme.primary,
            child: Text(
              number,
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
