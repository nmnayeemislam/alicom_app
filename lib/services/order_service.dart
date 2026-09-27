import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../core/api_client.dart';
import '../core/api_endpoints.dart';
import '../core/api_exception.dart';
import '../models/order_tracking.dart';

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

  /// Where an order has got to, and every stage still ahead of it.
  ///
  /// Public route — it takes the order code and the phone it was placed
  /// with, not the bearer token.
  Future<OrderTracking> tracking({
    required String orderCode,
    required String phone,
  }) async {
    final response = await _client.get(
      ApiEndpoints.ordersTracking,
      queryParameters: {'order_code': orderCode, 'phone': phone},
    );
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    return OrderTracking.fromJson(
      data is Map ? data.cast<String, dynamic>() : const {},
    );
  }

  /// Downloads the server-rendered invoice and writes it to a file the
  /// viewer and the share sheet can both read.
  ///
  /// The PDF is built by the backend — the app never lays one out itself,
  /// so the paper invoice and the emailed one always match.
  Future<File> downloadInvoice(int id, {String? orderCode}) async {
    final response = await _client.get<List<int>>(
      ApiEndpoints.myOrderInvoice(id),
      options: Options(
        responseType: ResponseType.bytes,
        headers: const {'Accept': 'application/pdf'},
      ),
    );
    final bytes = response.data ?? const <int>[];
    if (bytes.isEmpty) {
      throw ApiException('The invoice came back empty.', statusCode: response.statusCode);
    }
    // Temporary directory: the invoice can always be fetched again, and the
    // customer keeps their own copy through the share sheet.
    final directory = await getTemporaryDirectory();
    final name = (orderCode?.trim().isNotEmpty == true ? orderCode!.trim() : '$id')
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final file = File('${directory.path}/invoice-$name.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// [reason] is required by AuthenticatedOrderController@requestRefund.
  Future<dynamic> requestRefund(int id, {required String reason}) async =>
      (await _client.post(
        ApiEndpoints.myOrderRefundRequest(id),
        data: {'reason': reason},
      )).data;
}
