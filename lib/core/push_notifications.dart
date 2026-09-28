import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import '../screens/order_detail_screen.dart';
import '../services/auth_service.dart';
import '../state/auth_state.dart';
import '../state/notification_state.dart';
import 'deep_links.dart';

/// Fired when the app is in the background or terminated. Must be a
/// top-level function: Android spins up a separate isolate for it.
///
/// Nothing is shown here on purpose — a message with a `notification` block
/// is already drawn by the system, and drawing a second one would double it.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {}

/// Firebase Cloud Messaging: permission, the device token the backend
/// stores per user (`PUT /profile/fcm-token`), and what happens when a
/// message arrives or is tapped.
///
/// The backend sends two kinds of message:
///   - order status — `data.order_id` + `data.status`; tapping opens that
///     order;
///   - admin broadcast — optional `data.link` (a URL or in-app path) and
///     an image: `notification.image` / `data.image_url` (absolute URLs;
///     `data.image` is the raw storage path). In the background the system
///     draws the picture itself; in the foreground [_onForegroundMessage]
///     downloads it and shows it as a big picture.
///
/// Everything here fails soft: a device without Play Services, a denied
/// permission or a missing Firebase config leaves the rest of the app
/// working, just without push.
class PushNotifications {
  PushNotifications._();
  static final PushNotifications instance = PushNotifications._();

  static const _androidChannel = AndroidNotificationChannel(
    'alicom_default',
    'Order updates & offers',
    description: 'Order status changes and messages from Alicom.',
    importance: Importance.high,
  );

  final _local = FlutterLocalNotificationsPlugin();

  bool _ready = false;
  bool _tokenSent = false;

  /// Set while the app was opened by tapping a notification, so routing can
  /// wait for the shell to be on screen.
  RemoteMessage? _pendingTap;
  bool _shellReady = false;

  /// Call once at start-up, before `runApp`.
  Future<void> init() async {
    if (_ready) return;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
      await _setUpLocalNotifications();

      // A tap that launched the app from terminated.
      _pendingTap = await FirebaseMessaging.instance.getInitialMessage();

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _tokenSent = false;
        _sendToken(token);
      });

      // Signing in or out changes which account the token belongs to.
      AuthState.instance.addListener(_onAuthChanged);
      _ready = true;
    } catch (error, stack) {
      debugPrint('Push notifications unavailable: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> _setUpLocalNotifications() async {
    await _local.initialize(
      settings: const InitializationSettings(
        // A white silhouette, not the launcher icon: Android masks the
        // small icon, so anything coloured shows up as a blank square.
        android: AndroidInitializationSettings('@drawable/ic_notification'),
        // The permission prompt is asked for separately, once the customer
        // has a reason to say yes.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = (jsonDecode(payload) as Map).cast<String, dynamic>();
          _route(data.map((k, v) => MapEntry(k, v)));
        } catch (_) {}
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  /// Asks for the notification permission (Android 13+ and iOS) and, once
  /// granted, registers the device against the signed-in account.
  ///
  /// Called after sign-in rather than at first launch, so the prompt lands
  /// when order updates actually mean something.
  Future<void> requestPermissionAndRegister() async {
    if (!_ready) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      await registerToken();
    } catch (error) {
      debugPrint('Push permission failed: $error');
    }
  }

  /// Sends the current device token to the backend for the signed-in user.
  /// Safe to call repeatedly — it only sends once per token per session.
  Future<void> registerToken() async {
    if (!_ready || _tokenSent || !AuthState.instance.isAuthenticated) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _sendToken(token);
    } catch (error) {
      debugPrint('Could not read the FCM token: $error');
    }
  }

  Future<void> _sendToken(String token) async {
    if (!AuthState.instance.isAuthenticated) return;
    try {
      await AuthService.instance.updateFcmToken(token);
      _tokenSent = true;
      debugPrint('FCM device token registered (${token.substring(0, 12)}…)');
    } catch (error) {
      // The next sign-in or token refresh tries again.
      debugPrint('Could not register the device token: $error');
    }
  }

  /// Sign-in — from the password form, sign-up or an OTP — is the moment
  /// to ask for the permission and hand the backend this device.
  void _onAuthChanged() {
    if (AuthState.instance.isAuthenticated) {
      requestPermissionAndRegister();
    } else {
      _tokenSent = false;
    }
  }

  /// Drops the device's token on sign-out.
  ///
  /// The backend keeps one token per user and does not clear it on logout,
  /// so without this the next person to use the phone would keep receiving
  /// the previous customer's order updates.
  Future<void> onSignedOut() async {
    _tokenSent = false;
    if (!_ready) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (error) {
      debugPrint('Could not delete the FCM token: $error');
    }
  }

  // --- INCOMING --------------------------------------------------------

  /// In the foreground the system draws nothing, so the notification is
  /// re-created locally.
  Future<void> _onForegroundMessage(RemoteMessage message) async {
    // The backend stored this one in the inbox too, so the bell moves even
    // though the customer never left the screen they were on.
    NotificationState.instance.refresh();
    final notification = message.notification;
    if (notification == null) return;
    final imageUrl = _imageUrlOf(message);
    final image = imageUrl == null ? null : await _download(imageUrl);
    try {
      await _local.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
            color: const Color(0xFF22A699),
            largeIcon: image == null ? null : ByteArrayAndroidBitmap(image),
            styleInformation: image == null
                ? null
                : BigPictureStyleInformation(
                    ByteArrayAndroidBitmap(image),
                    contentTitle: notification.title,
                    summaryText: notification.body,
                    // Collapsed: thumbnail on the right; expanded: the
                    // picture alone, not the thumbnail beside it again.
                    hideExpandedLargeIcon: true,
                  ),
          ),
          iOS: DarwinNotificationDetails(
            attachments: image == null ? null : await _iosAttachment(image, imageUrl!),
          ),
        ),
        payload: jsonEncode(message.data),
      );
    } catch (error) {
      debugPrint('Could not show the notification: $error');
    }
  }

  /// Where the push's picture is, if it has one.
  String? _imageUrlOf(RemoteMessage message) {
    final candidates = [
      message.notification?.android?.imageUrl,
      message.notification?.apple?.imageUrl,
      message.data['image_url'],
    ];
    for (final candidate in candidates) {
      final url = '${candidate ?? ''}'.trim();
      if (url.startsWith('http')) return url;
    }
    return null;
  }

  /// The picture's bytes, or null — a missing or slow image must never stop
  /// the notification itself from showing.
  Future<Uint8List?> _download(String url) async {
    try {
      final response = await Dio().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
        ),
      );
      final bytes = response.data;
      return bytes == null || bytes.isEmpty ? null : Uint8List.fromList(bytes);
    } catch (error) {
      debugPrint('Could not load the notification image: $error');
      return null;
    }
  }

  /// iOS attaches pictures from a file, so the bytes go to the temp folder.
  Future<List<DarwinNotificationAttachment>?> _iosAttachment(Uint8List bytes, String url) async {
    if (!Platform.isIOS) return null;
    try {
      final path = Uri.parse(url).path.toLowerCase();
      final ext = path.endsWith('.png')
          ? 'png'
          : path.endsWith('.gif')
              ? 'gif'
              : 'jpg';
      final file = File('${Directory.systemTemp.path}/push_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await file.writeAsBytes(bytes);
      return [DarwinNotificationAttachment(file.path)];
    } catch (_) {
      return null;
    }
  }

  void _handleTap(RemoteMessage message) {
    if (!_shellReady) {
      _pendingTap = message;
      return;
    }
    _route(message.data);
  }

  /// Called by the main shell once it is on screen, so a notification that
  /// launched the app is acted on then rather than against a splash screen.
  void markShellReady() {
    _shellReady = true;
    final pending = _pendingTap;
    if (pending == null) return;
    _pendingTap = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _route(pending.data));
  }

  /// Order pushes carry `order_id`; broadcasts may carry `link`. Anything
  /// else just opens the app, which is what tapping already did.
  void _route(Map<String, dynamic> data) {
    // Opening from a tap is also the moment the inbox changed.
    NotificationState.instance.refresh();
    final navigator = DeepLinks.navigatorKey.currentState;
    if (navigator == null) return;

    final orderId = int.tryParse('${data['order_id'] ?? ''}');
    if (orderId != null) {
      navigator.push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: orderId)));
      return;
    }

    final link = '${data['link'] ?? ''}'.trim();
    if (link.isNotEmpty) DeepLinks.instance.handleLink(link);
  }
}
