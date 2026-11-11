import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Inspect Obsidian Noir ColorScheme', () {
    final light = ColorScheme.fromSeed(seedColor: const Color(0xFF18181B), brightness: Brightness.light);
    final dark = ColorScheme.fromSeed(seedColor: const Color(0xFF18181B), brightness: Brightness.dark);

    print('=== LIGHT SCHEME ===');
    print('primary: ${light.primary.value.toRadixString(16)}');
    print('onPrimary: ${light.onPrimary.value.toRadixString(16)}');
    print('primaryContainer: ${light.primaryContainer.value.toRadixString(16)}');
    print('onPrimaryContainer: ${light.onPrimaryContainer.value.toRadixString(16)}');
    print('secondary: ${light.secondary.value.toRadixString(16)}');
    print('onSecondary: ${light.onSecondary.value.toRadixString(16)}');
    print('secondaryContainer: ${light.secondaryContainer.value.toRadixString(16)}');
    print('onSecondaryContainer: ${light.onSecondaryContainer.value.toRadixString(16)}');
    print('surface: ${light.surface.value.toRadixString(16)}');
    print('onSurface: ${light.onSurface.value.toRadixString(16)}');
    print('onSurfaceVariant: ${light.onSurfaceVariant.value.toRadixString(16)}');
    print('surfaceContainer: ${light.surfaceContainer.value.toRadixString(16)}');
    print('surfaceContainerHighest: ${light.surfaceContainerHighest.value.toRadixString(16)}');
    print('outline: ${light.outline.value.toRadixString(16)}');
    print('outlineVariant: ${light.outlineVariant.value.toRadixString(16)}');

    print('=== DARK SCHEME ===');
    print('primary: ${dark.primary.value.toRadixString(16)}');
    print('onPrimary: ${dark.onPrimary.value.toRadixString(16)}');
    print('primaryContainer: ${dark.primaryContainer.value.toRadixString(16)}');
    print('onPrimaryContainer: ${dark.onPrimaryContainer.value.toRadixString(16)}');
    print('surface: ${dark.surface.value.toRadixString(16)}');
    print('onSurface: ${dark.onSurface.value.toRadixString(16)}');
    print('onSurfaceVariant: ${dark.onSurfaceVariant.value.toRadixString(16)}');
    print('outline: ${dark.outline.value.toRadixString(16)}');
  });
}
