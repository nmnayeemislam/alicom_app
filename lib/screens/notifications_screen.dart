import 'package:flutter/material.dart';

import '../widgets/state_views.dart';

/// The backend has no `/notifications` endpoint yet (only a device-token
/// registration route for push, `PUT /profile/fcm-token`), so there is no
/// real notification feed to list here. This screen exists so the bell icon
/// scattered across the app leads somewhere honest instead of nowhere, and
/// is ready to wire up once a listing endpoint exists.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const EmptyView(
        icon: Icons.notifications_none_rounded,
        message: "You're all caught up — no notifications yet.",
      ),
    );
  }
}
