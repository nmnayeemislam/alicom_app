import '../core/api_client.dart';
import '../core/api_endpoints.dart';

/// Authenticated customer wishlist. Mirrors WishlistController.
class WishlistService {
  WishlistService._();
  static final WishlistService instance = WishlistService._();

  final _client = ApiClient.instance;

  Future<dynamic> index() async =>
      (await _client.get(ApiEndpoints.wishlist)).data;

  Future<dynamic> add(int productId) async =>
      (await _client.post(ApiEndpoints.wishlist, data: {'product_id': productId}))
          .data;

  Future<void> remove(int productId) async {
    await _client.delete(ApiEndpoints.wishlistItem(productId));
  }

  Future<dynamic> toggle(int productId) async =>
      (await _client.post(
        ApiEndpoints.wishlistToggle,
        data: {'product_id': productId},
      )).data;

  Future<dynamic> status(int productId) async =>
      (await _client.get(ApiEndpoints.wishlistStatus(productId))).data;
}
