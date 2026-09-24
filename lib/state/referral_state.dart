import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/referral.dart';
import '../services/referral_service.dart';
import 'auth_state.dart';

/// Shared referral data, so the Profile card, the Referral screen and the
/// redeem / apply flows always show the same numbers: any of them calls
/// [refresh] and every listener updates.
///
/// Also holds a referral code that arrived by deep link or QR before the
/// user could act on it ([pendingCode]) — it lives here, in memory, so it
/// survives the hop through login / sign-up.
class ReferralState extends ChangeNotifier {
  ReferralState._() {
    AuthState.instance.addListener(_onAuthChanged);
  }
  static final ReferralState instance = ReferralState._();

  ReferralInfo? info;
  ReferralRewards? rewards;
  bool isLoading = false;

  /// Last load failure (already a user-facing message); `null` when fine.
  String? error;

  /// True when the last failure was a 401 — the caller sends the user to
  /// the login screen rather than showing an error.
  bool unauthorized = false;

  String? pendingCode;

  bool? _wasSignedIn;

  void _onAuthChanged() {
    final signedIn = AuthState.instance.isAuthenticated;
    if (signedIn == _wasSignedIn) return;
    _wasSignedIn = signedIn;
    // A different (or no) account: drop the old account's numbers.
    info = null;
    rewards = null;
    error = null;
    unauthorized = false;
    notifyListeners();
  }

  /// Re-fetches `/referral` and `/referral/rewards` together.
  Future<void> refresh() async {
    if (!AuthState.instance.isAuthenticated) return;
    isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        ReferralService.instance.info(),
        ReferralService.instance.rewards(),
      ]);
      info = results[0] as ReferralInfo;
      rewards = results[1] as ReferralRewards;
      error = null;
      unauthorized = false;
    } on ApiException catch (e) {
      unauthorized = e.statusCode == 401;
      error = e.message;
    } catch (_) {
      error = '';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Hands over (and forgets) the code a deep link left behind.
  String? takePendingCode() {
    final code = pendingCode;
    pendingCode = null;
    return code;
  }
}
