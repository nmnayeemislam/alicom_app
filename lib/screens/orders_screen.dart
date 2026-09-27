import 'package:flutter/material.dart';

import '../core/money.dart';
import '../models/order_tracking.dart';
import '../services/order_service.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/order_stage_tracker.dart';
import '../widgets/state_views.dart';
import '../widgets/notification_bell.dart';
import '../widgets/tab_app_bar.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import 'order_detail_screen.dart';

/// Order history: a summary panel (spent / orders / active), status filter
/// chips, and one card per order — status-tinted icon, code and date, a
/// single meta line (items · payment · area) and the total.
/// Paginates with "Load more".
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

enum _OrderFilter { all, active, completed, cancelled }

class _OrdersScreenState extends State<OrdersScreen> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  List<Map> _orders = [];
  Map? _stats;
  int _page = 1;
  bool _hasMore = false;
  _OrderFilter _filter = _OrderFilter.all;
  int? _loadedForUserId;

  /// The stage flow, keyed by `is_regular_order`. The backend ties the flow
  /// to the order's type, not to the individual order, so one request per
  /// type covers the whole list instead of one per card.
  final Map<bool, OrderTracking> _flows = {};

  @override
  void initState() {
    super.initState();
    AuthState.instance.addListener(_onAuthChanged);
    if (AuthState.instance.isAuthenticated) _load();
  }

  @override
  void dispose() {
    AuthState.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final auth = AuthState.instance;
    if (auth.isAuthenticated && auth.user?.id != _loadedForUserId) {
      _load();
    } else if (!auth.isAuthenticated) {
      setState(() {
        _orders = [];
        _stats = null;
        _loadedForUserId = null;
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        OrderService.instance.myOrders(page: 1),
        // Stats are decoration; a failure there must not hide the orders.
        OrderService.instance.myStats().catchError((_) => null),
      ]);
      final data = _dataOf(results[0]);
      _orders = ((data['orders'] as List?) ?? []).map((e) => e as Map).toList();
      _page = 1;
      _hasMore = _hasMorePages(data);
      _stats = results[1] == null ? null : _dataOf(results[1]);
      _loadedForUserId = AuthState.instance.user?.id;
      _loadFlows();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final data = _dataOf(await OrderService.instance.myOrders(page: nextPage));
      final more = ((data['orders'] as List?) ?? []).map((e) => e as Map).toList();
      if (mounted) {
        setState(() {
          _orders = [..._orders, ...more];
          _page = nextPage;
          _hasMore = _hasMorePages(data);
        });
      }
    } catch (_) {
      // Keep what is loaded; the button stays tappable to retry.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /// Fetches the flow once for each kind of order on screen. Silent on
  /// failure — the cards simply keep their status pill.
  Future<void> _loadFlows() async {
    for (final order in _orders) {
      final regular = order['is_regular_order'] != false;
      if (_flows.containsKey(regular)) continue;
      final code = order['order_code'] as String?;
      final phone = order['phone'] as String?;
      if (code == null || phone == null) continue;
      // Marked before the call so two orders of the same kind do not both
      // fire one off.
      _flows[regular] = const OrderTracking();
      try {
        final tracking = await OrderService.instance.tracking(orderCode: code, phone: phone);
        if (!mounted) return;
        setState(() => _flows[regular] = tracking);
      } catch (_) {
        _flows.remove(regular);
      }
    }
  }

  /// The shared flow, re-pointed at this order's own status.
  OrderTracking? _flowFor(Map order) {
    final flow = _flows[order['is_regular_order'] != false];
    if (flow == null || flow.stages.isEmpty) return null;
    final status = order['current_status'] as String? ?? '';
    final index = flow.stages.indexWhere((s) => s.status == status);
    // A status outside the flow (cancelled, refunded) has no place on a
    // progress bar.
    if (index < 0) return null;
    return OrderTracking(
      orderCode: order['order_code'] as String? ?? '',
      currentStatus: status,
      isRegularOrder: flow.isRegularOrder,
      stages: [
        for (var i = 0; i < flow.stages.length; i++)
          OrderStage(
            status: flow.stages[i].status,
            isCompleted: i <= index,
            isCurrent: i == index,
          ),
      ],
    );
  }

  static Map _dataOf(dynamic response) =>
      (response is Map ? response['data'] ?? response : {}) as Map;

  static bool _hasMorePages(Map data) {
    final pagination = data['pagination'];
    return pagination is Map && pagination['has_more_pages'] == true;
  }

  List<Map> get _visibleOrders => switch (_filter) {
        _OrderFilter.all => _orders,
        _OrderFilter.active => _orders.where((o) => _kindOf(o) == _StatusKind.active).toList(),
        _OrderFilter.completed => _orders.where((o) => _kindOf(o) == _StatusKind.delivered).toList(),
        _OrderFilter.cancelled => _orders.where((o) => _kindOf(o) == _StatusKind.cancelled).toList(),
      };

  static _StatusKind _kindOf(Map order) => _statusKind(order['current_status'] as String? ?? '');

  @override
  Widget build(BuildContext context) {
    final appBar = TabAppBar(
      title: 'My Orders',
      action: const NotificationBell(),
    );

    return ListenableBuilder(
      listenable: AuthState.instance,
      builder: (context, _) {
        if (!AuthState.instance.isAuthenticated) {
          return Scaffold(
            appBar: appBar,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
                      child: Icon(Icons.receipt_long_rounded, size: 36, color: AppColors.primary),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Sign in to see your orders',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.inkStrong),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your order history and delivery updates live here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.muted),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(190, 48),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Sign In'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: appBar,
          body: RefreshIndicator(
            onRefresh: _load,
            child: _isLoading
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: const [_OrderSkeleton()],
                  )
                : _error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : _buildList(),
          ),
        );
      },
    );
  }

  Widget _buildList() {
    final visible = _visibleOrders;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        if (_stats != null) ...[
          _StatsStrip(stats: _stats!),
          const SizedBox(height: 18),
        ],
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final f in _OrderFilter.values) ...[
                _FilterChip(
                  label: switch (f) {
                    _OrderFilter.all => 'All',
                    _OrderFilter.active => 'Active',
                    _OrderFilter.completed => 'Completed',
                    _OrderFilter.cancelled => 'Cancelled',
                  },
                  selected: _filter == f,
                  onTap: () => setState(() => _filter = f),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        // EmptyView is itself a scrollable, so it cannot sit inside this
        // ListView — inline a plain empty state instead.
        if (_orders.isEmpty)
          _InlineEmpty(
            icon: Icons.receipt_long_rounded,
            message: 'No orders yet',
            onShop: () => MainShell.selectTab(context, 0),
          )
        else if (visible.isEmpty)
          _InlineEmpty(
            icon: Icons.filter_list_off_rounded,
            message: 'No ${_filter.name} orders',
          )
        else
          for (final order in visible) ...[
            _OrderCard(
              order: order,
              tracking: _flowFor(order),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order['id'] as int)),
              ),
            ),
            const SizedBox(height: 14),
          ],
        if (_hasMore && _orders.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: OutlinedButton.icon(
              onPressed: _isLoadingMore ? null : _loadMore,
              icon: _isLoadingMore
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.expand_more_rounded, size: 18),
              label: Text(_isLoadingMore ? 'Loading…' : 'Load more orders'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
                side: BorderSide(color: AppColors.line),
                foregroundColor: AppColors.inkStrong,
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Status → colour/kind mapping shared by the pill and the filter chips.

enum _StatusKind { active, delivered, cancelled }

_StatusKind _statusKind(String status) {
  final s = status.toLowerCase();
  if (s.contains('deliver') && !s.contains('out for')) return _StatusKind.delivered;
  if (s.contains('cancel') || s.contains('refund') || s.contains('return') || s.contains('fail')) {
    return _StatusKind.cancelled;
  }
  return _StatusKind.active;
}

({Color fg, Color bg, IconData icon}) _statusStyle(String status) {
  final s = status.toLowerCase();
  if (_statusKind(status) == _StatusKind.delivered) {
    return (fg: const Color(0xFF1FA65A), bg: const Color(0xFF1FA65A).withValues(alpha: 0.12), icon: Icons.check_circle_rounded);
  }
  if (_statusKind(status) == _StatusKind.cancelled) {
    return (fg: AppColors.sale, bg: AppColors.sale.withValues(alpha: 0.12), icon: Icons.cancel_rounded);
  }
  if (s.contains('ship') || s.contains('transit') || s.contains('out for') || s.contains('dispatch')) {
    return (fg: const Color(0xFF0284C7), bg: const Color(0xFF0284C7).withValues(alpha: 0.12), icon: Icons.local_shipping_rounded);
  }
  if (s.contains('process') || s.contains('confirm') || s.contains('pack') || s.contains('prepar')) {
    return (fg: const Color(0xFFC98A00), bg: const Color(0xFFF7B500).withValues(alpha: 0.16), icon: Icons.autorenew_rounded);
  }
  return (fg: AppColors.primary, bg: AppColors.accentSoft, icon: Icons.receipt_long_rounded);
}

String _formatDate(String? iso) {
  if (iso == null) return '';
  final parsed = DateTime.tryParse(iso)?.toLocal();
  if (parsed == null) return '';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hour12 = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
  final minute = parsed.minute.toString().padLeft(2, '0');
  final ampm = parsed.hour < 12 ? 'AM' : 'PM';
  return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year} · $hour12:$minute $ampm';
}

// ---------------------------------------------------------------------------

class _StatsStrip extends StatelessWidget {
  final Map stats;
  const _StatsStrip({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = (stats['total_orders'] as num?)?.toInt() ?? 0;
    final active = (stats['active_orders'] as num?)?.toInt() ?? 0;
    final spent = (stats['total_purchase'] as num?)?.toDouble() ?? 0;
    // One panel rather than three floating tiles: the amount is what a
    // shopper looks for, so it leads and the counts sit beside it.
    return _Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total spent',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.muted),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatPrice(spent),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: AppColors.inkStrong,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 38, color: AppColors.line),
          Expanded(flex: 2, child: _StatTile(label: 'Orders', value: '$total')),
          Container(width: 1, height: 38, color: AppColors.line),
          Expanded(flex: 2, child: _StatTile(label: 'Active', value: '$active')),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.inkStrong),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          style: TextStyle(fontSize: 11.5, color: AppColors.muted),
        ),
      ],
    );
  }
}

/// White card with a hairline edge and a soft shadow.
///
/// The shadow sits on an outer box: painted inside a clipping [Material] it
/// washes the card's own surface grey.
class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const _Panel({required this.child, required this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(20));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 3, offset: const Offset(0, 1)),
        ],
      ),
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: AppColors.line.withValues(alpha: 0.8)),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.bodyStrong,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map order;
  final VoidCallback onTap;

  /// Where this order sits in its flow; null while it loads, or for a
  /// status that is not part of one.
  final OrderTracking? tracking;

  const _OrderCard({required this.order, required this.onTap, this.tracking});

  @override
  Widget build(BuildContext context) {
    final id = order['id'] as int;
    final code = order['order_code'] as String? ?? '$id';
    final status = order['current_status'] as String? ?? '';
    final style = _statusStyle(status);
    final total = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final items = (order['total_items'] as num?)?.toInt() ?? 0;
    final payment = order['payment_method'] as String? ?? '';
    final paymentStatus = order['payment_status'] as String? ?? '';
    final area = (order['delivery_area'] is Map ? (order['delivery_area'] as Map)['name'] : null) as String?;
    final date = _formatDate(order['created_at'] as String?);

    // Everything secondary on one line instead of chips that wrapped onto
    // a second row and made every card a different height.
    final meta = [
      '$items item${items == 1 ? '' : 's'}',
      if (payment.isNotEmpty) payment,
      if (area != null && area.isNotEmpty) area,
    ].join('  ·  ');

    return _Panel(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Status as a tinted tile, so the state of an order reads from
              // the left edge while scanning the list.
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(13)),
                child: Icon(style.icon, size: 20, color: style.fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#$code',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: AppColors.inkStrong,
                      ),
                    ),
                    if (date.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(label: status, style: style),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: AppColors.body),
          ),
          if (paymentStatus.isNotEmpty) ...[
            const SizedBox(height: 8),
            _PaymentBadge(status: paymentStatus),
          ],
          if (tracking != null) ...[
            const SizedBox(height: 12),
            OrderStageBar(tracking: tracking!),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Total', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatPrice(total),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: AppColors.inkStrong,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // The whole card already opens the order; this is the visible
              // affordance for it rather than a second destination.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View details',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The order's current status, in its own colour.
class _StatusPill extends StatelessWidget {
  final String label;
  final ({Color fg, Color bg, IconData icon}) style;
  const _StatusPill({required this.label, required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: style.fg),
      ),
    );
  }
}

/// "Paid" / "Pending" on the payment, which is the one thing a shopper may
/// still have to act on.
class _PaymentBadge extends StatelessWidget {
  final String status;
  const _PaymentBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final paid = status.toLowerCase().contains('paid');
    final color = paid ? const Color(0xFF1FA65A) : const Color(0xFFC98A00);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(paid ? Icons.verified_rounded : Icons.schedule_rounded, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          paid ? 'Payment $status' : 'Payment $status',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  final IconData icon;
  final String message;

  /// Shown when the whole history is empty — a filter turning up nothing
  /// needs no call to action.
  final VoidCallback? onShop;

  const _InlineEmpty({required this.icon, required this.message, this.onShop});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 56, 32, 32),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.inkStrong),
          ),
          if (onShop != null) ...[
            const SizedBox(height: 6),
            Text(
              'Once you place an order it will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onShop,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(190, 48),
                shape: const StadiumBorder(),
              ),
              child: const Text('Start shopping'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Grey stand-ins with the shape of an order card, pulsing gently while the
/// first page loads — steadier than a spinner that leaves the page blank.
class _OrderSkeleton extends StatefulWidget {
  const _OrderSkeleton();

  @override
  State<_OrderSkeleton> createState() => _OrderSkeletonState();
}

class _OrderSkeletonState extends State<_OrderSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.55, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            _Panel(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _bar(40, 40, radius: 13),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _bar(110, 13),
                          const SizedBox(height: 7),
                          _bar(150, 10),
                        ],
                      ),
                      const Spacer(),
                      _bar(78, 22, radius: 999),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _bar(200, 11),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: AppColors.line),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _bar(120, 18),
                      const Spacer(),
                      _bar(90, 14),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _bar(double width, double height, {double radius = 6}) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.line,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}
