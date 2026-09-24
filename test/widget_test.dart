import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alicom_app/screens/categories_screen.dart';
import 'package:alicom_app/screens/home_screen.dart';
import 'package:alicom_app/screens/main_shell.dart';
import 'package:alicom_app/l10n/app_localizations.dart';
import 'package:alicom_app/theme/app_theme.dart';

void main() {
  // No network in tests: fall back to the default font instead of letting
  // google_fonts fail a download after the test has finished.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('Nav shell renders all five destinations', (tester) async {
    // Tests MainShell directly rather than the full app (which starts on
    // SplashScreen and awaits a secure-storage read) — that keeps this a
    // fast, deterministic smoke test instead of depending on platform
    // channels/timers that aren't mocked in this test environment.
    //
    // The nav is icon-only: four pills around a raised centre button, with
    // no text labels to match on.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MainShell()),
      );
      await tester.pump();
    });

    expect(find.byIcon(Icons.home_rounded), findsOneWidget); // active
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    // The raised centre button.
    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);

    // All five live in an IndexedStack, which keeps the unselected ones
    // built but offstage — hence `skipOffstage: false` for the Categories
    // tab, while Home is the one actually on screen.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(
      find.byType(CategoriesScreen, skipOffstage: false),
      findsOneWidget,
    );
  });
}
