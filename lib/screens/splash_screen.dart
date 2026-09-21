import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/auth_state.dart';
import '../state/theme_state.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';

/// First-frame screen while [AuthState.restore] resolves a stored session,
/// so the app doesn't flash a logged-out UI before swapping to logged-in.
///
/// Drawn with widgets rather than the old full-screen GIF: the GIF was 9:16
/// and got cropped on taller phones, and its background never matched the
/// native splash, so the app visibly "jumped" between the two. The colours
/// here are the same ones `flutter_native_splash` uses in pubspec.yaml.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// Deep teal shared with the native splash (`flutter_native_splash.color`).
const _splashBackground = Color(0xFF022728);

const _splashOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: _splashBackground,
  systemNavigationBarIconBrightness: Brightness.light,
);

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _minDisplay = Duration(milliseconds: 2000);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final Animation<double> _markScale = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
  );
  late final Animation<double> _markFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.45, curve: Curves.easeOut),
  );
  late final Animation<double> _wordmarkFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.45, 1, curve: Curves.easeOut),
  );
  late final Animation<Offset> _wordmarkSlide =
      Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.45, 1, curve: Curves.easeOutCubic),
        ),
      );

  @override
  void initState() {
    super.initState();
    // Light icons and a dark nav bar on the deep-teal splash regardless of
    // the app theme; the app's own style is restored in [_bootstrap].
    SystemChrome.setSystemUIOverlayStyle(_splashOverlayStyle);
    _controller.forward();
    _bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final results = await Future.wait([
      AuthState.instance.restore(),
      OnboardingScreen.wasSeen(),
      Future.delayed(_minDisplay),
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

  @override
  Widget build(BuildContext context) {
    // Deliberately no AnnotatedRegion here: it would re-apply the dark bars
    // on the frame we hand over and undo the restore done in [_bootstrap].
    return Scaffold(
      backgroundColor: _splashBackground,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _markFade,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.8, end: 1.0).animate(_markScale),
                      child: const _BrandMark(height: 190),
                    ),
                  ),
                  const SizedBox(height: 26),
                  FadeTransition(
                    opacity: _wordmarkFade,
                    child: SlideTransition(
                      position: _wordmarkSlide,
                      child: const Text(
                        'Alicom',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 36,
              child: FadeTransition(
                opacity: _wordmarkFade,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bag mark with the white "a" sitting in its circular cut-out — the
/// same composition as the brand wordmark. The cut-out's centre and radius
/// were measured off `app_icon.png` (82.2% / 72.3% of the bag box, radius
/// 38.7% of its width), so the letter lands in the hole at any size.
class _BrandMark extends StatelessWidget {
  final double height;
  const _BrandMark({required this.height});

  // splash_mark.png is 572×720 — the bag cropped to its bounds.
  static const _aspect = 572 / 720;

  @override
  Widget build(BuildContext context) {
    final width = height * _aspect;
    final radius = width * 0.387;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/splash_mark.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned(
            left: width * 0.822 - radius,
            top: height * 0.723 - radius,
            width: radius * 2,
            height: radius * 2,
            child: Center(
              child: Text(
                'a',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: radius * 1.55,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
