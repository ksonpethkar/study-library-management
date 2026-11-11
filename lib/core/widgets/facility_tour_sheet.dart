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

  /// Automatically checks if the user has completed the tour and presents it on first launch.
  static Future<void> checkAndShow(BuildContext context, {bool force = false}) async {
    try {
      if (!force) {
        final prefs = await SharedPreferences.getInstance();
        final completed = prefs.getBool(_prefTourKey) ?? false;
        if (completed) return;
      }

      await Future.delayed(const Duration(milliseconds: 800));
      if (!context.mounted) return;

      await show(context, force: force);
    } catch (_) {}
  }

  /// Displays the interactive 5-step facility tour modal.
  static Future<void> show(BuildContext context, {bool force = false}) async {
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const FacilityTourSheet(),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefTourKey, true);
    } catch (_) {}
  }

  @override
  State<FacilityTourSheet> createState() => _FacilityTourSheetState();
}

class _FacilityTourSheetState extends State<FacilityTourSheet> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 5;

  final List<_TourStepData> _steps = const [
    _TourStepData(
      stepNumber: 1,
      badge: 'RESERVED WORKSPACE',
      badgeColor: Color(0xFF2563EB),
      icon: Icons.chair_rounded,
      iconColor: Color(0xFF2563EB),
      title: 'Dedicated Desk & Shift',
      subtitle: 'Your personal, quiet study zone every day',
      items: [
        _TourFeatureItem(
          icon: Icons.access_time_filled_rounded,
          title: 'Flexible Study Shifts',
          description: 'Morning, Evening, or 24×7 Full Day. Your reserved seat is guaranteed during your designated hours.',
        ),
        _TourFeatureItem(
          icon: Icons.event_seat_rounded,
          title: 'Fixed Reserved Desk',
          description: 'Your assigned seat number is exclusively yours. Leave books safely without worry of seat loss.',
        ),
        _TourFeatureItem(
          icon: Icons.swap_horiz_rounded,
          title: 'Easy Seat Transfers',
          description: 'Want a window desk or a quieter corner? You can request a seat change once every 30 days via the app.',
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
          title: 'Contactless Check-In',
          description: 'Show your personal student QR pass at the entrance scanner when arriving for automatic check-in.',
        ),
        _TourFeatureItem(
          icon: Icons.wifi_off_rounded,
          title: '100% Offline Ready',
          description: 'Your pass is saved locally on your phone. It scans reliably even without an active internet connection.',
        ),
        _TourFeatureItem(
          icon: Icons.security_rounded,
          title: 'Protected Identity',
          description: 'Your pass contains verified membership security to prevent unauthorized access and protect students.',
        ),
      ],
    ),
    _TourStepData(
      stepNumber: 3,
      badge: 'COMFORT & FOCUS',
      badgeColor: Color(0xFF7C3AED),
      icon: Icons.wifi_rounded,
      iconColor: Color(0xFF7C3AED),
      title: '5G Wi-Fi & Amenities',
      subtitle: 'Premium facilities designed for long study marathons',
      items: [
        _TourFeatureItem(
          icon: Icons.speed_rounded,
          title: 'High-Speed Optical Fiber',
          description: 'High-speed dual-band Wi-Fi optimized for streaming video lectures, test series, and PDFs without lag.',
        ),
        _TourFeatureItem(
          icon: Icons.power_rounded,
          title: 'Power at Every Desk',
          description: 'Dedicated electrical plug points and mobile chargers at every single study cabin.',
        ),
        _TourFeatureItem(
          icon: Icons.ac_unit_rounded,
          title: 'Silent Climate Control',
          description: 'Chilled air-conditioned study halls with ergonomic cushioned chairs built for long sitting hours.',
        ),
        _TourFeatureItem(
          icon: Icons.local_drink_rounded,
          title: 'Clean RO Water & Lockers',
          description: 'Free purified cold drinking water station and lockable personal lockers for your heavy reference books.',
        ),
      ],
    ),
    _TourStepData(
      stepNumber: 4,
      badge: 'COMMUNITY CODE',
      badgeColor: Color(0xFFD97706),
      icon: Icons.volume_off_rounded,
      iconColor: Color(0xFFD97706),
      title: 'Silent Study Code',
      subtitle: 'Maintaining an environment of deep focus and mutual respect',
      items: [
        _TourFeatureItem(
          icon: Icons.volume_mute_rounded,
          title: 'Strict Hall Silence',
          description: 'Keep your mobile on silent or vibration mode. Discussions and whisperings are strictly prohibited in study halls.',
        ),
        _TourFeatureItem(
          icon: Icons.phone_in_talk_rounded,
          title: 'Designated Calling Zone',
          description: 'Please step outside into the reception area or phone booths for all urgent phone calls.',
        ),
        _TourFeatureItem(
          icon: Icons.cleaning_services_rounded,
          title: 'Clean Desk Etiquette',
          description: 'Keep your study desk tidy and dispose of disposable water bottles or coffee cups in designated bins.',
        ),
      ],
    ),
    _TourStepData(
      stepNumber: 5,
      badge: 'EASY PAYMENTS',
      badgeColor: Color(0xFFEA580C),
      icon: Icons.receipt_long_rounded,
      iconColor: Color(0xFFEA580C),
      title: '1-Tap Renewals & Receipts',
      subtitle: 'Hassle-free fee payments and instant digital invoices',
      items: [
        _TourFeatureItem(
          icon: Icons.notifications_active_rounded,
          title: 'Advance Due Alerts',
          description: 'Receive a polite reminder 3 days prior to membership expiry with your exact payable amount.',
        ),
        _TourFeatureItem(
          icon: Icons.shield_rounded,
          title: 'Courtesy Buffer Days',
          description: 'Busy with an exam? Your reserved desk remains protected under grace days before being released.',
        ),
        _TourFeatureItem(
          icon: Icons.qr_code_scanner_rounded,
          title: '1-Tap UPI & PDF Receipts',
          description: 'Pay instantly via GPay, PhonePe, Paytm, or BHIM UPI and immediately download your stamped fee receipt.',
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
    final maxHeight = media.size.height * 0.88;

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
                    // Top Skip Button
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: Colors.grey.shade600,
                      ),
                      onPressed: _finishTour,
                      child: const Text('Skip Tour', style: TextStyle(fontWeight: FontWeight.w600)),
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
                              _currentPage == _totalPages - 1 ? 'Get Started' : 'Next',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              _currentPage == _totalPages - 1
                                  ? Icons.check_circle_rounded
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
