import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/api_config.dart';
import '../core/api_exception.dart';
import '../core/file_downloads.dart';
import '../core/money.dart';
import '../l10n/app_localizations.dart';
import '../models/order_tracking.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';
import '../widgets/order_stage_tracker.dart';
import '../widgets/state_views.dart';
import 'invoice_viewer_screen.dart';
import 'login_screen.dart';

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

  /// One download at a time — the button is disabled while this is set, so
  /// a second tap cannot start a second request.
  bool _isDownloadingInvoice = false;

  /// Where the order has got to. Fetched after the order itself, since it
  /// needs the order code and phone the order carries.
  OrderTracking? _tracking;

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
      _loadTracking();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// The stage list is decoration around the order itself — a failure here
  /// leaves the rest of the page alone.
  Future<void> _loadTracking() async {
    final code = _order?['order_code'] as String?;
    final phone = _order?['phone'] as String?;
    if (code == null || phone == null) return;
    try {
      final tracking = await OrderService.instance.tracking(orderCode: code, phone: phone);
      if (mounted) setState(() => _tracking = tracking);
    } catch (_) {
      // Leave the status line on its own.
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

  /// Downloads the invoice, then offers to read it or pass it on.
  Future<void> _openInvoice() async {
    if (_isDownloadingInvoice) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _isDownloadingInvoice = true);
    try {
      final file = await OrderService.instance.downloadInvoice(
        widget.orderId,
        orderCode: _order?['order_code'] as String?,
      );
      if (!mounted) return;
      _showInvoiceSheet(file);
    } on ApiException catch (e) {
      if (!mounted) return;
      switch (e.statusCode) {
        case 401:
          // Same as every other authenticated screen: the session is gone.
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
        case 404:
          _snack(l10n.invoiceNotAvailable);
        default:
          _snack(l10n.invoiceFailed, onRetry: _openInvoice);
      }
    } catch (_) {
      if (mounted) _snack(l10n.invoiceFailed, onRetry: _openInvoice);
    } finally {
      if (mounted) setState(() => _isDownloadingInvoice = false);
    }
  }

  void _showInvoiceSheet(File file) {
    final l10n = AppLocalizations.of(context);
    final code = _order?['order_code'] as String?;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.invoiceReady,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.inkStrong),
              ),
              const SizedBox(height: 4),
              Text(
                file.uri.pathSegments.last,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InvoiceViewerScreen(file: file, orderCode: code),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility_outlined, size: 20),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                label: Text(l10n.invoiceView),
              ),
              // Android can put the file straight into the phone's
              // Downloads folder; elsewhere the share sheet's "Save to
              // Files" is the native way, so only Share is offered.
              if (FileDownloads.isSupported) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _saveInvoiceToDownloads(sheetContext, file),
                  icon: const Icon(Icons.download_rounded, size: 20),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  label: Text(l10n.invoiceSave),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _shareInvoice(sheetContext, file, code),
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                label: Text(l10n.share),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Copies the downloaded invoice into the phone's Downloads folder.
  /// Pre-Android-10 returns null (no MediaStore) — the share sheet covers it.
  Future<void> _saveInvoiceToDownloads(BuildContext sheetContext, File file) async {
    final l10n = AppLocalizations.of(context);
    final name = file.uri.pathSegments.last;
    Navigator.of(sheetContext).pop();
    try {
      final saved = await FileDownloads.saveToDownloads(
        file,
        fileName: name,
        mimeType: 'application/pdf',
      );
      if (!mounted) return;
      if (saved == null) {
        _snack(l10n.invoiceSaveFailed);
      } else {
        _snack(l10n.invoiceSaved(saved));
      }
    } catch (_) {
      if (mounted) _snack(l10n.invoiceSaveFailed);
    }
  }

  Future<void> _shareInvoice(BuildContext sheetContext, File file, String? code) async {
    final l10n = AppLocalizations.of(context);
    final box = sheetContext.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        text: l10n.invoiceShareText(code ?? ''),
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  void _snack(String message, {VoidCallback? onRetry}) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: onRetry == null ? null : SnackBarAction(label: l10n.retry, onPressed: onRetry),
        ),
      );
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
        if (_tracking != null && _tracking!.stages.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Order stage', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          OrderStageTracker(tracking: _tracking!),
        ],
        const SizedBox(height: 16),
        Text('Items', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...items.map((raw) {
          final item = raw as Map;
          final product = item['product'] as Map?;
          final image = ApiConfig.resolveUrl(product?['image_url'] as String?);
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
                Text(formatPrice(item['subtotal'] as num?)),
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
        const SizedBox(height: 10),
        // The invoice is the server's PDF — downloading it is also how the
        // customer shares or files their own copy.
        ElevatedButton.icon(
          onPressed: _isDownloadingInvoice ? null : _openInvoice,
          icon: _isDownloadingInvoice
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.download_rounded, size: 20),
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          label: Text(
            _isDownloadingInvoice
                ? AppLocalizations.of(context).invoicePreparing
                : AppLocalizations.of(context).invoiceDownload,
          ),
        ),
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
            formatPrice(amount),
            style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
          ),
        ],
      ),
    );
  }
}
