import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:study_library/core/router/app_router.dart';
import 'package:study_library/models/student_model.dart';
import 'package:study_library/services/app_notification_service.dart';
import 'package:study_library/core/utils/seat_helper.dart';

class SilentHelpOption {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String defaultMessage;

  const SilentHelpOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.defaultMessage,
  });
}

class SilentReceptionHelpSheet extends StatefulWidget {
  final String libraryId;
  final StudentModel? student;
  final String initialDeskLabel;

  const SilentReceptionHelpSheet({
    super.key,
    required this.libraryId,
    this.student,
    required this.initialDeskLabel,
  });

  static Future<void> show(
    BuildContext context, {
    required String libraryId,
    StudentModel? student,
    String? deskLabel,
  }) {
    HapticFeedback.selectionClick();
    final effectiveDesk = (deskLabel != null && deskLabel.isNotEmpty)
        ? deskLabel
        : ((student?.seatId != null && student!.seatId!.isNotEmpty)
            ? SeatHelper.formatSeatLabel(seatId: student.seatId)
            : 'Study Hall');

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SilentReceptionHelpSheet(
        libraryId: libraryId,
        student: student,
        initialDeskLabel: effectiveDesk,
      ),
    );
  }

  @override
  State<SilentReceptionHelpSheet> createState() => _SilentReceptionHelpSheetState();
}

class _SilentReceptionHelpSheetState extends State<SilentReceptionHelpSheet> {
  late String _selectedDesk;
  int _selectedOptionIndex = 0;
  final _noteController = TextEditingController();
  bool _isCustomDesk = false;
  final _deskController = TextEditingController();
  bool _isSubmitting = false;

  final List<SilentHelpOption> _options = const [
    SilentHelpOption(
      id: 'noise',
      title: 'Noise Disturbance',
      subtitle: 'Whispering, talking, or phone call noise in study zone',
      icon: Icons.volume_off_rounded,
      color: Color(0xFFEF4444),
      defaultMessage: 'Noise disturbance in study zone. Requesting discreet floor supervisor check.',
    ),
    SilentHelpOption(
      id: 'ac',
      title: 'AC / Temperature',
      subtitle: 'Room is too cold or too warm',
      icon: Icons.ac_unit_rounded,
      color: Color(0xFF0284C7),
      defaultMessage: 'Please adjust the AC temperature or airflow in our study area.',
    ),
    SilentHelpOption(
      id: 'wifi',
      title: 'Wi-Fi / Latency',
      subtitle: 'Slow internet, disconnections, or high ping',
      icon: Icons.wifi_off_rounded,
      color: Color(0xFF8B5CF6),
      defaultMessage: 'Wi-Fi speed is sluggish or dropping out at this desk. Please verify router AP.',
    ),
    SilentHelpOption(
      id: 'water_clean',
      title: 'Water & Hygiene',
      subtitle: 'RO water refill needed or desk area cleaning',
      icon: Icons.water_drop_outlined,
      color: Color(0xFF0D9488),
      defaultMessage: 'RO water dispenser needs refilling or desk area requires housekeeping attention.',
    ),
    SilentHelpOption(
      id: 'desk_help',
      title: 'Reception Help',
      subtitle: 'Front desk assistance, stationery, or quick query',
      icon: Icons.support_agent_rounded,
      color: Color(0xFFF59E0B),
      defaultMessage: 'Requesting a staff member visit my desk for quick assistance.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedDesk = widget.initialDeskLabel;
    _deskController.text = _selectedDesk;
  }

  @override
  void dispose() {
    _noteController.dispose();
    _deskController.dispose();
    super.dispose();
  }

  Future<void> _submitSilentAlert() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final selectedOption = _options[_selectedOptionIndex];
      final note = _noteController.text.trim();
      final finalDesk = _isCustomDesk ? _deskController.text.trim() : _selectedDesk;
      final finalMessage = note.isNotEmpty ? note : selectedOption.defaultMessage;
      final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      // 1. Persist to Firestore under feedback collection with 'silent_alert' type
      await FirebaseFirestore.instance
          .collection('libraries')
          .doc(widget.libraryId)
          .collection('feedback')
          .add({
        'libraryId': widget.libraryId,
        'studentId': widget.student?.id ?? authUid,
        'studentUserId': authUid,
        'studentName': widget.student?.name ?? 'Enrolled Student',
        'studentPhone': widget.student?.phone ?? '',
        'seatNumber': finalDesk.isNotEmpty ? finalDesk : 'General Zone',
        'category': selectedOption.title,
        'feedbackType': 'silent_alert',
        'status': 'unread',
        'message': finalMessage,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Dispatch real-time alert to Reception / Admin
      AppNotificationService.sendNotification(
        libraryId: widget.libraryId,
        title: '🚨 Quiet Help: ${selectedOption.title}',
        body: 'Desk $finalDesk: $finalMessage',
        type: 'silent_alert',
        targetRole: 'admin',
        actionRoute: Routes.adminFeedback,
      ).ignore();

      HapticFeedback.mediumImpact();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F766E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF5EEAD4), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🤫 Quiet Alert Sent to Reception',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                      Text(
                        'Discreet assistance dispatched to $finalDesk. No need to leave your seat.',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFCCFBF1)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send alert: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedOption = _options[_selectedOptionIndex];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header Banner with Discrete Styling
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withValues(alpha: isDark ? 0.3 : 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.3)),
                      ),
                      child: const Icon(
                        Icons.volume_off_rounded,
                        color: Color(0xFF0D9488),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Quiet Reception Help',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '100% Discrete',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D9488),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Front desk will quietly inspect and resolve this without disrupting you or anyone around you.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Desk Location Pill / Switcher
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.chair_rounded, size: 18, color: Color(0xFF0D9488)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _isCustomDesk
                            ? TextField(
                                controller: _deskController,
                                autofocus: true,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  hintText: 'Enter seat/zone (e.g. Desk #12, Zone B)',
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Your Location',
                                    style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    _selectedDesk,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _isCustomDesk = !_isCustomDesk;
                            if (!_isCustomDesk) {
                              _selectedDesk = _deskController.text.trim().isNotEmpty
                                  ? _deskController.text.trim()
                                  : widget.initialDeskLabel;
                            }
                          });
                        },
                        child: Text(
                          _isCustomDesk ? 'Done' : 'Change',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Issue Category Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Text(
                  'Select Disturbance / Assistance Needed',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
              ),

              // Category Option Tiles
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final opt = _options[idx];
                  final isSelected = _selectedOptionIndex == idx;

                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedOptionIndex = idx);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? opt.color.withValues(alpha: isDark ? 0.2 : 0.09)
                            : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? opt.color.withValues(alpha: 0.6)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: opt.color.withValues(alpha: isSelected ? 0.2 : 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(opt.icon, color: opt.color, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  opt.title,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 13,
                                    color: isSelected ? opt.color : null,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  opt.subtitle,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: isSelected ? opt.color : Colors.grey.withValues(alpha: 0.5),
                            size: 19,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              // Optional Detail Note
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _noteController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    labelText: 'Optional Short Note',
                    hintText: 'e.g. Someone is on call near the back corner...',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Submit Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: selectedOption.color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isSubmitting ? null : _submitSilentAlert,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _isSubmitting
                          ? 'Dispatching Help...'
                          : '🤫 Send Discrete Alert to Reception',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
