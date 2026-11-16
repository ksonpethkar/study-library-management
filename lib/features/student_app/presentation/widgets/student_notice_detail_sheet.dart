import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:study_library/core/providers/font_settings_provider.dart';
import 'package:study_library/models/announcement_model.dart';

/// Modal bottom sheet providing an accessible, mobile-optimized reading view
/// for library notices with dynamic Quick A- / A+ Zoom controls.
class StudentNoticeDetailSheet extends ConsumerStatefulWidget {
  final AnnouncementModel announcement;
  final String? studentId;
  final String? libraryId;

  const StudentNoticeDetailSheet({
    super.key,
    required this.announcement,
    this.studentId,
    this.libraryId,
  });

  /// Displays the interactive notice detail sheet.
  static Future<void> show(
    BuildContext context, {
    required AnnouncementModel announcement,
    String? studentId,
    String? libraryId,
  }) {
    HapticFeedback.lightImpact();

    // Mark as read in Firestore
    if (studentId != null &&
        studentId.isNotEmpty &&
        libraryId != null &&
        libraryId.isNotEmpty &&
        !announcement.readBy.contains(studentId)) {
      FirebaseFirestore.instance
          .collection('libraries')
          .doc(libraryId)
          .collection('announcements')
          .doc(announcement.id)
          .update({
        'readBy': FieldValue.arrayUnion([studentId]),
      }).ignore();
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => StudentNoticeDetailSheet(
        announcement: announcement,
        studentId: studentId,
        libraryId: libraryId,
      ),
    );
  }

  @override
  ConsumerState<StudentNoticeDetailSheet> createState() =>
      _StudentNoticeDetailSheetState();
}

class _StudentNoticeDetailSheetState
    extends ConsumerState<StudentNoticeDetailSheet> {
  // Reading zoom steps: 0.85x, 1.00x, 1.15x, 1.30x
  static const List<double> _zoomLevels = [0.85, 1.00, 1.15, 1.30];
  late int _currentZoomIndex;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    // Default zoom initialized to match global font settings
    final globalScale = ref.read(fontSettingsProvider).scale;
    switch (globalScale) {
      case AppFontScale.compact:
        _currentZoomIndex = 0;
        break;
      case AppFontScale.standard:
        _currentZoomIndex = 1;
        break;
      case AppFontScale.comfort:
        _currentZoomIndex = 2;
        break;
      case AppFontScale.large:
        _currentZoomIndex = 3;
        break;
    }
  }

  double get _currentZoom => _zoomLevels[_currentZoomIndex];

  void _zoomIn() {
    if (_currentZoomIndex < _zoomLevels.length - 1) {
      HapticFeedback.lightImpact();
      setState(() => _currentZoomIndex++);
    }
  }

  void _zoomOut() {
    if (_currentZoomIndex > 0) {
      HapticFeedback.lightImpact();
      setState(() => _currentZoomIndex--);
    }
  }

  void _resetZoom() {
    HapticFeedback.selectionClick();
    setState(() => _currentZoomIndex = 1); // 1.00x standard
  }

  Future<void> _copyNotice() async {
    final text = '${widget.announcement.title}\n\n${widget.announcement.message}';
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _shareNotice() async {
    HapticFeedback.lightImpact();
    final text = '📢 *${widget.announcement.title}*\n\n${widget.announcement.message}\n\n— The Cozy Corner Study Centre';
    // ignore: deprecated_member_use
    await Share.share(text, subject: widget.announcement.title);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = widget.announcement;
    final zoom = _currentZoom;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 2. Header Bar: Priority Badge + Quick A- / A+ Zoom Pill + Close Button
              Row(
                children: [
                  // Priority Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: a.priority.containerColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: a.priority.color.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(a.priority.icon, size: 14, color: a.priority.onContainerColor),
                        const SizedBox(width: 5),
                        Text(
                          a.priority.label.toUpperCase(),
                          style: TextStyle(
                            color: a.priority.onContainerColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Quick A- / A+ Zoom Capsule
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: _currentZoomIndex > 0 ? _zoomOut : null,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            child: Text(
                              'A-',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _currentZoomIndex > 0
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: _resetZoom,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Text(
                              '${(zoom * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: _currentZoomIndex < _zoomLevels.length - 1 ? _zoomIn : null,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            child: Text(
                              'A+',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _currentZoomIndex < _zoomLevels.length - 1
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Close Button
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Close Notice',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 3. Scrollable Notice Content with Dynamic Zoom
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Notice Title
                      SelectableText(
                        a.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 17 * zoom,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Metadata info line
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (a.createdAt != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.schedule_rounded,
                                    size: 13, color: theme.colorScheme.outline),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('EEE, MMM d, yyyy • h:mm a').format(a.createdAt!),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          if (a.expiresAt != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer_outlined,
                                    size: 13, color: theme.colorScheme.outline),
                                const SizedBox(width: 4),
                                Text(
                                  'Active until ${DateFormat("MMM d, yyyy").format(a.expiresAt!)}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),

                      // Notice Body Message (Selectable & Scaled)
                      SelectableText(
                        a.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14.5 * zoom,
                          height: 1.6,
                          letterSpacing: 0.1,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // 4. Bottom Action Bar (Copy, Share, Done)
              const SizedBox(height: 8),
              Row(
                children: [
                  // Copy Button
                  OutlinedButton.icon(
                    onPressed: _copyNotice,
                    icon: Icon(
                      _copied ? Icons.check_circle_rounded : Icons.copy_rounded,
                      size: 16,
                      color: _copied ? Colors.green : null,
                    ),
                    label: Text(_copied ? 'Copied' : 'Copy'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Share Button
                  IconButton.outlined(
                    tooltip: 'Share Circular',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _shareNotice,
                  ),
                  const SizedBox(width: 10),

                  // Primary Understood Button
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Understood',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
