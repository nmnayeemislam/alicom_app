import 'package:flutter/material.dart';

import '../services/order_service.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await OrderService.instance.myOrders();
      final data = (response is Map ? response['data'] ?? response : {}) as Map;
      _orders = ((data['orders'] as List?) ?? []).map((e) => e as Map).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const LoadingView()
            : _error != null
            ? ErrorView(message: _error!, onRetry: _load)
            : _orders.isEmpty
            ? const EmptyView(
                icon: Icons.receipt_long_outlined,
                message: 'You have no orders yet.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final order = _orders[index];
                  final id = order['id'] as int;
                  final status = order['current_status'] as String? ?? '';
                  final total = (order['total_amount'] as num?)?.toDouble() ?? 0;

                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: id)),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order['order_code'] as String? ?? 'Order #$id',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${order['total_items'] ?? 0} item(s) · ৳${total.toStringAsFixed(0)}',
                                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          _StatusChip(status: status),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, color: AppColors.accentDark, fontWeight: FontWeight.w600),
      ),
    );
  }
}
