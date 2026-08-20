import '../core/api_client.dart';
import '../core/api_endpoints.dart';

/// Storefront content: home feed, footer, static pages, blog, banners,
/// flash sales, coupons listing. Mirrors HomeController, FooterController,
/// PageController, BlogCategoryController, BlogPostController,
/// BannerController, HeroBannerController, FlashSaleController,
/// CouponController@index.
class ContentService {
  ContentService._();
  static final ContentService instance = ContentService._();

  final _client = ApiClient.instance;

  Future<dynamic> homeFetchData() async =>
      (await _client.get(ApiEndpoints.homeFetchData)).data;

  Future<dynamic> homeFeaturedCatalog() async =>
      (await _client.get(ApiEndpoints.homeFeaturedCatalog)).data;

  Future<dynamic> footer() async => (await _client.get(ApiEndpoints.footer)).data;

  Future<dynamic> page(String slug) async =>
      (await _client.get(ApiEndpoints.page(slug))).data;

  Future<dynamic> blogCategories() async =>
      (await _client.get(ApiEndpoints.blogCategories)).data;

  Future<dynamic> blogTags() async =>
      (await _client.get(ApiEndpoints.blogTags)).data;

  Future<dynamic> blogPosts({Map<String, dynamic>? filters}) async =>
      (await _client.get(ApiEndpoints.blogPosts, queryParameters: filters))
          .data;

  Future<dynamic> blogPost(String slug) async =>
      (await _client.get(ApiEndpoints.blogPost(slug))).data;

  Future<dynamic> coupons() async => (await _client.get(ApiEndpoints.coupons)).data;

  Future<dynamic> banners() async => (await _client.get(ApiEndpoints.banners)).data;

  Future<dynamic> heroBanners() async =>
      (await _client.get(ApiEndpoints.heroBanners)).data;

  Future<dynamic> flashSales() async =>
      (await _client.get(ApiEndpoints.flashSales)).data;
}
