/// Central place to point the app at the Laravel backend.
///
/// Defaults to the UAT deployment so builds work out of the box without a
/// local server. Override at build time with
/// `--dart-define=API_BASE_URL=https://your-host/api` for other
/// environments (e.g. pointing back at a local `php artisan serve` during
/// development — use `http://10.0.2.2:8000/api` on the Android emulator,
/// `http://localhost:8000/api` elsewhere).
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
