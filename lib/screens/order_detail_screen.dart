import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _isLoading = true;
  String? _error;
  Map? _order;
  bool _isActionBusy = false;

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
      final response = await OrderService.instance.myOrder(widget.orderId);
      final data = (response is Map ? response['data'] ?? response : {}) as Map;
      _order = (data['order'] as Map?) ?? data;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel order?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, cancel')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isActionBusy = true);
    try {
      await OrderService.instance.cancelOrder(widget.orderId);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isActionBusy = false);
    }
  }

  Future<void> _requestRefund() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request refund'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Tell us what went wrong'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, reasonController.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;

    setState(() => _isActionBusy = true);
    try {
      await OrderService.instance.requestRefund(widget.orderId, reason: reason);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isActionBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_order?['order_code'] as String? ?? 'Order')),
      body: _isLoading
          ? const LoadingView()
          : _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : _order == null
          ? const EmptyView(icon: Icons.receipt_long_outlined, message: 'Order not found.')
          : _buildDetail(_order!),
    );
  }

  Widget _buildDetail(Map order) {
    final items = (order['items'] as List?) ?? [];
    final canCancel = order['can_cancel'] == true;
    final refundStatus = order['refund_status'] as String?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: ${order['current_status']}', style: Theme.of(context).textTheme.titleSmall),
              if (order['delivery_address'] != null) ...[
                const SizedBox(height: 6),
                Text('Delivery: ${order['delivery_address']}', style: TextStyle(color: AppColors.muted)),
              ],
              if (order['payment_method'] != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Payment: ${order['payment_method']} (${order['payment_status'] ?? '-'})',
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Items', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...items.map((raw) {
          final item = raw as Map;
          final product = item['product'] as Map?;
          final image = product?['image_url'] as String?;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: image != null && image.isNotEmpty
                        ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover)
                        : Container(color: AppColors.surface),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    product?['name'] as String? ?? 'Item',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('x${item['quantity']}'),
                const SizedBox(width: 8),
                Text('৳${((item['subtotal'] as num?) ?? 0).toStringAsFixed(0)}'),
              ],
            ),
          );
        }),
        const Divider(height: 24),
        _totalsRow('Discount', order['discount']),
        _totalsRow('Delivery', order['delivery_charge']),
        _totalsRow('Total', order['total_amount'], bold: true),
        const SizedBox(height: 20),
        if (canCancel)
          OutlinedButton(
            onPressed: _isActionBusy ? null : _cancelOrder,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Order'),
          )
        else if (refundStatus == null || refundStatus == 'none')
          OutlinedButton(
            onPressed: _isActionBusy ? null : _requestRefund,
            child: const Text('Request Refund'),
          )
        else
          Text('Refund status: $refundStatus', style: TextStyle(color: AppColors.muted)),
      ],
    );
  }

  Widget _totalsRow(String label, dynamic value, {bool bold = false}) {
    final amount = (value as num?)?.toDouble() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null),
          Text(
            '৳${amount.toStringAsFixed(0)}',
            style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
          ),
        ],
      ),
    );
  }
}
