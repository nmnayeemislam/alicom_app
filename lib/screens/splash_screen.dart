import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/money.dart';
import '../services/settings_service.dart';
import '../state/auth_state.dart';
import '../state/theme_state.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';

/// First-frame screen while [AuthState.restore] resolves a stored session,
/// so the app doesn't flash a logged-out UI before swapping to logged-in.
///
/// Plays the animated `splash_alicom.gif` (the logo bouncing in). The GIF is
/// 9:16 on a flat teal, so it is fitted with [BoxFit.contain] — never
/// cropped — and the screen behind it is painted that same teal, which makes
/// the extra height on taller phones invisible. `flutter_native_splash` in
/// pubspec.yaml uses the same colour so there is no jump between the two.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// The GIF's own background, sampled from its frames. Keep in sync with
/// `flutter_native_splash.color`.
const _splashBackground = Color(0xFF22A1A7);

const _splashGif = 'assets/images/splash_alicom.gif';

const _splashOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: _splashBackground,
  systemNavigationBarIconBrightness: Brightness.light,
);

class _SplashScreenState extends State<SplashScreen> {
  /// One full play of the GIF (64 frames, ~2.13s) plus a beat on the
  /// settled logo, so the hand-off never cuts the animation mid-bounce.
  static const _minDisplay = Duration(milliseconds: 2400);

  @override
  void initState() {
    super.initState();
    // Light icons and a teal nav bar on the splash regardless of the app
    // theme; the app's own style is restored in [_bootstrap].
    SystemChrome.setSystemUIOverlayStyle(_splashOverlayStyle);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final results = await Future.wait<Object?>([
      AuthState.instance.restore(),
      OnboardingScreen.wasSeen(),
      Future.delayed(_minDisplay),
      _loadCurrency(),
    ]);
    if (!mounted) return;
    final seenOnboarding = results[1] == true;
    SystemChrome.setSystemUIOverlayStyle(
      AppTheme.systemOverlayStyle(ThemeState.instance.isDark),
    );
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) =>
            seenOnboarding ? const MainShell() : const OnboardingScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  /// The store's currency, so every price in the app renders with the
  /// admin-configured symbol and decimals. Runs alongside the GIF, so it
  /// normally costs nothing; capped so a slow or down API can't hold the
  /// splash — prices then fall back to the currency code or a bare number.
  Future<void> _loadCurrency() async {
    try {
      final response = await SettingsService.instance
          .brandingSettings()
          .timeout(const Duration(seconds: 6));
      CurrencySettings.applyBranding(response);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Deliberately no AnnotatedRegion here: it would re-apply the splash
    // bars on the frame we hand over and undo the restore in [_bootstrap].
    return const Scaffold(
      backgroundColor: _splashBackground,
      body: SizedBox.expand(
        child: Image(
          image: AssetImage(_splashGif),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
