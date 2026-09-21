import 'package:flutter/material.dart';

import '../core/money.dart';
import '../services/order_service.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import 'login_screen.dart';
import 'order_detail_screen.dart';

/// Order history: a stats strip (orders / active / spent), status filter
/// chips, and one card per order with code, date, item count, payment,
/// delivery area, total and a status pill. Paginates with "Load more".
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
    final canPop = Navigator.of(context).canPop();
    final appBar = AppBar(
      title: const Text('My Orders'),
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: canPop
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
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
                    Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.muted),
                    const SizedBox(height: 12),
                    Text('Sign in to see your orders.', style: TextStyle(color: AppColors.body)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 160,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        ),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 46)),
                        child: const Text('Sign In'),
                      ),
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
                ? const LoadingView()
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
          const _InlineEmpty(icon: Icons.receipt_long_outlined, message: 'You have no orders yet.')
        else if (visible.isEmpty)
          _InlineEmpty(icon: Icons.filter_list_off_rounded, message: 'No ${_filter.name} orders.')
        else
          for (final order in visible) ...[
            _OrderCard(
              order: order,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order['id'] as int)),
              ),
            ),
            const SizedBox(height: 14),
          ],
        if (_hasMore && _orders.isNotEmpty)
          OutlinedButton.icon(
            onPressed: _isLoadingMore ? null : _loadMore,
            icon: _isLoadingMore
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.expand_more_rounded, size: 18),
            label: Text(_isLoadingMore ? 'Loading…' : 'Load more orders'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
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
    return Row(
      children: [
        Expanded(child: _StatTile(label: 'Orders', value: '$total', icon: Icons.receipt_long_rounded)),
        const SizedBox(width: 10),
        Expanded(child: _StatTile(label: 'Active', value: '$active', icon: Icons.local_shipping_rounded)),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: _StatTile(label: 'Total spent', value: formatPrice(spent), icon: Icons.payments_rounded)),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.inkStrong),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ],
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
      color: selected ? AppColors.inkStrong : AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: selected ? AppColors.inkStrong : AppColors.line),
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
                color: selected ? AppColors.onAccent : AppColors.inkStrong,
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
  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final id = order['id'] as int;
    final code = order['order_code'] as String? ?? '#$id';
    final status = order['current_status'] as String? ?? '';
    final style = _statusStyle(status);
    final total = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final items = (order['total_items'] as num?)?.toInt() ?? 0;
    final payment = order['payment_method'] as String? ?? '';
    final paymentStatus = order['payment_status'] as String? ?? '';
    final area = (order['delivery_area'] is Map ? (order['delivery_area'] as Map)['name'] : null) as String?;
    final date = _formatDate(order['created_at'] as String?);
    final delivered = _statusKind(status) == _StatusKind.delivered;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Code + date | status pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#$code',
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.inkStrong),
                        ),
                        if (date.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(date, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
                    decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(999)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(style.icon, size: 13, color: style.fg),
                        const SizedBox(width: 4),
                        Text(status, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: style.fg)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: AppColors.line),
              const SizedBox(height: 12),
              // Meta chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaChip(icon: Icons.inventory_2_outlined, label: '$items item${items == 1 ? '' : 's'}'),
                  if (payment.isNotEmpty)
                    _MetaChip(
                      icon: Icons.payments_outlined,
                      label: paymentStatus.isNotEmpty ? '$payment · $paymentStatus' : payment,
                    ),
                  if (area != null && area.isNotEmpty) _MetaChip(icon: Icons.location_on_outlined, label: area),
                ],
              ),
              const SizedBox(height: 14),
              // Total | action
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                        Text(
                          formatPrice(total),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.inkStrong),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(delivered ? 'Buy Again' : 'View Details'),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.bodyStrong),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.bodyStrong)),
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  final IconData icon;
  final String message;
  const _InlineEmpty({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 72, 32, 32),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.muted),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}
