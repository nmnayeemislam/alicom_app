import '../core/api_client.dart';
import '../core/api_endpoints.dart';

/// Authenticated customer address book. Mirrors AddressController.
class AddressService {
  AddressService._();
  static final AddressService instance = AddressService._();

  final _client = ApiClient.instance;

  Future<dynamic> index() async =>
      (await _client.get(ApiEndpoints.addresses)).data;

  Future<dynamic> store(Map<String, dynamic> payload) async =>
      (await _client.post(ApiEndpoints.addresses, data: payload)).data;

  Future<dynamic> update(int id, Map<String, dynamic> payload) async =>
      (await _client.put(ApiEndpoints.address(id), data: payload)).data;

  Future<void> destroy(int id) async {
    await _client.delete(ApiEndpoints.address(id));
  }

  Future<void> setDefault(int id) async {
    await _client.post(ApiEndpoints.addressDefault(id));
  }
}
