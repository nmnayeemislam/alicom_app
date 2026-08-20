import '../core/api_client.dart';
import '../core/api_endpoints.dart';

/// Product/category/brand browsing — mirrors ProductController,
/// CategoryController, BrandController's public routes.
class CatalogService {
  CatalogService._();
  static final CatalogService instance = CatalogService._();

  final _client = ApiClient.instance;

  Future<dynamic> categories() async =>
      (await _client.get(ApiEndpoints.categories)).data;

  Future<dynamic> brands() async => (await _client.get(ApiEndpoints.brands)).data;

  Future<dynamic> products({Map<String, dynamic>? filters}) async =>
      (await _client.get(ApiEndpoints.products, queryParameters: filters))
          .data;

  Future<dynamic> discountedProducts() async =>
      (await _client.get(ApiEndpoints.productsDiscounted)).data;

  Future<dynamic> product(String slug) async =>
      (await _client.get(ApiEndpoints.product(slug))).data;

  Future<dynamic> productReviews(String slug, {int? page}) async =>
      (await _client.get(
        ApiEndpoints.productReviews(slug),
        queryParameters: page != null ? {'page': page} : null,
      )).data;

  Future<dynamic> search(String query, {Map<String, dynamic>? filters}) async =>
      (await _client.get(
        ApiEndpoints.productsSearch,
        queryParameters: {'q': query, ...?filters},
      )).data;
}
