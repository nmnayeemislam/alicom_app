import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alicom_app/screens/main_shell.dart';
import 'package:alicom_app/theme/app_theme.dart';

void main() {
  testWidgets('Nav shell renders all five tabs', (WidgetTester tester) async {
    // Tests MainShell directly rather than the full app (which starts on
    // SplashScreen and awaits a secure-storage read) — that keeps this a
    // fast, deterministic smoke test instead of depending on platform
    // channels/timers that aren't mocked in this test environment.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const MainShell()),
      );
      await tester.pump();
    });

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Wishlist'), findsOneWidget);
    expect(find.text('Cart'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });
}
