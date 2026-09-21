import 'package:flutter/foundation.dart';

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

  Future<void> register({
    required String name,
    required String countryIso,
    required String phone,
    String? email,
    required String password,
  }) async {
    final result = await AuthService.instance.register(
      name: name,
      countryIso: countryIso,
      phone: phone,
      email: email,
      password: password,
    );
    user = result.user;
    notifyListeners();
  }

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

  Future<void> logout() async {
    await AuthService.instance.logout();
    user = null;
    notifyListeners();
  }
}
