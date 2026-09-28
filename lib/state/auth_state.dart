import 'package:flutter/foundation.dart';

import '../core/push_notifications.dart';
import '../core/token_storage.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthState extends ChangeNotifier {
  AuthState._();
  static final AuthState instance = AuthState._();

  AppUser? user;
  bool isLoading = false;

  bool get isAuthenticated => user != null;

  /// Call once at app start to restore a session from the stored token.
  Future<void> restore() async {
    String? token;
    try {
      token = await TokenStorage.instance.readToken();
    } catch (_) {
      // Keychain/keystore unavailable — fall back to a logged-out session.
    }
    if (token == null || token.isEmpty) return;

    isLoading = true;
    notifyListeners();
    try {
      user = await AuthService.instance.profile();
    } catch (_) {
      // Stale/invalid token — ApiClient already clears it on a 401.
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login({required String email, required String password}) async {
    final result = await AuthService.instance.login(email: email, password: password);
    user = result.user;
    notifyListeners();
  }

  /// Second step of sign-up — see [AuthService.register]. Phone is
  /// optional; the country only travels with one.
  Future<void> register({
    required String name,
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
    String? countryIso,
    String? phone,
    String? referralCode,
  }) async {
    final result = await AuthService.instance.register(
      referralCode: referralCode,
      name: name,
      email: email,
      otp: otp,
      countryIso: countryIso,
      phone: phone,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );
    user = result.user;
    notifyListeners();
  }

  Future<({int expiresInSeconds, int resendAfterSeconds})> sendRegistrationOtp(String email) =>
      AuthService.instance.sendRegistrationOtp(email);

  Future<void> sendLoginOtp({required String phone}) =>
      AuthService.instance.sendLoginOtp(phone: phone);

  Future<void> loginWithOtp({required String phone, required String otp}) async {
    final result = await AuthService.instance.verifyLoginOtp(phone: phone, otp: otp);
    user = result.user;
    notifyListeners();
  }

  Future<void> updateProfile({
    required String name,
    required String countryIso,
    required String phone,
    String? email,
    String? address,
  }) async {
    user = await AuthService.instance.updateProfile(
      name: name,
      countryIso: countryIso,
      phone: phone,
      email: email,
      address: address,
    );
    notifyListeners();
  }

  Future<void> updateProfilePhoto(String filePath) async {
    final current = user;
    if (current == null) return;
    user = await AuthService.instance.uploadProfilePhoto(current: current, filePath: filePath);
    notifyListeners();
  }

  /// Deletes the account for good, then leaves the app signed out.
  Future<void> deleteAccount(String password) async {
    await AuthService.instance.deleteAccount(password);
    await PushNotifications.instance.onSignedOut();
    user = null;
    notifyListeners();
  }

  Future<void> logout() async {
    await AuthService.instance.logout();
    // The backend keeps one FCM token per user and does not clear it on
    // logout, so the device drops its own — otherwise the next person to
    // sign in here would keep getting the previous customer's pushes.
    await PushNotifications.instance.onSignedOut();
    user = null;
    notifyListeners();
  }
}
