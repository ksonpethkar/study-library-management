import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/core/validators/gov_id_validator.dart';
import 'package:study_library/core/security/audit_logger.dart';
import 'package:study_library/core/security/encryption_service.dart';
import 'package:study_library/services/image_service.dart';
import 'package:study_library/services/document_picker_service.dart';
import 'package:study_library/core/utils/error_formatter.dart';

enum DocumentFilterMode { original, highContrast, grayscale }

/// Professional Admin Document Studio for viewing, modifying, re-uploading,
/// cropping/rotating, filtering, and watermarking Government IDs.
class AdminDocumentStudioDialog extends StatefulWidget {
  final String documentTitle;
  final String imageUrl;
  final String? backImageUrl;
  final String initialGovIdType;
  final String initialGovIdNumber;
  final String libraryId;
  final String? requestId;
  final String? studentId;
  final VoidCallback? onDocumentUpdated;

  const AdminDocumentStudioDialog({
    super.key,
    required this.documentTitle,
    required this.imageUrl,
    this.backImageUrl,
    required this.initialGovIdType,
    required this.initialGovIdNumber,
    required this.libraryId,
    this.requestId,
    this.studentId,
    this.onDocumentUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required String documentTitle,
    required String imageUrl,
    String? backImageUrl,
    required String initialGovIdType,
    required String initialGovIdNumber,
    required String libraryId,
    String? requestId,
    String? studentId,
    VoidCallback? onDocumentUpdated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AdminDocumentStudioDialog(
        documentTitle: documentTitle,
        imageUrl: imageUrl,
        backImageUrl: backImageUrl,
        initialGovIdType: initialGovIdType,
        initialGovIdNumber: initialGovIdNumber,
        libraryId: libraryId,
        requestId: requestId,
        studentId: studentId,
        onDocumentUpdated: onDocumentUpdated,
      ),
    );
  }

  @override
  State<AdminDocumentStudioDialog> createState() => _AdminDocumentStudioDialogState();
}

class _AdminDocumentStudioDialogState extends State<AdminDocumentStudioDialog> {
  late String _currentImageUrl;
  String? _currentBackImageUrl;
  bool _showingBackSide = false;

  int _quarterTurns = 0;
  DocumentFilterMode _filterMode = DocumentFilterMode.original;
  bool _showWatermark = true;

  // In-line ID correction
  late GovIdType _selectedType;
  late final TextEditingController _idNumberController;
  bool _isSavingDetails = false;
  bool _isUploadingNewImage = false;

  // Color Filter Matrices
  static const List<double> _grayscaleMatrix = [
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ];

  static const List<double> _highContrastMatrix = [
    1.6, 1.6, 1.6, 0, -130,
    1.6, 1.6, 1.6, 0, -130,
    1.6, 1.6, 1.6, 0, -130,
    0,   0,   0,   1, 0,
  ];

  @override
  void initState() {
    super.initState();
    _currentImageUrl = widget.imageUrl;
    _currentBackImageUrl = widget.backImageUrl;

    final rawType = widget.initialGovIdType.toLowerCase();
    _selectedType = GovIdType.values.firstWhere(
      (t) => t.name.toLowerCase() == rawType ||
             (rawType.contains('dl') && t == GovIdType.drivingLicence) ||
             (rawType.contains('voter') && t == GovIdType.voterId) ||
             (rawType.contains('pass') && t == GovIdType.passport),
      orElse: () => GovIdType.aadhaar,
    );

    _idNumberController = TextEditingController(
      text: GovIdValidator.format(_selectedType, widget.initialGovIdNumber),
    );

    // Audit log document inspection
    AuditLogger().log(
      action: AuditAction.updated,
      entityType: widget.requestId != null ? AuditEntity.request : AuditEntity.student,
      libraryId: widget.libraryId,
      entityId: widget.requestId ?? widget.studentId ?? 'unknown',
      details: {
        'action': 'VIEW_GOV_ID_DOCUMENT',
        'docType': _selectedType.name,
      },
    ).ignore();
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    super.dispose();
  }

  void _rotateClockwise() {
    HapticFeedback.selectionClick();
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
    });
  }

  Future<void> _reuploadDocument({bool isBackSide = false}) async {
    final doc = await DocumentPickerService.pickDocument(
      context: context,
    );
    if (doc == null || !mounted) return;

    final dataUrl = doc.dataUrl;

    setState(() => _isUploadingNewImage = true);

    try {
      final key = isBackSide ? 'govIdBackImageUrl' : 'govIdImageUrl';
      final fieldUpdates = <String, dynamic>{
        key: dataUrl,
        if (isBackSide) 'govIdBackDataUrl': dataUrl else 'govIdDataUrl': dataUrl,
        if (isBackSide) 'govIdBackFileName': doc.fileName else 'govIdFileName': doc.fileName,
      };

      if (widget.requestId != null) {
        await FirebaseFirestore.instance
            .collection('libraries')
            .doc(widget.libraryId)
            .collection('requests')
            .doc(widget.requestId)
            .set({
          key: dataUrl,
          'studentData': fieldUpdates,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (widget.studentId != null) {
        await FirebaseFirestore.instance
            .collection('libraries')
            .doc(widget.libraryId)
            .collection('students')
            .doc(widget.studentId)
            .set(fieldUpdates, SetOptions(merge: true));
      }

      setState(() {
        if (isBackSide) {
          _currentBackImageUrl = dataUrl;
        } else {
          _currentImageUrl = dataUrl;
        }
      });

      widget.onDocumentUpdated?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 8),
                Text('${isBackSide ? "Back" : "Front"} document updated successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'gov_id');
      }
    } finally {
      if (mounted) setState(() => _isUploadingNewImage = false);
    }
  }

  Future<void> _saveIdDetails() async {
    final clean = _idNumberController.text.trim();
    final validationError = GovIdValidator.validate(_selectedType, clean, isRequired: true);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError), backgroundColor: Colors.amber.shade900),
      );
      return;
    }

    setState(() => _isSavingDetails = true);

    try {
      final encryptedId = clean.isNotEmpty ? EncryptionService.encryptGovId(clean, widget.libraryId) : '';

      if (widget.requestId != null) {
        await FirebaseFirestore.instance
            .collection('libraries')
            .doc(widget.libraryId)
            .collection('requests')
            .doc(widget.requestId)
            .set({
          'govIdType': _selectedType.name,
          'govIdNumber': encryptedId,
          'studentData': {
            'govIdType': _selectedType.name,
            'govIdNumber': clean,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (widget.studentId != null) {
        await FirebaseFirestore.instance
            .collection('libraries')
            .doc(widget.libraryId)
            .collection('students')
            .doc(widget.studentId)
            .set({
          'govIdType': _selectedType.name,
          'govIdNumber': encryptedId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      widget.onDocumentUpdated?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                SizedBox(width: 8),
                Text('Government ID details updated and encrypted!'),
              ],
            ),
            backgroundColor: Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppErrorFormatter.showErrorSnackBar(context, e, actionContext: 'camera');
      }
    } finally {
      if (mounted) setState(() => _isSavingDetails = false);
    }
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required DocumentFilterMode mode,
  }) {
    final isSelected = _filterMode == mode;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey.shade700),
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: const Color(0xFF2563EB),
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
      onSelected: (sel) {
        if (sel) setState(() => _filterMode = mode);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeUrl = _showingBackSide && _currentBackImageUrl != null
        ? _currentBackImageUrl!
        : _currentImageUrl;

    final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 900),
        child: Column(
          children: [
            // Studio Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.document_scanner_rounded, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Document Studio',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.documentTitle,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),

                  // Front / Back toggle (if back side exists)
                  if (_currentBackImageUrl != null && _currentBackImageUrl!.isNotEmpty) ...[
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Front')),
                        ButtonSegment(value: true, label: Text('Back')),
                      ],
                      selected: {_showingBackSide},
                      onSelectionChanged: (set) => setState(() => _showingBackSide = set.first),
                      style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    ),
                    const SizedBox(width: 10),
                  ],

                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close Studio',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Studio Toolbar (Rotate, Filters, Watermark, Re-upload)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Rotate
                    OutlinedButton.icon(
                      onPressed: _rotateClockwise,
                      icon: const Icon(Icons.rotate_right_rounded, size: 18),
                      label: Text('Rotate (${_quarterTurns * 90}°)'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Filter Modes
                    _buildFilterChip(
                      label: 'Original',
                      icon: Icons.palette_outlined,
                      mode: DocumentFilterMode.original,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'B&W High-Contrast',
                      icon: Icons.contrast_rounded,
                      mode: DocumentFilterMode.highContrast,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Grayscale',
                      icon: Icons.monochrome_photos_rounded,
                      mode: DocumentFilterMode.grayscale,
                    ),
                    const SizedBox(width: 14),

                    // Watermark Toggle
                    FilterChip(
                      avatar: Icon(
                        _showWatermark ? Icons.verified_user_rounded : Icons.security_rounded,
                        size: 16,
                        color: _showWatermark ? Colors.green.shade700 : Colors.grey,
                      ),
                      label: const Text('Watermark Overlay', style: TextStyle(fontSize: 12)),
                      selected: _showWatermark,
                      onSelected: (val) => setState(() => _showWatermark = val),
                    ),
                    const SizedBox(width: 14),

                    // Re-Upload / Replace Document
                    FilledButton.icon(
                      onPressed: _isUploadingNewImage ? null : () => _reuploadDocument(isBackSide: _showingBackSide),
                      icon: _isUploadingNewImage
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.upload_file_rounded, size: 16),
                      label: Text(_showingBackSide ? 'Replace Back' : 'Replace Front'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: const Color(0xFF047857),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Document Viewport (Pan, Zoom, Rotate, Filter & Watermark)
            Expanded(
              child: Container(
                color: isDark ? Colors.black45 : Colors.grey.shade100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    InteractiveViewer(
                      maxScale: 5.0,
                      minScale: 0.5,
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: _quarterTurns,
                          child: _buildFilteredImage(activeUrl),
                        ),
                      ),
                    ),

                    // Diagonal Security Watermark Overlay
                    if (_showWatermark)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _SecurityWatermarkPainter(
                              text: 'COZY CORNER STUDY CENTRE • ADMISSION VERIFIED • $dateStr',
                            ),
                          ),
                        ),
                      ),

                    // Zoom Helper Hint
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pinch_rounded, color: Colors.white70, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Pinch / Scroll to Zoom & Pan',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom In-Line ID Details Editor
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  // ID Type Dropdown
                  SizedBox(
                    width: 170,
                    child: DropdownButtonFormField<GovIdType>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'ID Type',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: GovIdType.values.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.displayName, style: const TextStyle(fontSize: 13)),
                      )).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _selectedType = v;
                            _idNumberController.text = GovIdValidator.format(v, _idNumberController.text);
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ID Number TextField
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _idNumberController,
                      builder: (context, val, child) {
                        final rawText = val.text.trim();
                        final isValid = rawText.isNotEmpty &&
                            GovIdValidator.isValid(_selectedType, rawText);
                        final showWarning = rawText.isNotEmpty && !isValid;

                        return TextFormField(
                          controller: _idNumberController,
                          decoration: InputDecoration(
                            labelText: '${_selectedType.displayName} Number',
                            hintText: _selectedType.placeholder,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: const OutlineInputBorder(),
                            isDense: true,
                            prefixIcon: const Icon(Icons.credit_card_rounded, size: 20),
                            suffixIcon: rawText.isEmpty
                                ? null
                                : isValid
                                    ? const Tooltip(
                                        message: 'Valid Checksum / Format Verified',
                                        child: Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 18),
                                      )
                                    : showWarning
                                        ? const Tooltip(
                                            message: 'Invalid format or checksum mismatch',
                                            child: Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                                          )
                                        : null,
                          ),
                          textCapitalization: GovIdValidator.textCapitalization(_selectedType),
                          keyboardType: GovIdValidator.keyboardType(_selectedType),
                          inputFormatters: GovIdValidator.inputFormatters(_selectedType),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Save Details Button
                  FilledButton.icon(
                    onPressed: _isSavingDetails ? null : _saveIdDetails,
                    icon: _isSavingDetails
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Save ID'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredImage(String url) {
    if (DocumentPickerService.isPdf(url)) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 64),
              const SizedBox(height: 16),
              const Text(
                'PDF Document Attached',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'This document was uploaded as a PDF file (e.g. e-Aadhaar / DigiLocker proof).',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    Widget imageWidget = ImageService.buildImageWidget(url, fit: BoxFit.contain);

    if (_filterMode == DocumentFilterMode.highContrast) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(_highContrastMatrix),
        child: imageWidget,
      );
    } else if (_filterMode == DocumentFilterMode.grayscale) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(_grayscaleMatrix),
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

/// Custom Painter that renders repeated diagonal security watermarks
class _SecurityWatermarkPainter extends CustomPainter {
  final String text;

  _SecurityWatermarkPainter({required this.text});

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      color: Colors.black.withValues(alpha: 0.16),
      fontSize: 13,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.2,
    );
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.rotate(-math.pi / 5.5);

    final stepX = textPainter.width + 120;
    final stepY = textPainter.height + 90;

    for (double y = -size.height; y < size.height * 2; y += stepY) {
      for (double x = -size.width; x < size.width * 2; x += stepX) {
        textPainter.paint(canvas, Offset(x, y));
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SecurityWatermarkPainter oldDelegate) {
    return oldDelegate.text != text;
  }
}
