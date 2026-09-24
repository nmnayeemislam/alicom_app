import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alicom_app/screens/register_screen.dart';
import 'package:alicom_app/l10n/app_localizations.dart';
import 'package:alicom_app/theme/app_theme.dart';

void main() {
  // No network in tests: fall back to the default font instead of letting
  // google_fonts fail a download after the test has finished.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpRegister(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    // The screen asks the API for countries on open; with no server that
    // request fails, which is fine — these tests stop at client validation.
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const RegisterScreen()));
      await tester.pump();
    });
  }

  Future<void> fill(WidgetTester tester, String label, String text) =>
      tester.enterText(find.widgetWithText(TextFormField, label), text);

  Future<void> submit(WidgetTester tester) async {
    final button = find.widgetWithText(ElevatedButton, 'Register');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  testWidgets('has a Confirm password field', (tester) async {
    await pumpRegister(tester);
    expect(find.widgetWithText(TextFormField, 'Confirm password'), findsOneWidget);
  });

  testWidgets('rejects mismatched passwords before sending anything', (tester) async {
    await pumpRegister(tester);
    await fill(tester, 'Full name', 'Rahim');
    await fill(tester, 'Phone', '01712345678');
    await fill(tester, 'Password', '12345678');
    await fill(tester, 'Confirm password', '87654321');
    await submit(tester);
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('rejects a password shorter than 8 characters', (tester) async {
    await pumpRegister(tester);
    await fill(tester, 'Full name', 'Rahim');
    await fill(tester, 'Phone', '01712345678');
    await fill(tester, 'Password', 'short');
    await fill(tester, 'Confirm password', 'short');
    await submit(tester);
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
  });
}
