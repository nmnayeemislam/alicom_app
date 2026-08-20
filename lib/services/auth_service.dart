import '../core/api_client.dart';
import '../core/api_endpoints.dart';
import '../core/token_storage.dart';
import '../models/user.dart';

class AuthResult {
  final AppUser user;
  final String token;
  AuthResult({required this.user, required this.token});
}

/// Mirrors AuthController's routes: register, password login, OTP login,
/// forgot/reset password, profile, logout, FCM token registration.
///
/// Every AuthController response is wrapped as `{success, message, data,
/// errors}` (its own shape, not the shared Controller::json envelope), so
/// every method here unwraps `body['data']` before reading fields.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _client = ApiClient.instance;

  /// [countryIso] is the two-letter code from [countries] (e.g. 'BD') —
  /// required by RegisterRequest to normalize [phone] into a single stored
  /// format. [email] is optional; [password] must be at least 8 characters.
  Future<AuthResult> register({
    required String name,
    required String countryIso,
    required String phone,
    String? email,
    required String password,
  }) async {
    final response = await _client.post(
      ApiEndpoints.register,
      data: {
        'name': name,
        'country_iso': countryIso,
        'phone': phone,
        'email': ?email,
        'password': password,
        'password_confirmation': password,
      },
    );
    return _handleAuthResponse(response.data);
  }

  /// Either [email] or [phone] must be given, alongside [password].
  Future<AuthResult> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    final response = await _client.post(
      ApiEndpoints.login,
      data: {'email': ?email, 'phone': ?phone, 'password': password},
    );
    return _handleAuthResponse(response.data);
  }

  /// Returns `[{iso, name, dial_code, flag}, ...]`.
  Future<List<dynamic>> countries() async {
    final response = await _client.get(ApiEndpoints.authCountries);
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return data['countries'] as List<dynamic>;
  }

  Future<void> sendLoginOtp({required String phone}) async {
    await _client.post(ApiEndpoints.authLoginOtp, data: {'phone': phone});
  }

  Future<AuthResult> verifyLoginOtp({
    required String phone,
    required String otp,
  }) async {
    final response = await _client.post(
      ApiEndpoints.authLoginOtpVerify,
      data: {'phone': phone, 'otp': otp},
    );
    return _handleAuthResponse(response.data);
  }

  /// Either [email] or [phone] must be given. Starts the reset flow by
  /// texting/emailing an OTP.
  Future<void> forgotPassword({String? email, String? phone}) async {
    await _client.post(
      ApiEndpoints.authForgotPassword,
      data: {'email': ?email, 'phone': ?phone},
    );
  }

  /// Returns the `reset_token` to pass to [resetPassword] — the OTP itself
  /// is single-use and not accepted by that endpoint.
  Future<String> verifyOtp({
    String? email,
    String? phone,
    required String otp,
  }) async {
    final response = await _client.post(
      ApiEndpoints.authVerifyOtp,
      data: {'email': ?email, 'phone': ?phone, 'otp': otp},
    );
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return data['reset_token'] as String;
  }

  Future<void> resendOtp({String? email, String? phone}) async {
    await _client.post(
      ApiEndpoints.authResendOtp,
      data: {'email': ?email, 'phone': ?phone},
    );
  }

  Future<void> resetPassword({
    String? email,
    String? phone,
    required String resetToken,
    required String password,
  }) async {
    await _client.post(
      ApiEndpoints.authResetPassword,
      data: {
        'email': ?email,
        'phone': ?phone,
        'reset_token': resetToken,
        'password': password,
        'password_confirmation': password,
      },
    );
  }

  Future<AppUser> profile() async {
    final response = await _client.get(ApiEndpoints.profile);
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// name, country_iso and phone are required by UpdateProfileRequest;
  /// email/address are optional.
  Future<AppUser> updateProfile({
    required String name,
    required String countryIso,
    required String phone,
    String? email,
    String? address,
  }) async {
    final response = await _client.put(
      ApiEndpoints.profile,
      data: {
        'name': name,
        'country_iso': countryIso,
        'phone': phone,
        'email': ?email,
        'address': ?address,
      },
    );
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> updateFcmToken(String fcmToken) async {
    await _client.put(
      ApiEndpoints.profileFcmToken,
      data: {'fcm_token': fcmToken},
    );
  }

  Future<void> logout() async {
    try {
      await _client.post(ApiEndpoints.logout);
    } finally {
      await TokenStorage.instance.clearToken();
    }
  }

  Future<AuthResult> _handleAuthResponse(dynamic body) async {
    final map = body as Map<String, dynamic>;
    final data = map['data'] as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    await TokenStorage.instance.saveToken(token);
    return AuthResult(user: user, token: token);
  }
}
