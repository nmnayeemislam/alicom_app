import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../services/cart_service.dart';

class CartState extends ChangeNotifier {
  CartState._();
  static final CartState instance = CartState._();

  List<dynamic> items = [];
  bool isLoading = false;

  int get totalItems => items.fold<int>(
    0,
    (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 0),
  );

  /// The `products` list for `POST /coupons/check`: each product id once
  /// per unit in the cart. The backend sums one price per entry to get the
  /// subtotal, so sending each id once made a 2 × \$150 cart look like
  /// \$150 — and a minimum-order coupon was wrongly refused.
  List<int> get couponProductIds => [
    for (final item in items)
      if ((item as Map)['product_id'] is int)
        for (var i = 0; i < ((item['quantity'] as num?)?.toInt() ?? 1).clamp(1, 999); i++)
          item['product_id'] as int,
  ];

  Future<void> refresh() async {
    isLoading = true;
    notifyListeners();
    try {
      final response = await CartService.instance.show();
      final data = (response is Map ? response['data'] ?? response : {}) as Map;
      items = (data['items'] as List?) ?? [];
    } catch (_) {
      // Leave the previous cart state on screen rather than blanking it.
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addProduct(Product product, {int quantity = 1}) async {
    await CartService.instance.addItem(productId: product.id!, quantity: quantity);
    await refresh();
  }

  Future<void> updateQuantity(int itemId, int quantity) async {
    await CartService.instance.updateItem(itemId, quantity: quantity);
    await refresh();
  }

  Future<void> removeItem(int itemId) async {
    await CartService.instance.removeItem(itemId);
    await refresh();
  }

  Future<void> clear() async {
    await CartService.instance.clear();
    await refresh();
  }
}
