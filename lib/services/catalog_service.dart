import '../core/api_client.dart';
import '../core/api_endpoints.dart';
import '../models/category.dart';
import '../models/product_page.dart';

/// Product/category/brand browsing — mirrors ProductController,
/// CategoryController, BrandController's public routes.
class CatalogService {
  CatalogService._();
  static final CatalogService instance = CatalogService._();

  final _client = ApiClient.instance;

  Future<dynamic> categories() async =>
      (await _client.get(ApiEndpoints.categories)).data;

  /// Categories as a tree, with the top-level parents the endpoint omits
  /// rebuilt from each leaf's `parent_slug` (see [Category.buildTree]).
  Future<List<Category>> categoryTree() async {
    final response = await categories();
    return Category.buildTree(_parseCategories(response));
  }

  /// The flat payload, parsed — for places that want a plain picker rather
  /// than a tree.
  Future<List<Category>> categoryList() async =>
      _parseCategories(await categories());

  List<Category> _parseCategories(dynamic response) {
    final raw = response is Map ? response['data'] : response;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Category.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Products plus the `pagination` block, so callers can show a real total
  /// and page through rather than guessing from the list length.
  ///
  /// Note the filter key is `category_slug` — Laravel silently ignores an
  /// unknown key and returns the whole catalogue, so a typo here looks like
  /// "the filter does nothing" with no error to follow.
  Future<ProductPage> productPage({Map<String, dynamic>? filters}) async =>
      ProductPage.fromResponse(await products(filters: filters));

  /// Same as [productPage] but hitting `/products/search`.
  Future<ProductPage> searchPage(
    String query, {
    Map<String, dynamic>? filters,
  }) async =>
      ProductPage.fromResponse(await search(query, filters: filters));

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
