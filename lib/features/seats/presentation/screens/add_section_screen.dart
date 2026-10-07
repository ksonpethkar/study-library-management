import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/seat_providers.dart';

import 'package:study_library/models/section_model.dart';
import 'package:study_library/models/seat_model.dart';
import 'package:study_library/core/providers/library_provider.dart';
import 'package:study_library/services/remote_config_service.dart';

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

  // Seat numbering fields
  SeatNamingStyle _namingStyle = SeatNamingStyle.alphanumeric;
  final _startNumberController = TextEditingController(text: '1');
  final _endNumberController = TextEditingController(text: '50');
  final _customPrefixController = TextEditingController(text: 'CAB');
  final _rowsController = TextEditingController(text: '5');
  final _colsController = TextEditingController(text: '10');

  // Gender restriction
  GenderRestriction _genderRestriction = GenderRestriction.any;

  int _selectedColor = 0xFF3498DB;
  String _sectionType = 'normal';
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
    }
    // Load saved seat numbering preference from Firestore
    _loadSavedNamingStyle();
  }

  /// Reads the admin's saved preference from Settings and pre-selects it.
  Future<void> _loadSavedNamingStyle() async {
    // Only apply preference when CREATING a new section (not editing existing)
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
          orElse: () => SeatNamingStyle.alphanumeric,
        );
        setState(() => _namingStyle = style);
      }
    } catch (_) {} // fail silently — default alphanumeric is fine
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _startNumberController.dispose();
    _endNumberController.dispose();
    _customPrefixController.dispose();
    _rowsController.dispose();
    _colsController.dispose();
    super.dispose();
  }

  /// Returns exact total seat count according to the selected numbering style.
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

  /// Returns (rows, cols) based on current style and user inputs.
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
          content: Text(
            'Library not loaded yet. Please go back and try again.',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repository = ref.read(seatRepositoryProvider);
      final (rows, cols) = _computeRowsCols();
      final totalSeats = _getTotalSeats();
      final maxSeats = RemoteConfigService.maxSeatsPerSection;

      if (rows * cols > maxSeats || totalSeats > maxSeats) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Maximum $maxSeats seats per section allowed by admin configuration',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      if (widget.section == null) {
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
        final updatedSection = widget.section!.copyWith(
          name: _nameController.text.trim(),
          rows: rows,
          cols: cols,
          color: _selectedColor,
          notes: _notesController.text.trim(),
          sectionType: _sectionType,
          updatedAt: DateTime.now(),
        );
        await repository.updateSection(
          libraryId: widget.libraryId,
          section: updatedSection,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Section updated successfully.')),
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
                        : Color(_selectedColor).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
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

  List<Widget> _buildCreatingSteps(ThemeData theme, int totalSeats) {
    return [
      // ── STEP 2: Seat Numbering Style ─────────────────────
      _StepHeader(number: '2', label: 'Seat Numbering Style'),
      const SizedBox(height: 8),
      DropdownButtonFormField<SeatNamingStyle>(
        initialValue: _namingStyle,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.format_list_numbered_rounded),
        ),
        items: const [
          DropdownMenuItem(
            value: SeatNamingStyle.alphanumeric,
            child: Text('🔤 Grid (A1, A2, B1, B2...)'),
          ),
          DropdownMenuItem(
            value: SeatNamingStyle.numeric,
            child: Text('🔢 Continuous Numbers (1, 2, 3...)'),
          ),
          DropdownMenuItem(
            value: SeatNamingStyle.customPrefix,
            child: Text('🏷️ Custom Prefix (CAB-01, CAB-02...)'),
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
      const SizedBox(height: 24),

      // ── STEP 3: Style-specific fields ────────────────────
      _StepHeader(number: '3', label: 'Seat Range & Layout'),
      const SizedBox(height: 8),

      // Numeric & Custom Prefix → Start From + Ending With
      if (_namingStyle == SeatNamingStyle.numeric ||
          _namingStyle == SeatNamingStyle.customPrefix)
        _buildNumericRangeFields()
      else
        _buildGridRowColFields(theme, totalSeats),

      if ((_namingStyle == SeatNamingStyle.numeric ||
              _namingStyle == SeatNamingStyle.customPrefix) &&
          totalSeats > RemoteConfigService.maxSeatsPerSection) ...[
        const SizedBox(height: 6),
        Text(
          'Maximum ${RemoteConfigService.maxSeatsPerSection} seats per section allowed by admin configuration',
          style: const TextStyle(
            color: Colors.red,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],

      const SizedBox(height: 8),
      if (_namingStyle == SeatNamingStyle.numeric ||
          _namingStyle == SeatNamingStyle.customPrefix)
        _buildTotalChip(totalSeats),
      const SizedBox(height: 20),

      // ── STEP 4: Preview ───────────────────────────────────
      _StepHeader(number: '4', label: 'Numbering Preview'),
      const SizedBox(height: 8),
      _buildPreviewCard(theme),
      const SizedBox(height: 24),

      // ── STEP 5: Gender Access ─────────────────────────────
      _StepHeader(number: '5', label: 'Gender Access'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          ChoiceChip(
            avatar: const Icon(Icons.people_rounded, size: 16),
            label: const Text('All'),
            selected: _genderRestriction == GenderRestriction.any,
            onSelected: (_) =>
                setState(() => _genderRestriction = GenderRestriction.any),
          ),
          ChoiceChip(
            avatar: const Icon(Icons.male_rounded, size: 16),
            label: const Text('Male Only'),
            selected: _genderRestriction == GenderRestriction.male,
            onSelected: (_) =>
                setState(() => _genderRestriction = GenderRestriction.male),
          ),
          ChoiceChip(
            avatar: const Icon(Icons.female_rounded, size: 16),
            label: const Text('Female Only'),
            selected: _genderRestriction == GenderRestriction.female,
            onSelected: (_) =>
                setState(() => _genderRestriction = GenderRestriction.female),
          ),
        ],
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _buildNumericRangeFields() {
    return Column(
      children: [
        if (_namingStyle == SeatNamingStyle.customPrefix) ...[
          TextFormField(
            controller: _customPrefixController,
            decoration: const InputDecoration(
              labelText: 'Seat Prefix',
              hintText: 'e.g. CAB, VIP, AC, DESK',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label_rounded),
            ),
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter a prefix' : null,
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _startNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Start From',
                  hintText: '1',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.first_page_rounded),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1) return 'Enter valid start';
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
                decoration: const InputDecoration(
                  labelText: 'Ending With',
                  hintText: '50',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.last_page_rounded),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final start = int.tryParse(_startNumberController.text) ?? 1;
                  final end = int.tryParse(v ?? '');
                  if (end == null || end < start) return 'Must be >= start';
                  if (end - start + 1 > 2500) return 'Max 2500 seats';
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGridRowColFields(ThemeData theme, int totalSeats) {
    final rows = int.tryParse(_rowsController.text) ?? 5;
    final cols = int.tryParse(_colsController.text) ?? 10;
    final maxSeats = RemoteConfigService.maxSeatsPerSection;

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
                  if (n == null || n < 1 || n > 50) return '1–50';
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
                  if (n == null || n < 1 || n > 50) return '1–50';
                  return null;
                },
              ),
            ),
          ],
        ),
        if (rows * cols > maxSeats) ...[
          const SizedBox(height: 8),
          Text(
            'Maximum $maxSeats seats per section allowed by admin configuration',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCreating = widget.section == null;
    final totalSeats = _getTotalSeats();

    return Scaffold(
      appBar: AppBar(title: Text(isCreating ? 'Add Section' : 'Edit Section')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── STEP 1: Section Name ─────────────────────────────
                    _StepHeader(number: '1', label: 'Section Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Section Name',
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
                    const SizedBox(height: 24),

                    // Steps 2–5 only when creating
                    if (isCreating) ..._buildCreatingSteps(theme, totalSeats),

                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _sectionType,
                      decoration: const InputDecoration(
                        labelText: 'Section Type',
                        prefixIcon: Icon(Icons.chair_alt_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'normal', child: Text('Normal')),
                        DropdownMenuItem(value: 'window', child: Text('Window Side 🪟')),
                        DropdownMenuItem(value: 'ac', child: Text('AC Zone ❄️')),
                        DropdownMenuItem(value: 'premium', child: Text('Premium 🌟')),
                      ],
                      onChanged: (v) => setState(() => _sectionType = v ?? 'normal'),
                    ),
                    const SizedBox(height: 24),

                    // ── STEP 6 (or 2 when editing): Section Color ─────────
                    _StepHeader(
                      number: isCreating ? '6' : '2',
                      label: 'Section Color',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: _colorOptions.map((c) {
                        final colorHex = c['hex'] as int;
                        final isSelected = _selectedColor == colorHex;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedColor = colorHex),
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
                                        color: Color(colorHex)
                                            .withValues(alpha: 0.5),
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

                    // ── STEP 7 (or 3 when editing): Notes ────────────────
                    _StepHeader(
                      number: isCreating ? '7' : '3',
                      label: 'Notes (Optional)',
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText:
                            'e.g., Silent area, power outlets at every desk',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Create / Update Button ────────────────────────────
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

/// Small numbered step header widget
class _StepHeader extends StatelessWidget {
  final String number;
  final String label;
  const _StepHeader({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: theme.colorScheme.primary,
          child: Text(
            number,
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
