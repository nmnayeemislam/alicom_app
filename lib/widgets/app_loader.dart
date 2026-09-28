import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../theme/app_theme.dart';

/// The app's one spinner: a Newton's cradle, so a wait looks the same
/// wherever it happens.
///
/// [size] is the whole square the animation draws in — the balls are a
/// tenth of it, so small values read as a smudge. Inside a button use
/// [AppLoader.onAccent].
class AppLoader extends StatelessWidget {
  final double size;
  final Color? color;

  /// Draw at full [size] even where the parent leaves less room.
  ///
  /// A filled button is 52px tall with 14px of padding each side, so its
  /// child gets 24px. Letting the cradle spill into that padding keeps the
  /// button exactly as tall as it is when it says "Login", instead of it
  /// growing every time someone taps it.
  final bool allowOverflow;

  const AppLoader({
    super.key,
    this.size = 72,
    this.color,
    this.allowOverflow = false,
  });

  /// For a filled button or any coloured surface.
  const AppLoader.onAccent({super.key, this.size = 46})
      : color = Colors.white,
        allowOverflow = true;

  @override
  Widget build(BuildContext context) {
    final loader = LoadingAnimationWidget.newtonCradle(
      color: color ?? AppColors.primary,
      size: size,
    );
    if (!allowOverflow) return loader;
    return SizedBox(
      height: 24,
      child: Center(
        child: OverflowBox(
          maxWidth: size,
          maxHeight: size,
          child: loader,
        ),
      ),
    );
  }
}

/// Covers the screen with the loader while something that cannot be
/// interrupted finishes — signing out, for instance, which calls the API
/// and drops the device's push token before the session goes.
Future<T> showBlockingLoader<T>(
  BuildContext context,
  Future<T> Function() action,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: AppLoader(size: 96)),
    ),
  );
  try {
    return await action();
  } finally {
    // The dialog is the top route; close it whatever the outcome.
    if (navigator.canPop()) navigator.pop();
  }
}
