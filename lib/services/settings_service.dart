import '../core/api_client.dart';
import '../core/api_endpoints.dart';

/// Delivery zones/charge, payment methods, meta pixel + branding settings.
/// Mirrors DeliveryZoneController, PaymentMethodController,
/// MetaPixelSettingController, BrandingSettingController.
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  final _client = ApiClient.instance;

  /// Returns `{countries: [{id, name, code, areas: [{id, name,
  /// delivery_charge}]}], weight_tiers: [...]}` — pick a country's area for
  /// [deliveryZoneCharge]'s `deliveryAreaId`.
  Future<dynamic> deliveryZones() async =>
      (await _client.get(ApiEndpoints.deliveryZones)).data;

  /// [products] is the cart's line items ({product_id, variant_id?,
  /// quantity}) so the backend can derive weight from the catalogue
  /// server-side, per DeliveryZoneController@charge's own comment: a
  /// client-supplied weight would let a shopper quote their own price.
  Future<dynamic> deliveryZoneCharge({
    int? deliveryAreaId,
    List<Map<String, dynamic>>? products,
  }) async =>
      (await _client.post(
        ApiEndpoints.deliveryZoneCharge,
        data: {
          'delivery_area_id': ?deliveryAreaId,
          'products': ?products,
        },
      )).data;

  Future<dynamic> paymentMethods() async =>
      (await _client.get(ApiEndpoints.paymentMethods)).data;

  Future<dynamic> metaPixelSettings() async =>
      (await _client.get(ApiEndpoints.settingsMetaPixel)).data;

  Future<dynamic> brandingSettings() async =>
      (await _client.get(ApiEndpoints.settingsBranding)).data;
}
