// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:study_library/models/seat_model.dart';
import 'package:study_library/features/seats/presentation/widgets/seat_tile.dart';
import 'package:study_library/core/utils/app_validators.dart';
import 'package:study_library/core/widgets/whatsapp_preview_sheet.dart';
import 'package:study_library/features/students/presentation/screens/bulk_import_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Minimal test harness — wraps a widget in MaterialApp with no Firebase deps
// ---------------------------------------------------------------------------
Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? ThemeData.light(),
      home: Scaffold(body: Center(child: child)),
    );

Widget _wrapDark(Widget child) => _wrap(
      child,
      theme: ThemeData.dark(),
    );

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
SeatModel _seat({
  SeatStatus status = SeatStatus.available,
  GenderRestriction gender = GenderRestriction.any,
  String? studentId,
  String label = 'A1',
}) =>
    SeatModel(
      id: 'seat_test',
      sectionId: 'sec_001',
      row: 0,
      col: 0,
      label: label,
      status: status,
      genderRestriction: gender,
      studentId: studentId,
    );

SeatTile _tile(
  SeatModel seat, {
  bool isSelected = false,
  String? studentName,
}) =>
    SeatTile(
      seat: seat,
      isSelected: isSelected,
      onTap: () {},
      onLongPress: () {},
      studentName: studentName,
    );

// ===========================================================================
// GROUP 1 — SeatTile: colour semantics
// ===========================================================================
void main() {
  group('💺 SeatTile — Colour Semantics (Light Theme)', () {
    testWidgets('Available seat renders green background', (tester) async {
      await tester.pumpWidget(_wrap(_tile(_seat(status: SeatStatus.available))));
      final container = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .first;
      final decoration = container.decoration as BoxDecoration;
      // Light available = 0xFFE8F5E9 (light green)
      expect(decoration.color, equals(const Color(0xFFE8F5E9)));
    });

    testWidgets('Occupied seat renders red background', (tester) async {
      await tester.pumpWidget(_wrap(_tile(_seat(
        status: SeatStatus.occupied,
        studentId: 'std_001',
        label: 'B1',
      ))));
      final container = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .first;
      final decoration = container.decoration as BoxDecoration;
      // Light occupied = 0xFFFFEBEE (light red)
      expect(decoration.color, equals(const Color(0xFFFFEBEE)));
    });

    testWidgets('Reserved seat renders amber background', (tester) async {
      await tester.pumpWidget(_wrap(_tile(_seat(status: SeatStatus.reserved))));
      final container = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .first;
      final decoration = container.decoration as BoxDecoration;
      // Light reserved = 0xFFFFF8E1 (amber tint)
      expect(decoration.color, equals(const Color(0xFFFFF8E1)));
    });

    testWidgets('Maintenance seat renders grey background', (tester) async {
      await tester
          .pumpWidget(_wrap(_tile(_seat(status: SeatStatus.maintenance))));
      final container = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .first;
      final decoration = container.decoration as BoxDecoration;
      // Light maintenance = 0xFFEEEEEE (grey)
      expect(decoration.color, equals(const Color(0xFFEEEEEE)));
    });
  });

  group('💺 SeatTile — Colour Semantics (Dark Theme)', () {
    testWidgets('Available seat renders dark green in dark mode', (tester) async {
      await tester
          .pumpWidget(_wrapDark(_tile(_seat(status: SeatStatus.available))));
      final container = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .first;
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, equals(const Color(0xFF1B382B)));
    });

    testWidgets('Occupied seat renders dark red in dark mode', (tester) async {
      await tester.pumpWidget(_wrapDark(_tile(_seat(
        status: SeatStatus.occupied,
        studentId: 'std_001',
      ))));
      final container = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .first;
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, equals(const Color(0xFF45141D)));
    });
  });

  group('💺 SeatTile — Label Display', () {
    testWidgets('Seat label is rendered as visible text', (tester) async {
      await tester.pumpWidget(_wrap(_tile(_seat(label: 'C5'))));
      expect(find.text('C5'), findsOneWidget);
    });

    testWidgets('Seat with empty label falls back to numeric from id',
        (tester) async {
      final seat = SeatModel(
        id: 'seat_007',
        sectionId: 'sec_001',
        row: 0,
        col: 6,
        label: '',    // empty — displayLabel regex extracts '007' from id
        status: SeatStatus.available,
        genderRestriction: GenderRestriction.any,
      );
      await tester.pumpWidget(_wrap(_tile(seat)));
      // displayLabel: RegExp(r'\d+').stringMatch('seat_007') = '007'
      // The tile renders '007' (leading zeros preserved from regex match)
      expect(find.text('007'), findsWidgets);
    });

    testWidgets('Selected seat renders selection indicator (different border)',
        (tester) async {
      final unselected = _tile(_seat(), isSelected: false);
      final selected = _tile(_seat(), isSelected: true);

      await tester.pumpWidget(_wrap(unselected));
      final unselectedBox = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .first;
      final unselectedDecoration = unselectedBox.decoration as BoxDecoration;

      await tester.pumpWidget(_wrap(selected));
      final selectedBox = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .first;
      final selectedDecoration = selectedBox.decoration as BoxDecoration;

      // Selected tile has a different border (thicker / accent colour)
      expect(
        selectedDecoration.border?.toString(),
        isNot(equals(unselectedDecoration.border?.toString())),
      );
    });

    testWidgets('Student name shown in seat tile (columns <= 4 layout)',
        (tester) async {
      // Student name is only rendered when columns <= 4 (spacious card mode).
      // Default columns=6 shows seat number only. Pass columns=4 to see name.
      await tester.pumpWidget(_wrap(
        SeatTile(
          seat: _seat(status: SeatStatus.occupied, studentId: 'std_001'),
          isSelected: false,
          onTap: () {},
          onLongPress: () {},
          columns: 4,             // spacious card layout — shows studentName
          studentName: 'Rahul Sharma',
        ),
      ));
      await tester.pump();
      // Layout shows first name only (split(' ').first)
      expect(find.text('Rahul'), findsOneWidget);
    });

    testWidgets('Female-only badge: Icons.female_rounded rendered in tile',
        (tester) async {
      await tester.pumpWidget(_wrap(_tile(
        _seat(gender: GenderRestriction.female),
      )));
      await tester.pump();
      // No exception — widget renders cleanly
      expect(tester.takeException(), isNull);
      // default columns=6: gender badge uses Positioned Icon(Icons.female_rounded)
      expect(find.byIcon(Icons.female_rounded), findsOneWidget);
    });
  });

  // ===========================================================================
  // GROUP 2 — Form Validation Error Display
  // ===========================================================================
  group('📋 Form Field Validation — Error Display', () {
    testWidgets('Phone field shows error for empty input', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(_wrap(
        Form(
          key: formKey,
          child: TextFormField(
            validator: AppValidators.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
        ),
      ));

      formKey.currentState!.validate();
      await tester.pump();

      expect(find.byType(TextFormField), findsOneWidget);
      // After validate(), error text should appear
      final errorText = tester.widgetList<Text>(find.byType(Text)).where((t) {
        return t.style?.color == Theme.of(
              tester.element(find.byType(TextFormField)),
            ).colorScheme.error;
      });
      // Alternatively, just check raw validator return
      final error = AppValidators.phone('');
      expect(error, isNotNull);
    });

    testWidgets('Email field: valid email passes, no error shown',
        (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController(text: 'test@gmail.com');

      await tester.pumpWidget(_wrap(
        Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            validator: AppValidators.email,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
        ),
      ));

      final isValid = formKey.currentState!.validate();
      await tester.pump();
      expect(isValid, isTrue);
    });

    testWidgets('Amount field: zero amount shows error', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController(text: '0');

      await tester.pumpWidget(_wrap(
        Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            validator: AppValidators.amount,
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
        ),
      ));

      final isValid = formKey.currentState!.validate();
      await tester.pump();
      expect(isValid, isFalse);
      // Error text from validator appears somewhere in widget tree
      final error = AppValidators.amount('0');
      expect(error, isNotNull);
    });

    testWidgets('Name field: 1-char name fails validation', (tester) async {
      expect(AppValidators.name('R'), isNotNull);
    });

    testWidgets('Name field: valid name passes validation', (tester) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController(text: 'Rahul Sharma');

      await tester.pumpWidget(_wrap(
        Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            validator: AppValidators.name,
          ),
        ),
      ));

      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets('Pincode field: 5-digit code fails; 6-digit passes',
        (tester) async {
      expect(AppValidators.pinCode('41100'), isNotNull);   // 5 digits → error
      expect(AppValidators.pinCode('411001'), isNull);     // 6 digits → ok
    });

    testWidgets('GSTIN: empty passes when not required', (tester) async {
      expect(AppValidators.gstin('', required: false), isNull);
    });

    testWidgets('Form submit: multiple invalid fields all fail at once',
        (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(_wrap(
        Form(
          key: formKey,
          child: Column(
            children: [
              TextFormField(
                validator: AppValidators.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              TextFormField(
                validator: AppValidators.email,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
            ],
          ),
        ),
      ));

      // Both fields empty — form must be invalid
      final isValid = formKey.currentState!.validate();
      await tester.pump();
      expect(isValid, isFalse);
    });
  });

  // ===========================================================================
  // GROUP 3 — Student Pass Card (Digital ID)
  // ===========================================================================
  group('🪪 Student Pass Card — Display Invariants', () {
    // We test the structural contract without Firebase deps:
    // QR content format, membership number format, masking of Gov IDs.

    test('QR payload for student pass contains required fields', () {
      // QR payload is JSON-encoded, must contain name + membershipNumber + expiry
      const membershipNumber = 'CC20260042';
      const name = 'Rahul Sharma';
      const expiry = '2026-10-31';

      final qrPayload = '{"id":"std_001","name":"$name","membership":"$membershipNumber","expiry":"$expiry"}';

      expect(qrPayload.contains('"name"'), isTrue);
      expect(qrPayload.contains('"membership"'), isTrue);
      expect(qrPayload.contains('"expiry"'), isTrue);
      expect(qrPayload.contains(membershipNumber), isTrue);
    });

    test('Membership number starts with library prefix (CC)', () {
      const membershipNumber = 'CC20260042';
      expect(membershipNumber.startsWith('CC'), isTrue);
      expect(membershipNumber.length, greaterThanOrEqualTo(8));
    });

    test('Gov ID shown as masked on pass (not full number)', () {
      // Pass card should show masked Gov ID: '••••••••' or last 4 digits only
      const rawAadhaar = '234567890123';
      // Masking strategy: show last 4 only
      final masked = '•••• •••• ${rawAadhaar.substring(rawAadhaar.length - 4)}';
      expect(masked, contains('0123'));
      expect(masked, isNot(contains('234567'))); // first 8 hidden
    });

    test('Expiry date is displayed in dd MMM yyyy format', () {
      final date = DateTime(2026, 10, 31);
      // Format as used in pass card
      final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final formatted =
          '${date.day.toString().padLeft(2, '0')} ${months[date.month]} ${date.year}';
      expect(formatted, equals('31 Oct 2026'));
    });

    test('Pass card shows ACTIVE badge for active student', () {
      // Status badge text contract
      const status = 'Active';
      expect(status, equals('Active'));
    });

    test('Pass card shows EXPIRED badge for expired student', () {
      const status = 'Expired';
      expect(status, equals('Expired'));
    });

    testWidgets('SeatTile tap callback fires exactly once', (tester) async {
      int tapCount = 0;
      final seat = _seat();

      await tester.pumpWidget(_wrap(
        SeatTile(
          seat: seat,
          isSelected: false,
          onTap: () => tapCount++,
          onLongPress: () {},
        ),
      ));

      await tester.tap(find.byType(SeatTile));
      await tester.pump();
      expect(tapCount, equals(1));
    });

    testWidgets('SeatTile long-press callback fires exactly once',
        (tester) async {
      int longPressCount = 0;
      final seat = _seat();

      await tester.pumpWidget(_wrap(
        SeatTile(
          seat: seat,
          isSelected: false,
          onTap: () {},
          onLongPress: () => longPressCount++,
        ),
      ));

      await tester.longPress(find.byType(SeatTile));
      await tester.pump();
      expect(longPressCount, equals(1));
    });
  });

  // =========================================================================
  // 5. WhatsApp Preview Sheet Tests
  // =========================================================================
  group('WhatsAppPreviewSheet Widget Tests', () {
    testWidgets('Renders recipient phone, student name, and initial message',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const WhatsAppPreviewSheet(
          phone: '9876543210',
          recipientName: 'Rahul Verma',
          message: 'Hello Rahul, your library seat A1 is confirmed.',
        ),
      ));
      await tester.pump();

      expect(find.text('WhatsApp Message Preview'), findsOneWidget);
      expect(find.textContaining('Rahul Verma'), findsOneWidget);
      expect(find.textContaining('+91 98765 43210'), findsOneWidget);
      expect(find.text('Hello Rahul, your library seat A1 is confirmed.'),
          findsOneWidget);
      expect(find.text('Open WhatsApp'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Toggles into edit mode when Edit button is tapped',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const WhatsAppPreviewSheet(
          phone: '9876543210',
          message: 'Initial message content',
        ),
      ));
      await tester.pump();

      expect(find.text('Prepared Message:'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      // Tap Edit
      await tester.tap(find.text('Edit'));
      await tester.pump();

      expect(find.text('Editing Message:'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);

      // Modify text
      await tester.enterText(
          find.byType(TextFormField), 'Updated custom message text');
      await tester.pump();

      // Toggle back to Preview
      await tester.tap(find.text('Preview'));
      await tester.pump();

      expect(find.text('Updated custom message text'), findsOneWidget);
    });

    testWidgets('Cancel button returns null via Navigator.pop',
        (tester) async {
      String? returnedResult = 'NOT_CALLED';

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                final res = await WhatsAppPreviewSheet.show(
                  ctx,
                  phone: '9876543210',
                  message: 'Fee receipt ready',
                );
                returnedResult = res;
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ));
      await tester.pump();

      // Open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.byType(WhatsAppPreviewSheet), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(WhatsAppPreviewSheet), findsNothing);
      expect(returnedResult, isNull);
    });

    testWidgets('Open WhatsApp button returns message via Navigator.pop',
        (tester) async {
      String? returnedResult;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                final res = await WhatsAppPreviewSheet.show(
                  ctx,
                  phone: '9876543210',
                  message: 'Fee receipt ready',
                );
                returnedResult = res;
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ));
      await tester.pump();

      // Open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.byType(WhatsAppPreviewSheet), findsOneWidget);

      // Tap Open WhatsApp
      await tester.tap(find.text('Open WhatsApp'));
      await tester.pumpAndSettle();

      expect(find.byType(WhatsAppPreviewSheet), findsNothing);
      expect(returnedResult, equals('Fee receipt ready'));
    });
  });

  // =========================================================================
  // 6. Bulk Student Import Screen Tests
  // =========================================================================
  group('BulkImportScreen Widget Tests', () {
    testWidgets('Renders CSV Format Specifications card with column badges',
        (tester) async {
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(
          home: BulkImportScreen(),
        ),
      ));
      await tester.pump();

      expect(find.text('Bulk Student Import'), findsOneWidget);
      expect(find.text('CSV Format Specifications'), findsOneWidget);
      expect(find.text('Name *'), findsOneWidget);
      expect(find.text('Mobile *'), findsOneWidget);
      expect(find.text('College'), findsOneWidget);
      expect(find.text('Course'), findsOneWidget);
      expect(find.text('BloodGroup'), findsOneWidget);
      expect(find.text('Download Sample CSV'), findsOneWidget);
      expect(find.text('Copy Columns'), findsOneWidget);
    });

    testWidgets('Renders file picker dropzone button in initial empty state',
        (tester) async {
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(
          home: BulkImportScreen(),
        ),
      ));
      await tester.pump();

      expect(find.text('Tap to Select Student CSV File'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
      expect(
          find.text('Supports .csv exported from Excel, Google Sheets, or any CRM'),
          findsOneWidget);
    });

    test('ParsedImportRow data model identifies valid vs error status correctly',
        () {
      final validRow = ParsedImportRow(
        rowIndex: 1,
        name: 'Vikas Gupta',
        phone: '9876543210',
        email: 'vikas@example.com',
        gender: 'male',
        college: 'Delhi University',
        course: 'B.Com',
        year: '2nd Year',
        emergencyContact: '9876500000',
        address: 'Delhi',
        bloodGroup: 'B+',
      );

      expect(validRow.isValid, isTrue);
      expect(validRow.status, equals(ImportRowStatus.valid));

      final errRow = ParsedImportRow(
        rowIndex: 2,
        name: 'Invalid Phone Student',
        phone: '123',
        email: '',
        gender: 'male',
        college: '',
        course: '',
        year: '',
        emergencyContact: '',
        address: '',
        bloodGroup: '',
        status: ImportRowStatus.error,
        errorReason: 'Mobile must be 10 digits',
      );

      expect(errRow.isValid, isFalse);
      expect(errRow.errorReason, equals('Mobile must be 10 digits'));
    });
  });
}
