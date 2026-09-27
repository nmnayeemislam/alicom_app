import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../screens/notifications_screen.dart';
import '../state/auth_state.dart';
import '../state/notification_state.dart';
import 'tab_app_bar.dart';

/// The bell used by every tab's app bar: its dot comes from the real unread
/// count, and a guest is sent to sign in rather than to an inbox the API
/// would refuse.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  static void open(BuildContext context) {
    final signedIn = AuthState.instance.isAuthenticated;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => signedIn ? const NotificationsScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([NotificationState.instance, AuthState.instance]),
      builder: (context, _) => RoundAppBarButton(
        icon: Icons.notifications_none_rounded,
        count: NotificationState.instance.unreadCount,
        onTap: () => open(context),
      ),
    );
  }
}
