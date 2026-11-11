import 'package:flutter/material.dart';
import 'package:study_library/core/theme/app_decorations.dart';
import 'package:study_library/core/widgets/cozy_pressable.dart';

/// Flagship-grade grouped island card for settings, profile, and system menu rows.
/// Inspired by Apple iOS 18 Inset Grouped design and Samsung One UI 7 Island cards.
class CozySettingsCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;
  final Widget? headerTrailing;

  const CozySettingsCard({
    super.key,
    this.title,
    required this.children,
    this.margin,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  ?headerTrailing,
                ],
              ),
            ),
          ],
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E28) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
                width: 1.0,
              ),
              boxShadow: AppDecorations.softShadows(context, elevation: 0.6),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tactile, squircle-badged settings tile with calibrated micro-press physics.
class CozySettingsTile extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final Color? iconColor;
  final Color? iconBgColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double pressScale;

  const CozySettingsTile({
    super.key,
    this.icon,
    this.leading,
    this.iconColor,
    this.iconBgColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.pressScale = 0.985,
  }) : assert(icon != null || leading != null, 'Either icon or leading must be provided');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final resolvedIconColor = iconColor ?? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569));
    final resolvedIconBgColor = iconBgColor ??
        (iconColor != null
            ? iconColor!.withValues(alpha: isDark ? 0.22 : 0.12)
            : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)));

    final leadingWidget = leading ??
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: resolvedIconBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: resolvedIconColor),
        );

    final rowContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          leadingWidget,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: -0.2,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing ??
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
        ],
      ),
    );

    if (onTap == null) {
      return Material(
        color: Colors.transparent,
        child: rowContent,
      );
    }

    return CozyPressable(
      onTap: onTap!,
      pressScale: pressScale,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: (iconColor ?? theme.colorScheme.primary).withValues(alpha: 0.08),
          highlightColor: (iconColor ?? theme.colorScheme.primary).withValues(alpha: 0.04),
          child: rowContent,
        ),
      ),
    );
  }
}

/// Precise inset divider matching iOS Inset Grouped & One UI 7 list standards.
/// Insets perfectly to align with the tile's text column (68px).
class CozySettingsDivider extends StatelessWidget {
  final double indent;
  final double endIndent;

  const CozySettingsDivider({
    super.key,
    this.indent = 68,
    this.endIndent = 16,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 0.7,
      indent: indent,
      endIndent: endIndent,
      color: isDark
          ? Colors.white.withValues(alpha: 0.07)
          : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
    );
  }
}
