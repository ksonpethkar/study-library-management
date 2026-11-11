import 'package:flutter/material.dart';

/// Leading-Brand Squircle Geometry & Curvature Constants (Apple HIG / Samsung One UI 7).
class AppCornerCurves {
  AppCornerCurves._();

  /// Crisp button squircle radius (14px).
  static const double button = 14.0;

  /// Expressive card squircle radius (20px).
  static const double card = 20.0;

  /// Large modal / bottom sheet squircle radius (28px).
  static const double sheet = 28.0;

  /// Dialog squircle radius (24px).
  static const double dialog = 24.0;

  /// Pill badge radius (999px).
  static const double pill = 999.0;

  /// Reusable RoundedRectangleBorder with continuous squircle corners.
  static RoundedRectangleBorder cardShape({Color? borderColor, double borderWidth = 1.0}) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(card),
      side: borderColor != null
          ? BorderSide(color: borderColor, width: borderWidth)
          : BorderSide.none,
    );
  }

  /// Reusable button shape.
  static RoundedRectangleBorder buttonShape({Color? borderColor, double borderWidth = 1.0}) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(button),
      side: borderColor != null
          ? BorderSide(color: borderColor, width: borderWidth)
          : BorderSide.none,
    );
  }
}

/// Leading-Brand Visual Softness & Tonal Elevation (Linear / Arc / iOS).
class AppDecorations {
  AppDecorations._();

  /// Dual-layer ambient diffuse shadow.
  /// Eliminates muddy black dropshadows with a 2-stage optical elevation:
  /// 1. Crisp hairline contact shadow at the base
  /// 2. Soft, warm ambient spread shadow that simulates soft diffuse room lighting.
  static List<BoxShadow> softShadows(BuildContext context, {double elevation = 1.0}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (elevation <= 0) return const [];

    final contactOpacity = isDark ? 0.20 : 0.025;
    final ambientOpacity = isDark ? 0.16 : 0.045;

    return [
      // 1. Contact shadow (Crispness & Grounding)
      BoxShadow(
        color: Colors.black.withValues(alpha: contactOpacity * elevation),
        blurRadius: 4.0 * elevation,
        offset: Offset(0, 1.0 * elevation),
      ),
      // 2. Ambient diffuse shadow (Softness & Spatial Float)
      BoxShadow(
        color: const Color(0xFF5D4037).withValues(alpha: ambientOpacity * elevation),
        blurRadius: 22.0 * elevation,
        offset: Offset(0, 7.0 * elevation),
      ),
    ];
  }

  /// Standard soft Bento Card decoration with squircle radius and hairline micro-border.
  static BoxDecoration softCard(
    BuildContext context, {
    Color? backgroundColor,
    Color? borderColor,
    double radius = AppCornerCurves.card,
    double elevation = 1.0,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BoxDecoration(
      color: backgroundColor ??
          (isDark ? theme.colorScheme.surfaceContainerLow : Colors.white),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ??
            (isDark
                ? Colors.white.withValues(alpha: 0.08)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
        width: 1.0,
      ),
      boxShadow: softShadows(context, elevation: elevation),
    );
  }

  /// Frosted glass container decoration for floating headers, bottom bars, and floating pills.
  static BoxDecoration frostedGlass(
    BuildContext context, {
    Color? tintColor,
    Color? borderColor,
    double radius = AppCornerCurves.card,
    double opacity = 0.82,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final baseColor = tintColor ??
        (isDark ? const Color(0xFF131B2E) : const Color(0xFFFFFFFF));

    return BoxDecoration(
      color: baseColor.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ??
            (isDark
                ? Colors.white.withValues(alpha: 0.12)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.45)),
        width: 1.0,
      ),
      boxShadow: softShadows(context, elevation: 0.8),
    );
  }
}
