import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/content_service.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';

/// Lists active storefront-wide coupons from `/coupons`. Per-order
/// eligibility is still checked at checkout (`/coupons/check`) — this is
/// just "here's what's available to try."
class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map> _coupons = [];

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
      final response = await ContentService.instance.coupons();
      final data = (response is Map ? response['data'] ?? response : {}) as Map;
      _coupons = ((data['coupons'] as List?) ?? []).map((e) => e as Map).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coupons & Offers')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const LoadingView()
            : _error != null
            ? ErrorView(message: _error!, onRetry: _load)
            : _coupons.isEmpty
            ? const EmptyView(
                icon: Icons.local_offer_outlined,
                message: 'No active coupons right now — check back soon.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _coupons.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _CouponCard(coupon: _coupons[index]),
              ),
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  final Map coupon;
  const _CouponCard({required this.coupon});

  @override
  Widget build(BuildContext context) {
    final code = coupon['code'] as String? ?? '';
    final description = coupon['description'] as String?;
    final discountType = coupon['discount_type'] as String?;
    final discountValue = (coupon['discount_value'] as num?)?.toDouble();
    final expiresAt = coupon['expires_at'] as String? ?? coupon['end_date'] as String?;

    final discountLabel = discountValue == null
        ? null
        : discountType == 'percentage'
        ? '${discountValue.toStringAsFixed(0)}% OFF'
        : '৳${discountValue.toStringAsFixed(0)} OFF';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
            child: Icon(Icons.local_offer, color: AppColors.accentDark, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(code, style: Theme.of(context).textTheme.titleSmall),
                    if (discountLabel != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.sale, borderRadius: BorderRadius.circular(999)),
                        child: Text(
                          discountLabel,
                          style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(description, style: TextStyle(color: AppColors.body, fontSize: 12.5)),
                ],
                if (expiresAt != null) ...[
                  const SizedBox(height: 4),
                  Text('Expires ${_formatDate(expiresAt)}', style: TextStyle(color: AppColors.muted, fontSize: 11.5)),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 18),
            tooltip: 'Copy code',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Copied "$code"')),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return '${parsed.day}/${parsed.month}/${parsed.year}';
  }
}
