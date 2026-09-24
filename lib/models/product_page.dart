import 'product.dart';

/// The `pagination` block `GET /products` sends alongside the list.
class Pagination {
  final int currentPage;
  final int perPage;

  /// Total matching the current filters — not the page length. This is what
  /// tells you a `category_slug` actually narrowed anything.
  final int total;

  final int lastPage;
  final int? from;
  final int? to;
  final bool hasMorePages;

  const Pagination({
    this.currentPage = 1,
    this.perPage = 20,
    this.total = 0,
    this.lastPage = 1,
    this.from,
    this.to,
    this.hasMorePages = false,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
        currentPage: _toInt(json['current_page']) ?? 1,
        perPage: _toInt(json['per_page']) ?? 20,
        total: _toInt(json['total']) ?? 0,
        lastPage: _toInt(json['last_page']) ?? 1,
        from: _toInt(json['from']),
        to: _toInt(json['to']),
        hasMorePages: json['has_more_pages'] == true,
      );

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

/// One page of `GET /products`, already unwrapped from the `data` envelope.
class ProductPage {
  final List<Product> products;
  final Pagination pagination;

  const ProductPage({required this.products, required this.pagination});

  /// Accepts both shapes the catalogue endpoints use: the paginated
  /// `{data: {products: [...], pagination: {...}}}` of `/products` and the
  /// bare `{data: [...]}` of `/products/discounted`, which has no pagination.
  factory ProductPage.fromResponse(dynamic response) {
    final data = response is Map ? response['data'] : response;

    if (data is List) {
      final products = _parseProducts(data);
      return ProductPage(
        products: products,
        pagination: Pagination(total: products.length, perPage: products.length),
      );
    }

    if (data is Map) {
      final products = _parseProducts(data['products']);
      final rawPagination = data['pagination'];
      return ProductPage(
        products: products,
        pagination: rawPagination is Map
            ? Pagination.fromJson(rawPagination.cast<String, dynamic>())
            : Pagination(total: products.length, perPage: products.length),
      );
    }

    return const ProductPage(products: [], pagination: Pagination());
  }

  static List<Product> _parseProducts(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Product.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
