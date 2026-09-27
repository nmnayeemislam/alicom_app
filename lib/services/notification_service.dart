import '../core/api_client.dart';
import '../core/api_endpoints.dart';
import '../models/notification.dart';

/// The notification inbox — mirrors the API's NotificationController.
///
/// Every write returns the account's new `unread_count`, so callers never
/// have to guess it or re-fetch.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _client = ApiClient.instance;

  static Map<String, dynamic> _data(dynamic body) {
    final data = body is Map ? body['data'] : null;
    return data is Map ? data.cast<String, dynamic>() : const {};
  }

  static int _unread(Map<String, dynamic> data) =>
      (data['unread_count'] as num?)?.toInt() ?? 0;

  /// Newest first. [unreadOnly] asks the API for just the unread ones.
  Future<NotificationPage> list({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
  }) async {
    final response = await _client.get(
      ApiEndpoints.notifications,
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (unreadOnly) 'unread': true,
      },
    );
    return NotificationPage.fromJson(_data(response.data));
  }

  Future<int> unreadCount() async =>
      _unread(_data((await _client.get(ApiEndpoints.notificationsUnreadCount)).data));

  /// Returns the updated row and the new unread total. 404 when the id
  /// belongs to someone else.
  Future<({AppNotification notification, int unreadCount})> markAsRead(String id) async {
    final data = _data((await _client.post(ApiEndpoints.notificationRead(id))).data);
    final raw = data['notification'];
    return (
      notification: AppNotification.fromJson(
        raw is Map ? raw.cast<String, dynamic>() : const {},
      ),
      unreadCount: _unread(data),
    );
  }

  /// Returns how many rows changed and the new unread total (zero).
  Future<({int updated, int unreadCount})> markAllAsRead() async {
    final data = _data((await _client.post(ApiEndpoints.notificationsReadAll)).data);
    return (
      updated: (data['updated'] as num?)?.toInt() ?? 0,
      unreadCount: _unread(data),
    );
  }

  Future<int> delete(String id) async =>
      _unread(_data((await _client.delete(ApiEndpoints.notification(id))).data));
}
