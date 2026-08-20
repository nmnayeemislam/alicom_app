import '../core/api_client.dart';
import '../core/api_endpoints.dart';

/// Coupon validation, order tracking, and cart checkout placement. Mirrors
/// CouponController@check, OrderTrackingController, CheckoutOrderController.
///
/// `/customer/order` is intentionally not wrapped here — despite the name it
/// is CustomCheckoutService's custom-rug-design order (multipart file
/// upload, `size`/`design_file` fields), a different feature from placing a
/// cart order, which always goes through `/checkout/order`.
class CommerceService {
  CommerceService._();
  static final CommerceService instance = CommerceService._();

  final _client = ApiClient.instance;

  /// [productIds] mirrors what CouponController@check validates: the
  /// distinct product ids in the cart, used to check eligibility (category/
  /// product restrictions) — not just the code.
  Future<dynamic> checkCoupon({
    required String coupon,
    required List<int> productIds,
    String? phone,
  }) async =>
      (await _client.post(
        ApiEndpoints.couponsCheck,
        data: {
          'coupon': coupon,
          'products': productIds,
          'phone': ?phone,
        },
      )).data;

  Future<dynamic> trackOrder({
    required String orderCode,
    required String phone,
  }) async =>
      (await _client.get(
        ApiEndpoints.ordersTracking,
        queryParameters: {'order_code': orderCode, 'phone': phone},
      )).data;

  /// Guest checkout: the backend reads the bearer token opportunistically
  /// and falls back to a shadow customer account resolved by phone. Payload
  /// mirrors StoreCheckoutOrderRequest: phone is the only required field —
  /// name/address/delivery_area_id may be filled in later by the shop.
  Future<dynamic> placeCheckoutOrder({
    required String phone,
    String? name,
    String? address,
    int? deliveryAreaId,
    required List<Map<String, dynamic>> products,
    String? coupon,
    String? note,
    String? paymentMethod,
  }) async =>
      (await _client.post(
        ApiEndpoints.checkoutOrder,
        data: {
          'phone': phone,
          'name': ?name,
          'address': ?address,
          'delivery_area_id': ?deliveryAreaId,
          'products': products,
          'coupon': ?coupon,
          'note': ?note,
          'payment_method': ?paymentMethod,
        },
      )).data;
}
