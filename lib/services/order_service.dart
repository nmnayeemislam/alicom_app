import '../core/api_client.dart';
import '../core/api_endpoints.dart';

/// Authenticated customer's own orders + dashboard stats. Mirrors
/// CustomerStatsController and AuthenticatedOrderController.
class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();

  final _client = ApiClient.instance;

  Future<dynamic> myStats() async =>
      (await _client.get(ApiEndpoints.myStats)).data;

  Future<dynamic> myOrders({int? page}) async =>
      (await _client.get(
        ApiEndpoints.myOrders,
        queryParameters: page != null ? {'page': page} : null,
      )).data;

  Future<dynamic> myOrder(int id) async =>
      (await _client.get(ApiEndpoints.myOrder(id))).data;

  Future<dynamic> cancelOrder(int id, {String? reason}) async =>
      (await _client.post(
        ApiEndpoints.myOrderCancel(id),
        data: {'reason': ?reason},
      )).data;

  /// [reason] is required by AuthenticatedOrderController@requestRefund.
  Future<dynamic> requestRefund(int id, {required String reason}) async =>
      (await _client.post(
        ApiEndpoints.myOrderRefundRequest(id),
        data: {'reason': reason},
      )).data;
}
