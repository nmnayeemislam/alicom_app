import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../state/auth_state.dart';

/// Sends a guest to sign in before an action that needs an account, and
/// says whether they came back signed in.
///
/// The cart and the wishlist both live on the customer's account server
/// side, so there is nothing to add to until there is one. Opening the
/// sign-in screen is friendlier than letting the call fail and showing
/// "could not add" — the shopper is told what to do about it.
///
/// ```dart
/// if (!await requireSignIn(context, reason: 'Sign in to add items to your cart.')) return;
/// ```
Future<bool> requireSignIn(BuildContext context, {String? reason}) async {
  if (AuthState.instance.isAuthenticated) return true;

  if (reason != null) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(reason), duration: const Duration(seconds: 2)));
  }
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
  );
  // The login screen pops itself once the session is live, so this is the
  // answer to "did they actually sign in?".
  return AuthState.instance.isAuthenticated;
}
