import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_config.dart';
import '../core/auth_gate.dart';
import '../core/api_exception.dart';
import '../core/money.dart';
import '../services/commerce_service.dart';
import '../services/settings_service.dart';
import '../state/auth_state.dart';
import '../state/cart_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_loader.dart';
import '../widgets/state_views.dart';
import 'main_shell.dart';

class _DeliveryArea {
  final int id;
  final String label;
  final double baseCharge;
  _DeliveryArea({required this.id, required this.label, required this.baseCharge});
}

class _PaymentMethod {
  final String code;
  final String label;
  _PaymentMethod({required this.code, required this.label});
}

/// Places a cart order via `/checkout/order` (StoreCheckoutOrderRequest):
/// phone is the only required field; the bearer token (if signed in) lets
/// the backend attach the order to the account instead of a guest phone
/// lookup, per CheckoutOrderController's own comment.
class CheckoutScreen extends StatefulWidget {
  /// Promo code already validated on the cart screen; it is re-checked here
  /// so the discount shown is always the server's answer.
  final String? initialCoupon;

  const CheckoutScreen({super.key, this.initialCoupon});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _couponController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isLoadingOptions = true;
  String? _loadError;
  List<_DeliveryArea> _areas = [];
  List<_PaymentMethod> _paymentMethods = [];

  _DeliveryArea? _selectedArea;
  String _selectedPaymentMethod = 'cod';

  bool _isCheckingDelivery = false;
  double? _deliveryCharge;

  bool _isCheckingCoupon = false;
  String? _couponError;
  double _discountAmount = 0;
  String? _appliedCoupon;

  bool _isSubmitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _phoneController.text = AuthState.instance.user?.phone ?? '';
    _nameController.text = AuthState.instance.user?.name ?? '';
    _loadOptions();
    final coupon = widget.initialCoupon?.trim();
    if (coupon != null && coupon.isNotEmpty) {
      _couponController.text = coupon;
      _applyCoupon();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _couponController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _isLoadingOptions = true;
      _loadError = null;
    });
    try {
      final zonesResponse = await SettingsService.instance.deliveryZones();
      final zonesData = (zonesResponse is Map ? zonesResponse['data'] ?? zonesResponse : {}) as Map;
      final countries = zonesData['countries'] as List? ?? [];
      final areas = <_DeliveryArea>[];
      for (final country in countries) {
        final countryMap = country as Map;
        final countryName = countryMap['name'] as String? ?? '';
        for (final area in (countryMap['areas'] as List? ?? [])) {
          final areaMap = area as Map;
          areas.add(_DeliveryArea(
            id: areaMap['id'] as int,
            label: countryName.isNotEmpty
                ? '$countryName — ${areaMap['name']}'
                : '${areaMap['name']}',
            baseCharge: (areaMap['delivery_charge'] as num?)?.toDouble() ?? 0,
          ));
        }
      }

      final methodsResponse = await SettingsService.instance.paymentMethods();
      final methodsData = (methodsResponse is Map ? methodsResponse['data'] ?? methodsResponse : {}) as Map;
      final methods = (methodsData['methods'] as List? ?? [])
          .map((m) => _PaymentMethod(
                code: (m as Map)['code'] as String,
                label: m['label'] as String? ?? m['code'] as String,
              ))
          .toList();

      _areas = areas;
      _paymentMethods = methods.isNotEmpty
          ? methods
          : [_PaymentMethod(code: 'cod', label: 'Cash on Delivery')];
      _selectedPaymentMethod = _paymentMethods.first.code;
    } catch (e) {
      _loadError = e.toString();
    } finally {
      if (mounted) setState(() => _isLoadingOptions = false);
    }
  }

  List<Map<String, dynamic>> get _cartProducts => CartState.instance.items
      .map((item) => {
            'product_id': (item as Map)['product_id'],
            'quantity': item['quantity'],
          })
      .toList();

  Future<void> _onAreaChanged(_DeliveryArea? area) async {
    setState(() {
      _selectedArea = area;
      _deliveryCharge = area?.baseCharge;
    });
    if (area == null) return;

    setState(() => _isCheckingDelivery = true);
    try {
      final response = await SettingsService.instance.deliveryZoneCharge(
        deliveryAreaId: area.id,
        products: _cartProducts,
      );
      final data = (response is Map ? response['data'] ?? response : {}) as Map;
      final total = (data['total_charge'] as num?)?.toDouble();
      if (mounted && total != null) setState(() => _deliveryCharge = total);
    } catch (_) {
      // Keep the area's flat charge as a fallback estimate.
    } finally {
      if (mounted) setState(() => _isCheckingDelivery = false);
    }
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isCheckingCoupon = true;
      _couponError = null;
    });
    try {
      final response = await CommerceService.instance.checkCoupon(
        coupon: code,
        productIds: CartState.instance.couponProductIds,
      );
      final data = (response is Map ? response['data'] ?? response : {}) as Map;
      final eligible = data['eligible'] == true;
      if (!eligible) {
        final message = response is Map ? response['message'] as String? : null;
        setState(() {
          _couponError = message?.isNotEmpty == true ? message : 'Coupon is not eligible for this order.';
          _discountAmount = 0;
          _appliedCoupon = null;
        });
        return;
      }
      setState(() {
        _discountAmount = (data['discount_amount'] as num?)?.toDouble() ?? 0;
        _appliedCoupon = code;
      });
    } on ApiException catch (e) {
      setState(() {
        _couponError = e.message;
        _discountAmount = 0;
        _appliedCoupon = null;
      });
    } catch (e) {
      setState(() {
        _couponError = 'Could not validate coupon.';
        _discountAmount = 0;
        _appliedCoupon = null;
      });
    } finally {
      if (mounted) setState(() => _isCheckingCoupon = false);
    }
  }

  double get _subtotal => CartState.instance.items.fold<double>(
        0,
        (sum, item) => sum + (((item as Map)['subtotal'] as num?)?.toDouble() ?? 0),
      );

  double get _total => (_subtotal - _discountAmount + (_deliveryCharge ?? 0)).clamp(0, double.infinity);

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (CartState.instance.items.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      final response = await CommerceService.instance.placeCheckoutOrder(
        phone: _phoneController.text.trim(),
        name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        deliveryAreaId: _selectedArea?.id,
        products: _cartProducts,
        coupon: _appliedCoupon,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        paymentMethod: _selectedPaymentMethod,
      );
      final data = (response is Map ? response['data'] ?? response : {}) as Map;
      final order = (data['order'] as Map?) ?? data;
      final orderCode = order['order_code'] as String? ?? order['order_number'] as String?;
      // An online method (Stripe) comes back with a hosted checkout page.
      // Cash on delivery has none, and the order is simply placed.
      final paymentUrl = (data['payment_url'] as String?)?.trim();

      await CartState.instance.clear();

      if (!mounted) return;
      if (paymentUrl != null && paymentUrl.isNotEmpty) {
        await _openPaymentPage(paymentUrl, orderCode);
      } else {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Order placed'),
            content: Text(
              orderCode != null
                  ? 'Your order $orderCode has been placed successfully.'
                  : 'Your order has been placed successfully.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } on ApiException catch (e) {
      setState(() => _submitError = e.message);
    } catch (e) {
      setState(() => _submitError = 'Could not place your order. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Shown when the session ended between filling the cart and paying —
  /// the order would be rejected, so it is better to say so here.
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
              child: Icon(Icons.lock_outline_rounded, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(
              'Sign in to check out',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.inkStrong),
            ),
            const SizedBox(height: 6),
            Text(
              'Your cart is kept with your account.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () async {
                if (!await requireSignIn(context)) return;
                if (!mounted) return;
                // Prefill from the account that just signed in, then fetch
                // the delivery zones the form needs.
                _phoneController.text = AuthState.instance.user?.phone ?? '';
                _nameController.text = AuthState.instance.user?.name ?? '';
                _loadOptions();
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

  /// Hands the customer to the payment provider's own page.
  ///
  /// Opened in an in-app browser tab (Custom Tabs on Android, Safari View
  /// on iOS) rather than a WebView: card fields and 3-D Secure belong in
  /// the system browser, and the customer can see the real URL and padlock.
  ///
  /// Whether the payment succeeded is the backend's to know — Stripe tells
  /// it by webhook — so the app sends the customer to the order, where the
  /// payment status is shown, instead of guessing from the browser closing.
  Future<void> _openPaymentPage(String url, String? orderCode) async {
    final uri = Uri.tryParse(url);
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (_) {
        opened = false;
      }
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(opened ? 'Finish your payment' : 'Order placed'),
        content: Text(
          opened
              ? 'Order ${orderCode ?? ''} is waiting for payment. Once you have paid, '
                  'the status updates on the order page.'
              : 'Order ${orderCode ?? ''} was placed, but the payment page could not be '
                  'opened. You can pay from the order page.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // The screen's own name. The brand wordmark said nothing about
        // where the customer was in the flow.
        title: const Text('Checkout'),
        centerTitle: true,
      ),
      body: !AuthState.instance.isAuthenticated
          ? _buildSignedOut()
          : _isLoadingOptions
          ? const LoadingView()
          : _loadError != null
          ? ErrorView(message: _loadError!, onRetry: _loadOptions)
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionCard(
                      title: 'Delivery Details',
                      icon: Icons.local_shipping_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Full name (optional)'),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(labelText: 'Phone number'),
                            validator: (value) => (value == null || value.trim().isEmpty)
                                ? 'Phone number is required'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _addressController,
                            maxLines: 2,
                            decoration: const InputDecoration(labelText: 'Delivery address (optional)'),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<_DeliveryArea>(
                            initialValue: _selectedArea,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Delivery area (optional)'),
                            items: _areas
                                .map((area) => DropdownMenuItem(value: area, child: Text(area.label)))
                                .toList(),
                            onChanged: _onAreaChanged,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Payment Method',
                      icon: Icons.account_balance_wallet_outlined,
                      child: Column(
                        children: [
                          for (final method in _paymentMethods) ...[
                            if (method != _paymentMethods.first) const SizedBox(height: 10),
                            _PaymentOption(
                              label: method.label,
                              selected: _selectedPaymentMethod == method.code,
                              onTap: () => setState(() => _selectedPaymentMethod = method.code),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Coupon & Notes',
                      icon: Icons.local_offer_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _couponController,
                                  decoration: const InputDecoration(labelText: 'Coupon code (optional)'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                // Same height as the field beside it, so the
                                // two do not sit on different baselines.
                                height: 56,
                                child: OutlinedButton(
                                  onPressed: _isCheckingCoupon ? null : _applyCoupon,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                  ),
                                  child: _isCheckingCoupon
                                      ? const AppLoader(size: 46)
                                      : const Text('Apply'),
                                ),
                              ),
                            ],
                          ),
                          if (_couponError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(_couponError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                            ),
                          if (_appliedCoupon != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Coupon "$_appliedCoupon" applied — saving ${formatPrice(_discountAmount)}',
                                style: TextStyle(color: AppColors.accentLight, fontSize: 12),
                              ),
                            ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _noteController,
                            maxLines: 2,
                            decoration: const InputDecoration(labelText: 'Order note (optional)'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Order Summary',
                      icon: Icons.receipt_long_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...CartState.instance.items.map((raw) {
                            final item = raw as Map;
                            final title = item['product_title'] as String? ?? 'Item';
                            final image = ApiConfig.resolveUrl(item['product_image'] as String?);
                            final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                            final subtotal = (item['subtotal'] as num?)?.toDouble() ??
                                (item['price'] as num?)?.toDouble() ?? 0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: image != null && image.isNotEmpty
                                          ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover)
                                          : Container(color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 2),
                                        Text('Qty: $qty', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    formatPrice(subtotal),
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(height: 20),
                          _SummaryRow(label: 'Subtotal', value: _subtotal),
                          _SummaryRow(
                            label: 'Delivery',
                            value: _deliveryCharge,
                            isLoading: _isCheckingDelivery,
                          ),
                          if (_discountAmount > 0)
                            _SummaryRow(label: 'Discount', value: -_discountAmount),
                          const Divider(height: 20),
                          _SummaryRow(label: 'Total', value: _total, isTotal: true),
                        ],
                      ),
                    ),
                    if (_submitError != null) ...[
                      const SizedBox(height: 14),
                      Text(_submitError!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _placeOrder,
                      child: _isSubmitting
                          ? AppLoader(size: 46)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text('Place Order'),
                                SizedBox(width: 8),
                                Icon(Icons.lock_outline, size: 16),
                              ],
                            ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, size: 13, color: AppColors.muted),
                        const SizedBox(width: 5),
                        Text(
                          'Secure Checkout',
                          style: TextStyle(color: AppColors.muted, fontSize: 11.5),
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

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    // Material, not a decorated Container: the payment tiles paint their
    // ink on the nearest Material, which a plain coloured box hides.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: AppColors.inkStrong,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double? value;
  final bool isTotal;
  final bool isLoading;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = isTotal
        ? const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
        : TextStyle(color: AppColors.body);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          if (isLoading)
            AppLoader(size: 46)
          else
            Text(formatPrice(value), style: style),
        ],
      ),
    );
  }
}

/// One payment method, as a tile that reads as chosen — a bare radio in a
/// list gave no sense of which row was selected until you looked closely.
class _PaymentOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentOption({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentSoft.withValues(alpha: 0.5) : AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.line,
          width: selected ? 1.8 : 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                size: 20,
                color: selected ? AppColors.primary : AppColors.lineStrong,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.inkStrong,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
