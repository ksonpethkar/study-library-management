import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study_library/core/widgets/not_found_screen.dart';

void main() {
  testWidgets('NotFoundScreen renders friendly branded 404 UI', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: NotFoundScreen(
            uri: null,
            error: null,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify key UI elements exist
    expect(find.text('The Cozy Corner'), findsOneWidget);
    expect(find.text('404 • Page Not Found'), findsOneWidget);
    expect(find.text('Lost in the Study Hall?'), findsOneWidget);
    expect(find.text('Return to Home / Dashboard'), findsOneWidget);
    expect(find.text('Go to Login'), findsOneWidget);
    expect(find.byIcon(Icons.explore_off_rounded), findsOneWidget);
  });

  testWidgets('NotFoundScreen shows diagnostics when error is provided', (tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final testError = Exception('Simulated test route failure');
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: NotFoundScreen(
            uri: Uri.parse('/test/invalid/route'),
            error: testError,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify path chip
    expect(find.text('/test/invalid/route'), findsOneWidget);
    expect(find.text('View Technical Diagnostics'), findsOneWidget);

    // Tap to expand diagnostics
    await tester.ensureVisible(find.text('View Technical Diagnostics'));
    await tester.tap(find.text('View Technical Diagnostics'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Simulated test route failure'), findsOneWidget);
    expect(find.text('Hide Diagnostics'), findsOneWidget);
  });
}
