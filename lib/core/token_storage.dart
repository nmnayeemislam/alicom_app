import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the Sanctum bearer token in the platform keychain/keystore
/// rather than SharedPreferences, since it is a credential.
class TokenStorage {
  TokenStorage._();
  static final TokenStorage instance = TokenStorage._();

  static const _tokenKey = 'auth_token';
  final _storage = const FlutterSecureStorage();

  /// Returns `null` rather than throwing when the keystore is unreadable.
  ///
  /// This runs in [ApiClient]'s request interceptor, so letting it throw
  /// would fail *every* request — including the public catalogue, which
  /// needs no token at all. A locked or corrupted keystore (and a unit-test
  /// VM with no plugin registered) should degrade to browsing as a guest,
  /// not to a dead app.
  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
