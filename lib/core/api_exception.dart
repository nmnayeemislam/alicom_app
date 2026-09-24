import 'package:dio/dio.dart';

/// Normalized error surfaced to the UI layer, translated from Laravel's
/// JSON error shape (`{message, errors: {field: [msg]}}` for 422s).
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, List<String>>? fieldErrors;

  ApiException(this.message, {this.statusCode, this.fieldErrors});

  factory ApiException.fromDioException(DioException e) {
    final response = e.response;
    final data = response?.data;

    // Laravel's throttle middleware answers "Too Many Attempts." — say what
    // the user should actually do instead.
    if (response?.statusCode == 429) {
      return ApiException(
        'Too many attempts, please wait a minute and try again.',
        statusCode: 429,
      );
    }

    if (data is Map<String, dynamic>) {
      final message = data['message'] as String? ?? _fallbackMessage(e);
      final rawErrors = data['errors'];
      Map<String, List<String>>? fieldErrors;
      if (rawErrors is Map) {
        fieldErrors = rawErrors.map(
          (key, value) => MapEntry(
            key.toString(),
            (value as List).map((v) => v.toString()).toList(),
          ),
        );
      }
      return ApiException(
        message,
        statusCode: response?.statusCode,
        fieldErrors: fieldErrors,
      );
    }

    return ApiException(_fallbackMessage(e), statusCode: response?.statusCode);
  }

  static String _fallbackMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The connection timed out. Please try again.';
      case DioExceptionType.connectionError:
        return 'Could not reach the server. Check your connection.';
      default:
        return e.response?.statusMessage ?? 'Something went wrong.';
    }
  }

  @override
  String toString() => message;
}
