import 'package:flutter/material.dart';

import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';

/// First-frame screen while [AuthState.restore] resolves a stored session,
/// so the app doesn't flash a logged-out UI before swapping to logged-in.
/// Holds for a minimum duration so the splash animation is actually seen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _minDisplay = Duration(milliseconds: 2500);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final results = await Future.wait([
      AuthState.instance.restore(),
      OnboardingScreen.wasSeen(),
      Future.delayed(_minDisplay),
    ]);
    if (!mounted) return;
    final seenOnboarding = results[1] == true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => seenOnboarding ? const MainShell() : const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SizedBox.expand(
        child: Image.asset(
          'assets/images/splash.gif',
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}
