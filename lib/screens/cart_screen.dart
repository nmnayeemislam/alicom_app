import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/api_config.dart';
import '../core/api_exception.dart';
import '../core/money.dart';
import '../services/commerce_service.dart';
import '../state/cart_state.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import 'checkout_screen.dart';

/// Cart laid out like the storefront mock: round back / "My Cart" / clear
/// header, one card per line with the image on a tinted tile, title, rating
/// (when the API sends one), unit price and a ⊖ qty ⊕ stepper; then a promo
/// code row, a "Bill Details" summary and a sticky Checkout button.
class CartScreen extends StatefulWidget {
  /// Pre-fills the promo field and applies it once the cart has loaded —
  /// the "Use now" path from a redeemed points coupon.
  final String? initialCoupon;

  const CartScreen({super.key, this.initialCoupon});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _promoController = TextEditingController();
  bool _isCheckingPromo = false;
  String? _promoError;
  String? _appliedPromo;
  double _discount = 0;

  @override
  void initState() {
    super.initState();
    final coupon = widget.initialCoupon?.trim();
    if (coupon != null && coupon.isNotEmpty) _promoController.text = coupon;
    // Kick the refresh off after the first frame: CartState notifies
    // synchronously and this route is still being built when initState runs.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await CartState.instance.refresh();
      // Apply against the real cart, so the backend's own verdict (minimum
      // order, owner-only, expired…) is what the shopper sees.
      if (mounted && _promoController.text.trim().isNotEmpty) _applyPromo();
    });
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  double get _subtotal => CartState.instance.items.fold<double>(
        0,
        (sum, item) => sum + (((item as Map)['subtotal'] as num?)?.toDouble() ?? 0),
      );

  double get _payable => (_subtotal - _discount).clamp(0, double.infinity);

  Future<void> _applyPromo() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isCheckingPromo = true;
      _promoError = null;
    });
    try {
      final productIds = CartState.instance.couponProductIds;
      if (productIds.isEmpty) {
        setState(() => _promoError = 'Add items to your cart to use this code.');
        return;
      }
      final response = await CommerceService.instance.checkCoupon(coupon: code, productIds: productIds);
      final data = (response is Map ? response['data'] ?? response : {}) as Map;
      if (data['eligible'] != true) {
        final message = response is Map ? response['message'] as String? : null;
        setState(() {
          _promoError = message?.isNotEmpty == true ? message : 'This code is not eligible for your cart.';
          _appliedPromo = null;
          _discount = 0;
        });
        return;
      }
      setState(() {
        _appliedPromo = code;
        _discount = (data['discount_amount'] as num?)?.toDouble() ?? 0;
      });
    } on ApiException catch (e) {
      setState(() {
        _promoError = e.message;
        _appliedPromo = null;
        _discount = 0;
      });
    } catch (_) {
      setState(() {
        _promoError = 'Could not validate the promo code.';
        _appliedPromo = null;
        _discount = 0;
      });
    } finally {
      if (mounted) setState(() => _isCheckingPromo = false);
    }
  }

  void _removePromo() {
    setState(() {
      _appliedPromo = null;
      _discount = 0;
      _promoError = null;
      _promoController.clear();
    });
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear cart?'),
        content: const Text('All items will be removed from your cart.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Clear', style: TextStyle(color: AppColors.sale)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await CartState.instance.clear();
      _removePromo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        titleSpacing: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: _RoundIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: const Text('My Cart'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ListenableBuilder(
              listenable: CartState.instance,
              builder: (context, _) => _RoundIconButton(
                icon: Icons.delete_sweep_outlined,
                onTap: CartState.instance.items.isEmpty ? null : _confirmClear,
              ),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: CartState.instance,
        builder: (context, _) {
          final cart = CartState.instance;
          if (cart.isLoading && cart.items.isEmpty) {
            return const LoadingView();
          }
          if (cart.items.isEmpty) {
            return const EmptyView(
              icon: Icons.shopping_bag_outlined,
              message: 'Your cart is empty.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              for (final item in cart.items) ...[
                _CartItemCard(item: item as Map, cart: cart),
                const SizedBox(height: 14),
              ],
              const SizedBox(height: 4),
              _buildPromoRow(),
              const SizedBox(height: 22),
              Text(
                'Bill Details',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppColors.inkStrong),
              ),
              const SizedBox(height: 10),
              _BillCard(
                rows: [
                  _BillRow(label: 'Total item price', value: formatPrice(_subtotal)),
                  if (_discount > 0)
                    _BillRow(label: 'Total discount', value: '-${formatPrice(_discount)}', valueColor: const Color(0xFF1FA65A)),
                  _BillRow(label: 'Delivery', value: 'At checkout', muted: true),
                  _BillRow(label: 'Total payable', value: formatPrice(_payable), isTotal: true),
                ],
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: CartState.instance,
        builder: (context, _) {
          if (CartState.instance.items.isEmpty) return const SizedBox.shrink();
          return Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CheckoutScreen(initialCoupon: _appliedPromo)),
                  ),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Checkout'),
                      const SizedBox(width: 10),
                      Container(width: 1, height: 16, color: Colors.white.withValues(alpha: 0.35)),
                      const SizedBox(width: 10),
                      Text(formatPrice(_payable), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromoRow() {
    if (_appliedPromo != null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1FA65A).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1FA65A).withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF1FA65A)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '"$_appliedPromo" applied — saving ${formatPrice(_discount)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkStrong),
              ),
            ),
            IconButton(
              onPressed: _removePromo,
              icon: Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
              visualDensity: VisualDensity.compact,
              tooltip: 'Remove promo',
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _promoController,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _applyPromo(),
                decoration: InputDecoration(
                  hintText: 'Enter Promo Code',
                  prefixIcon: Icon(Icons.confirmation_number_outlined, size: 20, color: AppColors.muted),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _isCheckingPromo ? null : _applyPromo,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(92, 50),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: _isCheckingPromo
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Apply'),
            ),
          ],
        ),
        if (_promoError != null) ...[
          const SizedBox(height: 6),
          Text(_promoError!, style: TextStyle(color: AppColors.sale, fontSize: 12.5)),
        ],
      ],
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final Map item;
  final CartState cart;
  const _CartItemCard({required this.item, required this.cart});

  @override
  Widget build(BuildContext context) {
    final itemId = item['id'] as int?;
    final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final title = item['product_title'] as String? ?? 'Item';
    final image = ApiConfig.resolveUrl(item['product_image'] as String?);
    final inStock = item['in_stock'] != false;
    // Rating fields are optional on cart lines; render the row only when
    // the API actually sends them.
    final rating = (item['average_rating'] ?? item['rating']) as num?;
    final reviews = (item['reviews_count'] ?? item['review_count']) as num?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 96,
              height: 96,
              color: AppColors.background,
              padding: const EdgeInsets.all(8),
              child: image != null && image.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.contain,
                      errorWidget: (_, _, _) => Icon(Icons.image_not_supported_outlined, color: AppColors.muted),
                    )
                  : Icon(Icons.image_not_supported_outlined, color: AppColors.muted),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.25, color: AppColors.inkStrong),
                ),
                const SizedBox(height: 4),
                if (rating != null && rating > 0)
                  Row(
                    children: [
                      Text(
                        rating.toStringAsFixed(1),
                        style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
                      ),
                      if (reviews != null) ...[
                        const SizedBox(width: 4),
                        Text('(${reviews.toInt()} Reviews)', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                      const SizedBox(width: 6),
                      ...List.generate(
                        5,
                        (i) => Icon(
                          i < rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 13,
                          color: const Color(0xFFF7B500),
                        ),
                      ),
                    ],
                  )
                else if (!inStock)
                  Text('Out of stock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.sale))
                else
                  Text('${formatPrice(price)} each', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatPrice(price * quantity),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.inkStrong),
                      ),
                    ),
                    if (itemId != null)
                      _Stepper(
                        quantity: quantity,
                        onDecrement: () => quantity > 1 ? cart.updateQuantity(itemId, quantity - 1) : cart.removeItem(itemId),
                        onIncrement: inStock ? () => cart.updateQuantity(itemId, quantity + 1) : null,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ⊖ qty ⊕ — outlined minus (turns into a bin at qty 1), filled plus.
class _Stepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback? onIncrement;
  const _Stepper({required this.quantity, required this.onDecrement, required this.onIncrement});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: quantity > 1 ? Icons.remove_rounded : Icons.delete_outline_rounded,
          filled: false,
          onTap: onDecrement,
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.inkStrong),
          ),
        ),
        _StepButton(icon: Icons.add_rounded, filled: true, onTap: onIncrement),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;
  const _StepButton({required this.icon, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: filled ? AppColors.primary : AppColors.card,
        shape: CircleBorder(side: BorderSide(color: filled ? AppColors.primary : AppColors.lineStrong)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(icon, size: 16, color: filled ? AppColors.onAccent : AppColors.inkStrong),
          ),
        ),
      ),
    );
  }
}

class _BillRow {
  final String label;
  final String value;
  final bool isTotal;
  final bool muted;
  final Color? valueColor;
  const _BillRow({required this.label, required this.value, this.isTotal = false, this.muted = false, this.valueColor});
}

class _BillCard extends StatelessWidget {
  final List<_BillRow> rows;
  const _BillCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.line),
            Padding(
              padding: EdgeInsets.symmetric(vertical: rows[i].isTotal ? 14 : 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[i].label,
                      style: TextStyle(
                        fontSize: rows[i].isTotal ? 15 : 13.5,
                        fontWeight: rows[i].isTotal ? FontWeight.w700 : FontWeight.w500,
                        color: rows[i].isTotal ? AppColors.inkStrong : AppColors.body,
                      ),
                    ),
                  ),
                  Text(
                    rows[i].value,
                    style: TextStyle(
                      fontSize: rows[i].isTotal ? 17 : 13.5,
                      fontWeight: rows[i].isTotal ? FontWeight.w800 : FontWeight.w600,
                      color: rows[i].valueColor ?? (rows[i].muted ? AppColors.muted : AppColors.inkStrong),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Material(
        color: AppColors.card,
        shape: CircleBorder(side: BorderSide(color: AppColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 21, color: AppColors.inkStrong),
          ),
        ),
      ),
    );
  }
}
