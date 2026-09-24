import '../core/api_config.dart';

/// Mirrors one entry of `GET /categories` — snake_case fields exactly as
/// CategoryController sends them.
///
/// The endpoint only returns categories that have products of their own, so
/// the top-level parents (Electronics, Fashion, Books, Kitchen Appliances,
/// Cooling & Climate) never appear as entries — they exist only as the
/// `parent_slug` / `parent_name` of the leaves. [buildTree] reconstructs them.
class Category {
  final String name;
  final String slug;

  /// `img` in the payload. Already an absolute URL from the API, but run
  /// through [ApiConfig.resolveUrl] so a relative path would still work.
  final String? imageUrl;

  /// Products attached directly to this category — 0 for a parent that was
  /// synthesized by [buildTree]. Use [totalProductsDeep] for a branch total.
  final int totalProduct;

  final bool isFeatured;
  final bool showInMenu;
  final bool isSubcategory;
  final String? parentSlug;
  final String? parentName;

  /// Filled in by [buildTree]; empty for a leaf.
  final List<Category> children;

  /// True when this node was reconstructed from a child's `parent_slug`
  /// rather than returned by the API.
  final bool isSynthesized;

  const Category({
    required this.name,
    required this.slug,
    this.imageUrl,
    this.totalProduct = 0,
    this.isFeatured = false,
    this.showInMenu = false,
    this.isSubcategory = false,
    this.parentSlug,
    this.parentName,
    this.children = const [],
    this.isSynthesized = false,
  });

  bool get hasChildren => children.isNotEmpty;

  /// Products in this category plus everything under it. A synthesized
  /// parent has no products of its own, so without this it would read "0".
  int get totalProductsDeep =>
      totalProduct +
      children.fold(0, (sum, child) => sum + child.totalProductsDeep);

  /// First image found walking down the branch — lets a synthesized parent
  /// borrow a child's picture instead of rendering an empty tile.
  String? get displayImageUrl {
    if (imageUrl != null && imageUrl!.isNotEmpty) return imageUrl;
    for (final child in children) {
      final inherited = child.displayImageUrl;
      if (inherited != null) return inherited;
    }
    return null;
  }

  Category copyWithChildren(List<Category> children) => Category(
        name: name,
        slug: slug,
        imageUrl: imageUrl,
        totalProduct: totalProduct,
        isFeatured: isFeatured,
        showInMenu: showInMenu,
        isSubcategory: isSubcategory,
        parentSlug: parentSlug,
        parentName: parentName,
        children: children,
        isSynthesized: isSynthesized,
      );

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        name: json['name'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        imageUrl: ApiConfig.resolveUrl(json['img'] as String?),
        totalProduct: _toInt(json['total_product']) ?? 0,
        isFeatured: json['is_featured'] == true,
        showInMenu: json['show_in_menu'] == true,
        isSubcategory: json['is_subcategory'] == true,
        parentSlug: json['parent_slug'] as String?,
        parentName: json['parent_name'] as String?,
      );

  /// Turns the flat payload into a tree.
  ///
  /// Every entry is hung off the entry whose `slug` matches its
  /// `parent_slug`; when that parent is missing from the payload (the common
  /// case — see the class doc) a placeholder is created from `parent_name`.
  /// Nesting depth is not assumed: the catalogue currently runs three deep
  /// (Electronics › Audio › Headphones) because Audio is both a leaf with
  /// products and a parent.
  static List<Category> buildTree(List<Category> flat) {
    final bySlug = <String, Category>{for (final c in flat) c.slug: c};

    // Synthesize the parents the endpoint left out.
    for (final category in flat) {
      final parentSlug = category.parentSlug;
      if (parentSlug == null || parentSlug.isEmpty) continue;
      if (bySlug.containsKey(parentSlug)) continue;
      bySlug[parentSlug] = Category(
        name: category.parentName?.isNotEmpty == true
            ? category.parentName!
            : parentSlug,
        slug: parentSlug,
        isSynthesized: true,
      );
    }

    final childrenOf = <String, List<Category>>{};
    final roots = <Category>[];
    for (final category in bySlug.values) {
      final parentSlug = category.parentSlug;
      if (parentSlug != null && bySlug.containsKey(parentSlug)) {
        childrenOf.putIfAbsent(parentSlug, () => []).add(category);
      } else {
        roots.add(category);
      }
    }

    // `attach` walks down, so children are built before their parent's
    // `totalProductsDeep` is ever read.
    Category attach(Category node, Set<String> seen) {
      if (!seen.add(node.slug)) return node; // guards a cyclic parent_slug
      final kids = (childrenOf[node.slug] ?? [])
          .map((child) => attach(child, seen))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return node.copyWithChildren(kids);
    }

    return roots.map((root) => attach(root, <String>{})).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Flattened node count of a tree — every category the user can tap,
  /// synthesized parents included.
  static int countAll(List<Category> tree) => tree.fold(
        0,
        (sum, category) => sum + 1 + countAll(category.children),
      );

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
