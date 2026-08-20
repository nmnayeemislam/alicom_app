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
