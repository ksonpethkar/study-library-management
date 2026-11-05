import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// A sleek, branded, Cozy Corner 404 & Route Recovery Screen.
/// Replaces raw GoRouter exception screens with a friendly, helpful interface,
/// automatic recovery countdown, role-aware navigation buttons, and collapsible diagnostics.
class NotFoundScreen extends ConsumerStatefulWidget {
  final Uri? uri;
  final Exception? error;

  const NotFoundScreen({
    super.key,
    this.uri,
    this.error,
  });

  @override
  ConsumerState<NotFoundScreen> createState() => _NotFoundScreenState();
}

class _NotFoundScreenState extends ConsumerState<NotFoundScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  Timer? _countdownTimer;
  int _secondsRemaining = 5;
  bool _isAutoRedirectPaused = false;
  bool _showTechnicalDetails = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();

    // Start 5-second auto-redirect countdown
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_isAutoRedirectPaused) return;

      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
        } else {
          timer.cancel();
          _navigateHome();
        }
      });
    });
  }

  void _navigateHome() {
    final role = ref.read(userRoleProvider);
    if (!mounted) return;

    if (role == AppUserRole.admin) {
      context.go(Routes.adminHome);
    } else if (role == AppUserRole.student) {
      context.go(Routes.studentHome);
    } else {
      context.go(Routes.splash);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final attemptedPath = widget.uri?.toString() ?? '/unknown';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Go Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              _navigateHome();
            }
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.local_library_rounded, size: 18, color: primaryColor),
            ),
            const SizedBox(width: 8),
            Text(
              'The Cozy Corner',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ambient Glowing Icon Badge
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor.withValues(alpha: 0.12),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.25),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.explore_off_rounded,
                            size: 48,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Status Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 15, color: Colors.amber),
                            SizedBox(width: 6),
                            Text(
                              '404 • Page Not Found',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.amber,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Headline
                      Text(
                        'Lost in the Study Hall?',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Explanation
                      Text(
                        'The page or study section you are looking for has moved, expired, or does not exist.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Monospace Attempted Path Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.3)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.link_off_rounded, size: 16, color: Colors.grey.shade500),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                attemptedPath,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 15),
                              tooltip: 'Copy Path',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: attemptedPath));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Path copied to clipboard'),
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Auto-redirect timer card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: primaryColor.withValues(alpha: 0.12)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.timer_outlined, size: 16, color: primaryColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _isAutoRedirectPaused
                                        ? 'Auto-redirect paused'
                                        : 'Redirecting to home in $_secondsRemaining seconds...',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isAutoRedirectPaused = !_isAutoRedirectPaused;
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  child: Text(
                                    _isAutoRedirectPaused ? 'Resume' : 'Pause',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            if (!_isAutoRedirectPaused) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _secondsRemaining / 5.0,
                                  backgroundColor: primaryColor.withValues(alpha: 0.15),
                                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                  minHeight: 4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Action Buttons
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _navigateHome,
                          icon: const Icon(Icons.home_rounded, size: 19),
                          label: const Text(
                            'Return to Home / Dashboard',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                          ),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: () => context.go(Routes.login),
                          icon: const Icon(Icons.login_rounded, size: 18),
                          label: const Text(
                            'Go to Login',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),

                      // Optional collapsible technical details (for admins/devs)
                      if (widget.error != null) ...[
                        const SizedBox(height: 20),
                        Divider(color: isDark ? Colors.white10 : Colors.black12),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _showTechnicalDetails = !_showTechnicalDetails;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _showTechnicalDetails
                                      ? Icons.expand_less_rounded
                                      : Icons.bug_report_outlined,
                                  size: 15,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _showTechnicalDetails
                                      ? 'Hide Diagnostics'
                                      : 'View Technical Diagnostics',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showTechnicalDetails) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? Colors.white10 : Colors.black12,
                              ),
                            ),
                            child: SelectableText(
                              widget.error.toString(),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11.5,
                                color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
