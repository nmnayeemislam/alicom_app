/// One row of the notification inbox (`GET /notifications`).
///
/// Every order-status push is stored server-side, so the inbox holds them
/// even when the device had no FCM token at the time; broadcasts are stored
/// for customers whose device was registered.
class AppNotification {
  /// Server-side UUID — the id the read/delete routes take.
  final String id;

  /// `order.status` or `broadcast`; anything else is treated as a plain
  /// message with no destination.
  final String type;
  final String title;
  final String body;

  /// Set on `order.status`: what tapping the row opens.
  final int? orderId;
  final String? orderCode;
  final String? status;

  /// Set on `broadcast`: a path ("/products") or a full URL.
  final String? link;

  /// Already a full URL from the API — never resolved again.
  final String? imageUrl;

  final bool isRead;
  final DateTime? readAt;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.orderId,
    this.orderCode,
    this.status,
    this.link,
    this.imageUrl,
    this.isRead = false,
    this.readAt,
    this.createdAt,
  });

  bool get isOrder => type == 'order.status';

  /// True when tapping the row has somewhere to go.
  bool get hasDestination =>
      (isOrder && orderId != null) || (link != null && link!.trim().isNotEmpty);

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: '${json['id'] ?? ''}',
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        orderId: _int(json['order_id']),
        orderCode: json['order_code'] as String?,
        status: json['status'] as String?,
        link: json['link'] as String?,
        imageUrl: json['image_url'] as String?,
        isRead: json['is_read'] == true || json['is_read'] == 1,
        readAt: _date(json['read_at']),
        createdAt: _date(json['created_at']),
      );

  AppNotification copyWith({bool? isRead, DateTime? readAt}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        orderId: orderId,
        orderCode: orderCode,
        status: status,
        link: link,
        imageUrl: imageUrl,
        isRead: isRead ?? this.isRead,
        readAt: readAt ?? this.readAt,
        createdAt: createdAt,
      );

  static int? _int(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse('$value')?.toLocal();
}

/// A page of the inbox, with the unread total the API returns alongside it.
class NotificationPage {
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool hasMore;
  final int currentPage;

  const NotificationPage({
    this.notifications = const [],
    this.unreadCount = 0,
    this.hasMore = false,
    this.currentPage = 1,
  });

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    final list = (json['notifications'] as List?) ?? const [];
    final pagination = json['pagination'];
    return NotificationPage(
      notifications: list
          .whereType<Map>()
          .map((e) => AppNotification.fromJson(e.cast<String, dynamic>()))
          .toList(),
      unreadCount: AppNotification._int(json['unread_count']) ?? 0,
      hasMore: pagination is Map && pagination['has_more_pages'] == true,
      currentPage: (pagination is Map ? AppNotification._int(pagination['current_page']) : null) ?? 1,
    );
  }
}
