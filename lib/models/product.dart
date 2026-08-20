/// Mirrors the product shape returned by the storefront API (see
/// HomeApiProduct / FeaturedCatalogProduct in the web app's pages/index.vue,
/// and ProductController's index/show payloads) — snake_case JSON fields.
class Product {
  final int? id;
  final String slug;
  final String title;
  final String category;
  final String? shortDescription;
  final double price;
  final double? originalPrice;
  final String? discountType; // 'percentage' | 'fixed'
  final String? sku;
  final int stock;
  final String? unit;
  final List<String> images;
  final bool isWishlisted;
  final double? averageRating;
  final List<String> tags;

  Product({
    this.id,
    required this.slug,
    required this.title,
    required this.category,
    this.shortDescription,
    required this.price,
    this.originalPrice,
    this.discountType,
    this.sku,
    required this.stock,
    this.unit,
    this.images = const [],
    this.isWishlisted = false,
    this.averageRating,
    this.tags = const [],
  });

  String get primaryImage => images.isNotEmpty ? images.first : '';

  double get referencePrice =>
      (originalPrice != null && originalPrice! > price) ? originalPrice! : price;

  int get discountPercentage {
    if (discountType != 'percentage' || referencePrice <= price) return 0;
    return (((referencePrice - price) / referencePrice) * 100).round();
  }

  bool get inStock => stock > 0;

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'];
    final images = rawImages is List
        ? rawImages.map((e) => e.toString()).toList()
        : <String>[];

    final rawTags = json['tags'];
    final tags = rawTags is List
        ? rawTags.map((e) => e.toString()).toList()
        : (rawTags is String && rawTags.isNotEmpty ? rawTags.split(',') : <String>[]);

    return Product(
      id: json['id'] as int?,
      slug: json['slug'] as String? ?? '',
      title: json['name'] as String? ?? json['title'] as String? ?? '',
      category: json['category_name'] as String? ??
          json['category'] as String? ??
          '',
      shortDescription: json['short_description'] as String?,
      price: _toDouble(json['price']) ?? 0,
      originalPrice: _toDouble(json['original_price']),
      discountType: json['discount_type'] as String?,
      sku: json['sku'] as String?,
      stock: (json['stock'] ?? json['stock_quantity'] ?? 0) is int
          ? (json['stock'] ?? json['stock_quantity'] ?? 0) as int
          : int.tryParse('${json['stock'] ?? json['stock_quantity'] ?? 0}') ??
              0,
      unit: json['unit'] as String?,
      images: images,
      isWishlisted: json['is_wishlisted'] == true ||
          json['is_wishlisted'] == 1 ||
          json['is_wishlisted'] == '1',
      averageRating: _toDouble(json['average_rating']),
      tags: tags,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
