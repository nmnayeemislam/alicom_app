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
  /// Units on hand; `null` when the payload did not include stock at all
  /// (e.g. the compact wishlist shape), which is *not* the same as sold out.
  final int? stock;
  final String? unit;
  final List<String> images;
  final bool isWishlisted;
  final double? averageRating;
  final List<String> tags;
  final String? categorySlug;
  final String? brandName;
  final String? brandSlug;

  /// Server-rendered badge like "10% OFF" — already accounts for
  /// percentage vs fixed discounts, so prefer it over recomputing.
  final String? discountLabel;

  /// The API's own `in_stock` verdict. `null` on payloads that omit it
  /// (wishlist/cart lines), where [inStock] falls back to [stock].
  final bool? inStockFlag;

  final bool isNew;
  final bool isFeature;
  final bool isBestSeller;

  /// Long description — detail payload only; list cards send
  /// `short_description` instead.
  final String? description;
  final String? descriptionHtml;
  final int? totalReviews;

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
    this.stock,
    this.unit,
    this.images = const [],
    this.isWishlisted = false,
    this.averageRating,
    this.tags = const [],
    this.categorySlug,
    this.brandName,
    this.brandSlug,
    this.discountLabel,
    this.inStockFlag,
    this.isNew = false,
    this.isFeature = false,
    this.isBestSeller = false,
    this.description,
    this.descriptionHtml,
    this.totalReviews,
  });

  String get primaryImage => images.isNotEmpty ? images.first : '';

  double get referencePrice =>
      (originalPrice != null && originalPrice! > price) ? originalPrice! : price;

  /// Saving as a whole percentage, derived from the prices rather than from
  /// [discountType] — a fixed-amount discount is still a percentage off, and
  /// gating on the type left those products showing a struck-through price
  /// with no badge next to it.
  int get discountPercentage {
    if (referencePrice <= price) return 0;
    return (((referencePrice - price) / referencePrice) * 100).round();
  }

  /// The server's own badge text ("10% OFF") when it sent one, else a
  /// percentage worked out from the prices.
  String? get discountBadge {
    if (discountLabel != null && discountLabel!.trim().isNotEmpty) {
      return discountLabel!.trim();
    }
    return discountPercentage > 0 ? '$discountPercentage% OFF' : null;
  }

  /// Trust the server's own flag when it sent one — a pre-order product can
  /// be buyable at `stock_quantity == 0`, so counting units is only a
  /// fallback for payloads that leave `in_stock` out.
  bool get inStock => inStockFlag ?? (stock == null || stock! > 0);

  /// Same product with a different wishlist flag — used when the wishlist
  /// toggle's response, not the listing payload, is the authority.
  Product copyWithWishlisted(bool wishlisted) => Product(
        id: id,
        slug: slug,
        title: title,
        category: category,
        shortDescription: shortDescription,
        price: price,
        originalPrice: originalPrice,
        discountType: discountType,
        sku: sku,
        stock: stock,
        unit: unit,
        images: images,
        isWishlisted: wishlisted,
        averageRating: averageRating,
        tags: tags,
        categorySlug: categorySlug,
        brandName: brandName,
        brandSlug: brandSlug,
        discountLabel: discountLabel,
        inStockFlag: inStockFlag,
        isNew: isNew,
        isFeature: isFeature,
        isBestSeller: isBestSeller,
        description: description,
        descriptionHtml: descriptionHtml,
        totalReviews: totalReviews,
      );

  factory Product.fromJson(Map<String, dynamic> json) {
    // List endpoints send `images: [...]`; compact ones (wishlist, cart
    // lines) send a single `image_url`. Accept either.
    final rawImages = json['images'];
    final singleImage = (json['image_url'] ?? json['image'] ?? json['thumbnail'])?.toString();
    final images = rawImages is List && rawImages.isNotEmpty
        ? rawImages.map((e) => e.toString()).toList()
        : (singleImage != null && singleImage.isNotEmpty ? [singleImage] : <String>[]);

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
      stock: _toInt(json['stock'] ?? json['stock_quantity']),
      unit: json['unit'] as String?,
      images: images,
      isWishlisted: json['is_wishlisted'] == true ||
          json['is_wishlisted'] == 1 ||
          json['is_wishlisted'] == '1',
      averageRating: _toDouble(json['average_rating']),
      tags: tags,
      categorySlug: json['category_slug'] as String?,
      brandName: json['brand_name'] as String?,
      brandSlug: json['brand_slug'] as String?,
      discountLabel: json['discount_label'] as String?,
      inStockFlag: _toBool(json['in_stock']),
      isNew: _toBool(json['is_new']) ?? false,
      isFeature: _toBool(json['is_feature']) ?? false,
      isBestSeller: _toBool(json['is_best_seller']) ?? false,
      description: json['description'] as String?,
      descriptionHtml: json['description_html'] as String?,
      totalReviews: _toInt(json['total_reviews']),
    );
  }

  /// Laravel serializes booleans as `true`, `1` or `"1"` depending on the
  /// cast, so accept all three rather than only the JSON boolean.
  static bool? _toBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
