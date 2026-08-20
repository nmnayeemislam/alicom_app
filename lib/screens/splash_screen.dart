import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';

/// First-frame screen while [AuthState.restore] resolves a stored session,
/// so the app doesn't flash a logged-out UI before swapping to logged-in.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await AuthState.instance.restore();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/alicom-mark.svg',
              width: 96,
              height: 96,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
