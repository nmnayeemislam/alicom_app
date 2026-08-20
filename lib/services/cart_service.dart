import '../core/api_client.dart';
import '../core/api_endpoints.dart';

/// Server-side cart — guest (visitor_uuid) or Sanctum-authenticated.
/// Mirrors CartController.
class CartService {
  CartService._();
  static final CartService instance = CartService._();

  final _client = ApiClient.instance;

  Future<dynamic> show() async => (await _client.get(ApiEndpoints.cart)).data;

  Future<dynamic> addItem({
    required int productId,
    required int quantity,
    Map<String, dynamic>? options,
  }) async =>
      (await _client.post(
        ApiEndpoints.cartItems,
        data: {
          'product_id': productId,
          'quantity': quantity,
          ...?options,
        },
      )).data;

  Future<dynamic> updateItem(int itemId, {required int quantity}) async =>
      (await _client.put(
        ApiEndpoints.cartItem(itemId),
        data: {'quantity': quantity},
      )).data;

  Future<void> removeItem(int itemId) async {
    await _client.delete(ApiEndpoints.cartItem(itemId));
  }

  Future<void> clear() async {
    await _client.delete(ApiEndpoints.cart);
  }
}
