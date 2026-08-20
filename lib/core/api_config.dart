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

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
