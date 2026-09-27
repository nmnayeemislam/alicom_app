import 'package:flutter/widgets.dart';

import '../services/notification_service.dart';
import 'auth_state.dart';

/// How many unread notifications the signed-in customer has, so every bell
/// in the app shows the same number instead of a decorative red dot.
///
/// Refreshed on sign-in and app start, when the app comes back to the
/// foreground, when a push lands while the app is open, and from the
/// `unread_count` every read/delete response carries. Reset to zero on
/// sign-out — a guest has no inbox.
class NotificationState extends ChangeNotifier with WidgetsBindingObserver {
  NotificationState._() {
    AuthState.instance.addListener(_onAuthChanged);
    WidgetsBinding.instance.addObserver(this);
  }
  static final NotificationState instance = NotificationState._();

  int unreadCount = 0;
  bool _loading = false;

  bool get hasUnread => unreadCount > 0;

  /// Applies a count the API just returned — cheaper and more accurate than
  /// re-fetching after every read or delete.
  void setUnreadCount(int count) {
    final next = count < 0 ? 0 : count;
    if (next == unreadCount) return;
    unreadCount = next;
    notifyListeners();
  }

  /// Re-reads the count from the API. Silent on failure: a stale badge is
  /// better than an error in front of whatever the customer was doing.
  Future<void> refresh() async {
    if (_loading) return;
    if (!AuthState.instance.isAuthenticated) {
      setUnreadCount(0);
      return;
    }
    _loading = true;
    try {
      setUnreadCount(await NotificationService.instance.unreadCount());
    } catch (_) {
      // Leave the last known count in place.
    } finally {
      _loading = false;
    }
  }

  void _onAuthChanged() {
    if (AuthState.instance.isAuthenticated) {
      refresh();
    } else {
      setUnreadCount(0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Notifications may have arrived (and been tapped, or not) while the
    // app was away.
    if (state == AppLifecycleState.resumed) refresh();
  }
}
