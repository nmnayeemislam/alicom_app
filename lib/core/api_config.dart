/// The single place the API host is configured — nothing else in the app
/// builds a base URL.
///
/// The default points at the dev machine running `php artisan serve` on the
/// office LAN. That address changes whenever the router restarts, so rather
/// than editing this file, override it at build time:
///
///   `--dart-define=API_BASE_URL=http://<lan-ip>:8000/api`  real device
///   --dart-define=API_BASE_URL=http://10.0.2.2:8000/api   Android emulator
///   --dart-define=API_BASE_URL=http://localhost:8000/api  iOS Simulator
///   --dart-define=API_BASE_URL=https://uat-alicom.razinsoft.com/api  UAT
///
/// Note the port is 8000 (`artisan serve`'s default), not 8001.
///
/// A plain-HTTP host needs the cleartext exemptions that go with it:
/// `android/app/src/debug/res/xml/network_security_config.xml` for debug
/// Android builds, and `NSAllowsLocalNetworking` in `ios/Runner/Info.plist`.
/// Release builds still require HTTPS.
class ApiConfig {
  ApiConfig._();

  static const String _override = String.fromEnvironment('API_BASE_URL');

  static const String _defaultBaseUrl = 'https://uat-alicom.razinsoft.com/api';

  static String get baseUrl => _override.isNotEmpty ? _override : _defaultBaseUrl;

  /// Turns a path the API returned into something an image widget can load.
  ///
  /// Some endpoints (cart, order items) send storage-relative paths like
  /// `dummy/images/demo/fan.webp` while others send full URLs, so anything
  /// without a scheme is resolved against the API's origin (the host
  /// without the `/api` prefix).
  static String? resolveUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (Uri.tryParse(path)?.hasScheme ?? false) return path;
    final origin = Uri.parse(baseUrl).origin;
    return '$origin/${path.startsWith('/') ? path.substring(1) : path}';
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
