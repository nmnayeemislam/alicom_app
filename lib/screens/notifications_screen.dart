import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../core/deep_links.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';
import '../state/auth_state.dart';
import '../state/notification_state.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import 'login_screen.dart';
import 'order_detail_screen.dart';

/// The notification inbox: everything the backend pushed, plus the order
/// updates it stored for devices that never registered for FCM.
///
/// Rows are read on tap and then open what they point at — the order for an
/// `order.status`, the `link` for a broadcast.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _scrollController = ScrollController();

  List<AppNotification> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  String? _error;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (AuthState.instance.isAuthenticated) {
      _load();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) _loadMore();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await NotificationService.instance.list(page: 1);
      if (!mounted) return;
      setState(() {
        _items = page.notifications;
        _page = page.currentPage;
        _hasMore = page.hasMore;
      });
      NotificationState.instance.setUnreadCount(page.unreadCount);
    } catch (e) {
      if (!mounted) return;
      if (_handleUnauthorized(e)) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    setState(() => _isLoadingMore = true);
    try {
      final page = await NotificationService.instance.list(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...page.notifications];
        _page = page.currentPage;
        _hasMore = page.hasMore;
      });
      NotificationState.instance.setUnreadCount(page.unreadCount);
    } catch (_) {
      // Keep what is loaded; scrolling again retries.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /// A 401 means the session went away under us — drop to the sign-in
  /// screen rather than showing "Unauthenticated" as an error.
  bool _handleUnauthorized(Object error) {
    if (error is! ApiException || error.statusCode != 401) return false;
    NotificationState.instance.setUnreadCount(0);
    setState(() {
      _items = [];
      _error = null;
    });
    return true;
  }

  Future<void> _markAllAsRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      final result = await NotificationService.instance.markAllAsRead();
      if (!mounted) return;
      setState(() {
        _items = [
          for (final item in _items) item.isRead ? item : item.copyWith(isRead: true, readAt: DateTime.now()),
        ];
      });
      NotificationState.instance.setUnreadCount(result.unreadCount);
    } catch (e) {
      if (!mounted) return;
      if (_handleUnauthorized(e)) return;
      _snack('Could not mark them as read');
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  /// Removed straight away and put back if the API refuses.
  Future<void> _delete(AppNotification item, int index) async {
    setState(() => _items = [..._items]..removeAt(index));
    try {
      final unread = await NotificationService.instance.delete(item.id);
      NotificationState.instance.setUnreadCount(unread);
    } catch (e) {
      if (!mounted) return;
      setState(() => _items = [..._items]..insert(index.clamp(0, _items.length), item));
      if (_handleUnauthorized(e)) return;
      _snack('Could not delete that notification');
    }
  }

  Future<void> _open(AppNotification item, int index) async {
    if (!item.isRead) {
      setState(() {
        _items = [..._items]..[index] = item.copyWith(isRead: true, readAt: DateTime.now());
      });
      try {
        final result = await NotificationService.instance.markAsRead(item.id);
        NotificationState.instance.setUnreadCount(result.unreadCount);
      } catch (e) {
        if (!mounted) return;
        // Put the unread state back so the row still reads as new.
        setState(() => _items = [..._items]..[index] = item);
        _handleUnauthorized(e);
      }
    }
    if (!mounted) return;

    if (item.isOrder && item.orderId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: item.orderId!)),
      );
      return;
    }
    final link = item.link?.trim() ?? '';
    // Same path a push tap takes, so a link behaves the same either way.
    if (link.isNotEmpty) DeepLinks.instance.handleLink(link);
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AuthState.instance, NotificationState.instance]),
      builder: (context, _) {
        final signedIn = AuthState.instance.isAuthenticated;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              if (signedIn && NotificationState.instance.hasUnread)
                TextButton(
                  onPressed: _markingAll ? null : _markAllAsRead,
                  child: Text(_markingAll ? 'Marking…' : 'Mark all as read'),
                ),
            ],
          ),
          body: signedIn ? _buildBody() : _buildSignedOut(),
        );
      },
    );
  }

  Widget _buildSignedOut() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
              child: Icon(Icons.notifications_none_rounded, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(
              'Sign in to see your notifications',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.inkStrong),
            ),
            const SizedBox(height: 6),
            Text(
              'Order updates and offers land here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
                if (mounted && AuthState.instance.isAuthenticated) _load();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(190, 48),
                shape: const StadiumBorder(),
              ),
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load,
      child: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                EmptyView(
                  icon: Icons.notifications_none_rounded,
                  message: "You're all caught up — no notifications yet.",
                ),
              ],
            )
          : ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: _items.length + (_hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index >= _items.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  );
                }
                final item = _items[index];
                return Dismissible(
                  key: ValueKey(item.id),
                  direction: DismissDirection.endToStart,
                  background: _deleteBackground(),
                  onDismissed: (_) => _delete(item, index),
                  child: _NotificationTile(
                    notification: item,
                    onTap: () => _open(item, index),
                  ),
                );
              },
            ),
    );
  }

  Widget _deleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: AppColors.sale.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(Icons.delete_outline_rounded, color: AppColors.sale),
    );
  }
}

/// One inbox row: type icon, title and body, the time, and the broadcast's
/// picture when it has one. Unread rows carry a tinted surface and a dot.
class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final (icon, tint) = notification.isOrder
        ? (Icons.receipt_long_rounded, AppColors.primary)
        : (Icons.campaign_rounded, const Color(0xFFC98A00));

    return Material(
      color: unread ? AppColors.accentSoft.withValues(alpha: 0.45) : AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: unread ? AppColors.primary.withValues(alpha: 0.25) : AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 20, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                              color: AppColors.inkStrong,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: AppColors.sale, shape: BoxShape.circle),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.body),
                    ),
                    if (notification.imageUrl != null && notification.imageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          // Already a full URL from the API.
                          imageUrl: notification.imageUrl!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          _relativeTime(notification.createdAt),
                          style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                        ),
                        if (notification.hasDestination) ...[
                          const Spacer(),
                          Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.muted),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "just now" / "5 min ago" / "3 h ago" / "2 d ago", then the date.
  static String _relativeTime(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${time.day} ${months[time.month - 1]} ${time.year}';
  }
}
