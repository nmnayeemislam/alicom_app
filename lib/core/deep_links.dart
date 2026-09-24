import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../models/referral.dart';
import '../screens/apply_referral_screen.dart';
import '../screens/login_screen.dart';
import '../screens/referral_screen.dart';
import '../screens/register_screen.dart';
import '../services/referral_service.dart';
import '../state/auth_state.dart';
import '../state/referral_state.dart';

/// Handles `https://<domain>/ref/{CODE}` links (Android App Links / iOS
/// Universal Links, configured in AndroidManifest.xml and
/// Runner.entitlements).
///
/// The code is parked in [ReferralState.pendingCode] — memory, so it
/// survives the login / sign-up hops — and acted on once the main shell is
/// on screen:
///   - logged out → Sign-up with the code pre-filled;
///   - logged in and `can_apply_code` → "Apply a referral code" pre-filled;
///   - logged in otherwise → the Referral screen.
/// Opening a link never awards anything by itself; only the friend's
/// qualifying order does.
class DeepLinks {
  DeepLinks._();
  static final DeepLinks instance = DeepLinks._();

  /// Lets the handler navigate from outside any widget.
  static final navigatorKey = GlobalKey<NavigatorState>();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _shellReady = false;
  bool _routing = false;
  bool _wasSignedIn = false;

  /// The same link can arrive from both getInitialLink and the stream.
  String? _lastUri;
  DateTime? _lastAt;

  void init() {
    _sub ??= _appLinks.uriLinkStream.listen(_handle, onError: (_) {});
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handle(uri);
    }).catchError((_) {});
    _wasSignedIn = AuthState.instance.isAuthenticated;
    AuthState.instance.addListener(_onAuthChanged);
  }

  void _handle(Uri uri) {
    final text = uri.toString();
    final now = DateTime.now();
    if (text == _lastUri && _lastAt != null && now.difference(_lastAt!) < const Duration(seconds: 3)) return;
    _lastUri = text;
    _lastAt = now;

    // Only /ref/{CODE} paths are ours.
    if (!uri.pathSegments.contains('ref')) return;
    final code = extractReferralCode(text);
    if (code == null) return;
    ReferralState.instance.pendingCode = code;
    if (_shellReady) route();
  }

  /// Called by the main shell once it is on screen (after splash /
  /// onboarding), so a link that opened the app is handled then.
  void markShellReady() {
    _shellReady = true;
    route();
  }

  /// Signing in while a code is still parked (e.g. the user chose Login
  /// over Sign-up) continues to the logged-in branch.
  void _onAuthChanged() {
    final signedIn = AuthState.instance.isAuthenticated;
    final justSignedIn = signedIn && !_wasSignedIn;
    _wasSignedIn = signedIn;
    if (justSignedIn && ReferralState.instance.pendingCode != null && _shellReady) {
      // Let the login/register routes finish popping first.
      Future.delayed(const Duration(milliseconds: 600), route);
    }
  }

  Future<void> route() async {
    final code = ReferralState.instance.pendingCode;
    final navigator = navigatorKey.currentState;
    if (code == null || navigator == null || _routing) return;
    _routing = true;
    try {
      if (!AuthState.instance.isAuthenticated) {
        // Keep the code parked: sign-up reads it, and if the user logs in
        // instead, [_onAuthChanged] picks it up.
        navigator.push(MaterialPageRoute(builder: (_) => const LoginScreen()));
        navigator.push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
        return;
      }
      bool canApply = false;
      try {
        canApply = (await ReferralService.instance.info()).canApplyCode;
      } catch (_) {}
      ReferralState.instance.takePendingCode();
      navigator.push(MaterialPageRoute(
        builder: (_) => canApply ? ApplyReferralScreen(initialCode: code) : const ReferralScreen(),
      ));
    } finally {
      _routing = false;
    }
  }
}
