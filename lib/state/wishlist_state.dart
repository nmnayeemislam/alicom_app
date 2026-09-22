import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../services/wishlist_service.dart';
import 'auth_state.dart';

/// Single source of truth for the customer's wishlist.
///
/// Every heart in the app toggles through here, so hearting a product on
/// Home or a detail page updates the Wishlist tab straight away — it lives
/// inside the shell's [IndexedStack] and would otherwise keep showing the
/// list it loaded once.
class WishlistState extends ChangeNotifier {
  WishlistState._();
  static final WishlistState instance = WishlistState._();

  List<Product> products = [];
  bool isLoading = false;
  String? error;

  /// Which account [products] belongs to, so a sign-in/out reloads instead
  /// of leaving the previous customer's items on screen.
  int? _loadedForUserId;
  int? get loadedForUserId => _loadedForUserId;

  bool contains(int? productId) =>
      productId != null && products.any((p) => p.id == productId);

  Future<void> refresh() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final response = await WishlistService.instance.index();
      final data = (response is Map ? response['data'] ?? response : {}) as Map;
      final list = (data['products'] as List?) ?? [];
      products = list
          .whereType<Map>()
          .map((e) => Product.fromJson(e.cast<String, dynamic>()))
          .toList();
      _loadedForUserId = AuthState.instance.user?.id;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Flips [product]'s wishlist membership and returns its new state.
  ///
  /// The list is updated from the server's `is_wishlisted` rather than a
  /// local flip, so a heart tapped twice quickly can't drift out of sync.
  Future<bool> toggle(Product product) async {
    final id = product.id;
    if (id == null) return contains(id);

    final response = await WishlistService.instance.toggle(id);
    final data = (response is Map ? response['data'] ?? response : {}) as Map;
    final wishlisted = data['is_wishlisted'] as bool? ?? !contains(id);

    if (wishlisted) {
      if (!contains(id)) {
        products = [product.copyWithWishlisted(true), ...products];
      }
    } else {
      products = products.where((p) => p.id != id).toList();
    }
    _loadedForUserId = AuthState.instance.user?.id;
    notifyListeners();
    return wishlisted;
  }

  /// Drops everything on sign-out so the next customer starts empty.
  void clear() {
    products = [];
    error = null;
    _loadedForUserId = null;
    notifyListeners();
  }
}
