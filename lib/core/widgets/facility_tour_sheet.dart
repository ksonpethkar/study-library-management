import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Interactive, illustrated 5-step facility onboarding tour for students.
/// Covers:
/// 1. Dedicated Desk & Study Shift
/// 2. Digital QR Gate Pass (Offline touchless access)
/// 3. High-Speed 5G Wi-Fi & Amenities
/// 4. Silent Study Code & Community Ethics
/// 5. Fee Receipts & 1-Tap UPI Renewal
class FacilityTourSheet extends StatefulWidget {
  final VoidCallback? onComplete;

  const FacilityTourSheet({super.key, this.onComplete});

  static const String _prefTourKey = 'student_facility_tour_completed';
  static bool _isTourOpen = false;
  static bool _hasCheckedInSession = false;

  /// Automatically checks if the user has completed the tour and presents it on first launch.
  static Future<void> checkAndShow(BuildContext context, {bool force = false}) async {
    if (_isTourOpen) return;
    if (!force && _hasCheckedInSession) return;
    _hasCheckedInSession = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!force) {
        final completed = prefs.getBool(_prefTourKey) ?? false;
        if (completed) return;
      }

      // Mark completed immediately so subsequent fast rebuilds or race conditions never re-trigger
      await prefs.setBool(_prefTourKey, true);

      await Future.delayed(const Duration(milliseconds: 600));
      if (!context.mounted || _isTourOpen) return;

      await show(context, force: force);
    } catch (_) {}
  }

  /// Displays the interactive 5-step facility tour modal.
  static Future<void> show(BuildContext context, {bool force = false}) async {
    if (_isTourOpen) return;
    _isTourOpen = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefTourKey, true);
    } catch (_) {}

    try {
      if (!context.mounted) return;
      await showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const FacilityTourSheet(),
      );
    } finally {
      _isTourOpen = false;
    }
  }

  @override
  State<FacilityTourSheet> createState() => _FacilityTourSheetState();
}

class _FacilityTourSheetState extends State<FacilityTourSheet> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 3;

  final List<_TourStepData> _steps = const [
    _TourStepData(
      stepNumber: 1,
      badge: 'RESERVED WORKSPACE',
      badgeColor: Color(0xFF2563EB),
      icon: Icons.chair_rounded,
      iconColor: Color(0xFF2563EB),
      title: 'Dedicated Desk & Shift',
      subtitle: 'Your personal, quiet study zone reserved exclusively for you',
      items: [
        _TourFeatureItem(
          icon: Icons.event_seat_rounded,
          title: 'Fixed Reserved Desk',
          description: 'Your assigned cabin is yours during your shift. Leave reference books safely without worry of seat loss.',
        ),
        _TourFeatureItem(
          icon: Icons.access_time_filled_rounded,
          title: 'Guaranteed Study Shifts',
          description: 'Morning, Evening, or 24×7 Full Day. Peace of mind with your seat reserved during your designated hours.',
        ),
        _TourFeatureItem(
          icon: Icons.swap_horiz_rounded,
          title: 'Easy Desk Transfers',
          description: 'Need a window desk or a quieter corner? Request a seat change directly in the app once every 30 days.',
        ),
      ],
    ),
    _TourStepData(
      stepNumber: 2,
      badge: 'TOUCHLESS ENTRY',
      badgeColor: Color(0xFF059669),
      icon: Icons.qr_code_2_rounded,
      iconColor: Color(0xFF059669),
      title: 'Digital QR Gate Pass',
      subtitle: 'Instant gate and turnstile entry with zero queues',
      items: [
        _TourFeatureItem(
          icon: Icons.touch_app_rounded,
          title: 'Fast Contactless Check-In',
          description: 'Flash your personal student QR pass at the entrance scanner for automatic, hands-free check-in.',
        ),
        _TourFeatureItem(
          icon: Icons.wifi_off_rounded,
          title: '100% Offline Ready',
          description: 'Pass is saved locally on your phone. It scans reliably even in basement reading halls without active internet.',
        ),
        _TourFeatureItem(
          icon: Icons.query_builder_rounded,
          title: 'Automated Study Streaks',
          description: 'Automatically tracks your daily study hours and consistency streaks to help maintain your preparation momentum.',
        ),
      ],
    ),
    _TourStepData(
      stepNumber: 3,
      badge: 'AMENITIES & PAYMENTS',
      badgeColor: Color(0xFF7C3AED),
      icon: Icons.bolt_rounded,
      iconColor: Color(0xFF7C3AED),
      title: '5G Wi-Fi, Silence & 1-Tap Pay',
      subtitle: 'Premium facilities and hassle-free fee renewals',
      items: [
        _TourFeatureItem(
          icon: Icons.wifi_rounded,
          title: 'High-Speed 5G Optical Fiber',
          description: 'Dual-band Wi-Fi optimized for lecture streaming, test series & PDFs, with power charging sockets at every desk.',
        ),
        _TourFeatureItem(
          icon: Icons.volume_mute_rounded,
          title: 'Strict Silent Study Ethics',
          description: 'Silent study halls for deep focus, with a designated calling area in reception for urgent phone calls.',
        ),
        _TourFeatureItem(
          icon: Icons.receipt_long_rounded,
          title: '1-Tap UPI Renewals & Receipts',
          description: 'Pay via GPay, PhonePe, or Paytm with automatic grace day buffers and instant stamped fee receipt downloads.',
        ),
      ],
    ),
  ];

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishTour();
    }
  }

  void _prevPage() {
    HapticFeedback.lightImpact();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _finishTour() {
    HapticFeedback.mediumImpact();
    widget.onComplete?.call();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    // Reserve space for the system navigation bar so the bottom controls
    // are never hidden behind the device's gesture / button nav bar.
    final bottomInset = media.viewPadding.bottom;
    final maxHeight = media.size.height * 0.88 - bottomInset;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: maxHeight,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Drag Handle & Header ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _steps[_currentPage].badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _steps[_currentPage].badgeColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        'STEP ${_currentPage + 1} OF $_totalPages',
                        style: TextStyle(
                          color: _steps[_currentPage].badgeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Top Skip and Close Buttons (Instant 1-Tap Dismiss)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          onPressed: _finishTour,
                          child: const Text('Skip Tour', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          tooltip: 'Close Tour',
                          style: IconButton.styleFrom(
                            backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(6),
                          ),
                          onPressed: _finishTour,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Carousel Step View ────────────────────────────────────────
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _totalPages,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  itemBuilder: (context, index) {
                    final step = _steps[index];
                    return _buildStepContent(step, theme, isDark);
                  },
                ),
              ),

              // ── Bottom Controls & Progress Dots ───────────────────────────
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Back Button (hidden on first page)
                      if (_currentPage > 0)
                        IconButton.filledTonal(
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: 'Previous Step',
                          onPressed: _prevPage,
                        )
                      else
                        const SizedBox(width: 48),

                      const Spacer(),

                      // Animated Progress Dots
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_totalPages, (i) {
                          final isActive = i == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 22 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? _steps[_currentPage].badgeColor
                                  : (isDark ? Colors.white24 : Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),

                      const Spacer(),

                      // Next / Finish Button
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _steps[_currentPage].badgeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _nextPage,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentPage == _totalPages - 1 ? 'Got It, Let\'s Study! 🚀' : 'Next',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              _currentPage == _totalPages - 1
                                  ? Icons.rocket_launch_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(_TourStepData step, ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      children: [
        // Hero Icon with Gradient Glow
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: step.iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: step.iconColor.withValues(alpha: 0.25),
                width: 2,
              ),
            ),
            child: Icon(step.icon, color: step.iconColor, size: 36),
          ),
        ),
        const SizedBox(height: 16),

        // Title and Subtitle
        Center(
          child: Text(
            step.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            step.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Items list
        ...step.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: step.iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: step.iconColor, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.description,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}

class _TourStepData {
  final int stepNumber;
  final String badge;
  final Color badgeColor;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<_TourFeatureItem> items;

  const _TourStepData({
    required this.stepNumber,
    required this.badge,
    required this.badgeColor,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.items,
  });
}

class _TourFeatureItem {
  final IconData icon;
  final String title;
  final String description;

  const _TourFeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
