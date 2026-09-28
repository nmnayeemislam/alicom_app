import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../state/theme_state.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';

/// First-run walkthrough shown once after the splash screen.
///
/// Each page is a photo hero with the app's own headline underneath, in the
/// same shape the auth screens use (full-bleed top, rounded sheet over it),
/// so the copy is translatable instead of baked into the artwork.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const _seenKey = 'onboarding_seen';
  static const _storage = FlutterSecureStorage();

  static Future<bool> wasSeen() async =>
      await _storage.read(key: _seenKey) == '1';

  static Future<void> markSeen() => _storage.write(key: _seenKey, value: '1');

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingPage {
  final String image;
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations) body;

  /// Which slice of the photo to keep when it is wider or taller than the
  /// hero — each shot has its subject in a different place.
  final Alignment alignment;

  const _OnboardingPage({
    required this.image,
    required this.title,
    required this.body,
    this.alignment = Alignment.center,
  });
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static final _pages = <_OnboardingPage>[
    _OnboardingPage(
      image: 'assets/images/onboard_1.jpg',
      title: (l) => l.onboardTitle1,
      body: (l) => l.onboardBody1,
      alignment: Alignment.topCenter,
    ),
    _OnboardingPage(
      image: 'assets/images/onboard_2.jpg',
      title: (l) => l.onboardTitle2,
      body: (l) => l.onboardBody2,
    ),
    _OnboardingPage(
      image: 'assets/images/onboard_3.jpg',
      title: (l) => l.onboardTitle3,
      body: (l) => l.onboardBody3,
    ),
  ];

  final _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == _pages.length - 1;

  @override
  void initState() {
    super.initState();
    // Warm the next frames up so a swipe never lands on a blank hero.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final page in _pages) {
        precacheImage(AssetImage(page.image), context);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingScreen.markSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    // The hero keeps a little more room on tall phones and gives it back on
    // short ones, so the copy never has to scroll.
    final heroHeight = (media.size.height * 0.60).clamp(280.0, 620.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness:
            ThemeState.instance.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            SizedBox(
              height: heroHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) => _hero(_pages[i]),
                  ),
                  // Keeps "Skip" readable over a bright shot.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 120,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.28),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!_isLast)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6, right: 12),
                          child: TextButton(
                            onPressed: _finish,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            child: Text(l10n.onboardSkip),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: _sheet(context, l10n)),
          ],
        ),
      ),
    );
  }

  /// The photo, cropped to the hero and faded into the sheet below so the
  /// two never meet on a hard line.
  Widget _hero(_OnboardingPage page) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(page.image, fit: BoxFit.cover, alignment: page.alignment),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 96,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.background.withValues(alpha: 0),
                  AppColors.background,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sheet(BuildContext context, AppLocalizations l10n) {
    final page = _pages[_index];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                // Centred so the copy sits between the photo and the CTA
                // instead of leaving a gap under it on tall screens.
                child: _AnimatedCopy(
                  // Re-keyed per page, so the widget rebuilds and replays
                  // its entrance instead of the text simply swapping.
                  key: ValueKey(_index),
                  title: page.title(l10n),
                  body: page.body(l10n),
                ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _dots(),
                const Spacer(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.32),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _nextButton(l10n),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_pages.length, (i) {
        final active = i == _index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(right: 6),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.lineStrong,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _nextButton(AppLocalizations l10n) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _next,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: _isLast ? 26 : 22, vertical: 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(999)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isLast ? l10n.onboardGetStarted : l10n.onboardNext,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// The headline and the line under it, sliding up into place one after the
/// other whenever the page changes.
///
/// Staggered on purpose: both arriving together reads as one block moving,
/// while a short gap between them makes the eye follow the headline first.
class _AnimatedCopy extends StatefulWidget {
  final String title;
  final String body;

  const _AnimatedCopy({super.key, required this.title, required this.body});

  @override
  State<_AnimatedCopy> createState() => _AnimatedCopyState();
}

class _AnimatedCopyState extends State<_AnimatedCopy> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Fade plus a lift, over [begin]–[end] of the controller's run.
  Widget _entrance({required double begin, required double end, required Widget child}) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _entrance(
          begin: 0,
          end: 0.65,
          child: Text(
            widget.title,
            style: GoogleFonts.interTight(
              fontSize: 27,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: AppColors.inkStrong,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _entrance(
          begin: 0.25,
          end: 1,
          child: Text(
            widget.body,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.55,
              color: AppColors.body,
            ),
          ),
        ),
      ],
    );
  }
}
