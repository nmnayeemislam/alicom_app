import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../services/catalog_service.dart';
import '../state/cart_state.dart';
import '../theme/app_theme.dart';
import '../widgets/product_grid_card.dart';
import '../widgets/state_views.dart';
import 'cart_screen.dart';
import 'products_screen.dart';

/// Browse the catalogue by category: top-level categories as pill tabs, a
/// promo banner for the selected one, subcategory chips, then its products.
///
/// `GET /categories` returns a flat list of only the categories that have
/// products of their own, so the top-level parents (Electronics, Fashion,
/// Books, …) arrive only as `parent_slug` on their children.
/// [Category.buildTree] rebuilds them.
///
/// A parent's `category_slug` returns the products of all its descendants,
/// in the admin's order, so "All" under a tab is simply the parent's slug and
/// each chip (a direct child) is that child's slug — one paginated stream
/// either way.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

/// The `category_slug` being paged through: the tab's own slug for "All",
/// or the selected chip's.
class _Source {
  final String slug;
  int page = 0;
  bool hasMore = true;

  _Source(this.slug);
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  static const _perPage = 20;

  bool _isLoading = true;
  String? _error;
  List<Category> _roots = [];
  int _rootIndex = 0;

  /// Selected subcategory chip; `null` is "All".
  String? _leafSlug;

  List<_Source> _sources = [];
  List<Product> _products = [];
  bool _productsLoading = false;
  bool _loadingMore = false;
  String? _productsError;

  /// Bumped whenever the tab or chip changes, so a response for the
  /// previous selection that lands late is dropped instead of mixed in.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final tree = await CatalogService.instance.categoryTree();
      _roots = tree.where((c) => _browsable(c).isNotEmpty).toList();
      if (_rootIndex >= _roots.length) _rootIndex = 0;
      if (_leafSlug != null &&
          !_leaves.any((leaf) => leaf.slug == _leafSlug)) {
        _leafSlug = null;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    if (_error == null && _roots.isNotEmpty) await _loadProducts();
  }

  /// Every node under [category] (itself included) that has products of its
  /// own — a tab is only worth showing when this is non-empty.
  static List<Category> _browsable(Category category) => [
        if (category.totalProduct > 0) category,
        for (final child in category.children) ..._browsable(child),
      ];

  Category? get _root => _roots.isEmpty ? null : _roots[_rootIndex];

  /// The chips under the banner: the tab's direct children. Audio's chip
  /// already covers Headphones and Speakers, since a parent slug includes
  /// its children's products.
  List<Category> get _leaves => _root?.children ?? const [];

  void _selectRoot(int index) {
    if (index == _rootIndex) return;
    setState(() {
      _rootIndex = index;
      _leafSlug = null;
    });
    _loadProducts();
  }

  void _selectLeaf(String? slug) {
    if (slug == _leafSlug) return;
    setState(() => _leafSlug = slug);
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final generation = ++_generation;
    final slugs = [_leafSlug ?? _root!.slug];
    setState(() {
      _sources = [for (final slug in slugs) _Source(slug)];
      _products = [];
      _productsError = null;
      _productsLoading = true;
      _loadingMore = false;
    });
    try {
      final batch = await _fetchNext(_sources);
      if (!mounted || generation != _generation) return;
      setState(() => _products = batch);
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() => _productsError = e.toString());
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _productsLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_productsLoading || _loadingMore || _productsError != null) return;
    final pending = _sources.where((s) => s.hasMore).toList();
    if (pending.isEmpty) return;
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final batch = await _fetchNext(pending);
      if (!mounted || generation != _generation) return;
      setState(() => _products = [..._products, ...batch]);
    } catch (_) {
      // Keep what's on screen; the footer offers a retry.
      if (mounted && generation == _generation) {
        setState(() => _productsError = 'Could not load more products.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loadingMore = false);
      }
    }
  }

  /// Fetches the next page of every source in parallel and advances each
  /// one's cursor from its own `has_more_pages`.
  Future<List<Product>> _fetchNext(List<_Source> sources) async {
    // No `sort`: the admin's product order.
    final pages = await Future.wait([
      for (final source in sources)
        CatalogService.instance.productPage(filters: {
          'category_slug': source.slug,
          'page': source.page + 1,
          'per_page': _perPage,
        }),
    ]);
    for (var i = 0; i < sources.length; i++) {
      sources[i]
        ..page += 1
        ..hasMore = pages[i].pagination.hasMorePages;
    }
    return [for (final page in pages) ...page.products];
  }

  bool get _hasMore => _sources.any((s) => s.hasMore);

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical &&
        notification.metrics.extentAfter < 600 &&
        _hasMore) {
      _loadMore();
    }
    return false;
  }

  /// The banner's "Shop Now": the full product screen (search, sort,
  /// filters, child chips) for the selected chip, or the whole tab under
  /// "All".
  void _shopNow() {
    final root = _root;
    if (root == null) return;
    final target = _leafSlug == null
        ? root
        : _leaves.firstWhere((leaf) => leaf.slug == _leafSlug, orElse: () => root);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductsScreen(
          initialCategorySlug: target.slug,
          initialCategoryName: target.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const LoadingView()
            : _error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : _roots.isEmpty
                    ? const EmptyView(
                        icon: Icons.category_outlined,
                        message: 'No categories yet.',
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: _onScroll,
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(child: _buildRootTabs()),
                            SliverToBoxAdapter(child: _buildBanner()),
                            SliverToBoxAdapter(child: _buildLeafChips()),
                            ..._buildProductSlivers(context),
                          ],
                        ),
                      ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      titleSpacing: canPop ? 0 : 16,
      leading: canPop
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      title: Text(
        'Categories',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.inkStrong,
        ),
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: Icon(Icons.search_rounded, color: AppColors.inkStrong),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProductsScreen()),
          ),
        ),
        ListenableBuilder(
          listenable: CartState.instance,
          builder: (context, _) => _CartButton(
            count: CartState.instance.totalItems,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CartScreen()),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // --- TOP-LEVEL TABS ------------------------------------------------------
  Widget _buildRootTabs() {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        itemCount: _roots.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final selected = i == _rootIndex;
          return Material(
            color: selected ? AppColors.primaryDark : AppColors.card,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => _selectRoot(i),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: selected ? null : Border.all(color: AppColors.line),
                ),
                child: Text(
                  _roots[i].name,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.bodyStrong,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- PROMO BANNER --------------------------------------------------------

  /// Headline for the selected tab: the best discount among the products
  /// loaded so far when there is one, otherwise how many products it holds.
  Widget _buildBanner() {
    final root = _root!;
    final bestDiscount = _products.fold<int>(
      0,
      (best, p) => p.discountPercentage > best ? p.discountPercentage : best,
    );
    final imageUrl = root.displayImageUrl ??
        (_products.isNotEmpty ? _products.first.primaryImage : null);
    final count = root.totalProductsDeep;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              AppColors.primarySoft,
              Color.lerp(AppColors.primarySoft, AppColors.card, 0.5)!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              flex: 11,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      root.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: AppColors.inkStrong,
                      ),
                    ),
                    Text(
                      bestDiscount > 0
                          ? 'Up to $bestDiscount% OFF'
                          : '$count ${count == 1 ? 'product' : 'products'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: AppColors.inkStrong,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Material(
                      color: AppColors.primaryDark,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        onTap: _shopNow,
                        borderRadius: BorderRadius.circular(999),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 9),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Shop Now',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded,
                                  color: Colors.white, size: 15),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 9,
              child: imageUrl == null || imageUrl.isEmpty
                  ? Icon(Icons.shopping_bag_outlined,
                      size: 56, color: AppColors.primary)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, _) => const SizedBox.shrink(),
                        errorWidget: (_, _, _) => Icon(
                          Icons.shopping_bag_outlined,
                          size: 56,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SUBCATEGORY CHIPS ---------------------------------------------------

  /// "All" + the tab's direct children. Hidden with fewer than two
  /// children — "All" and a lone child would be the same list twice.
  Widget _buildLeafChips() {
    final leaves = _leaves;
    if (leaves.length < 2) return const SizedBox(height: 10);

    Widget chip(String label, String? slug) {
      final selected = _leafSlug == slug;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _selectLeaf(slug),
        showCheckmark: false,
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.primaryDark : AppColors.body,
        ),
        backgroundColor: Colors.transparent,
        selectedColor: AppColors.primarySoft,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.line,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        visualDensity: VisualDensity.compact,
      );
    }

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        children: [
          chip('All', null),
          for (final leaf in leaves) ...[
            const SizedBox(width: 8),
            chip(leaf.name, leaf.slug),
          ],
        ],
      ),
    );
  }

  // --- PRODUCTS ------------------------------------------------------------
  List<Widget> _buildProductSlivers(BuildContext context) {
    // Clears the floating bottom nav when this is a MainShell tab.
    final bottomInset = MediaQuery.paddingOf(context).bottom + 24;

    if (_productsLoading) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }
    if (_products.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: _productsError != null
                ? ErrorView(message: _productsError!, onRetry: _loadProducts)
                : const EmptyView(
                    icon: Icons.inventory_2_outlined,
                    message: 'No products in this category yet.',
                  ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        sliver: SliverGrid(
          // Same card as every other product list, so prices, discount
          // labels and stock read identically everywhere.
          gridDelegate: ProductGridDelegate.of(context),
          delegate: SliverChildBuilderDelegate(
            (context, i) => ProductGridCard(product: _products[i]),
            childCount: _products.length,
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
          child: _buildFooter(),
        ),
      ),
    ];
  }

  Widget _buildFooter() {
    if (_loadingMore) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_productsError != null && _hasMore) {
      return Center(
        child: TextButton.icon(
          onPressed: () {
            setState(() => _productsError = null);
            _loadMore();
          },
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Could not load more — tap to retry'),
        ),
      );
    }
    if (_hasMore) {
      // Covers a first page too short to scroll, where no scroll event
      // would ever trigger the next one.
      return Center(
        child: TextButton(
          onPressed: _loadMore,
          child: const Text('Load more'),
        ),
      );
    }
    return Center(
      child: Text(
        "You've seen everything.",
        style: TextStyle(color: AppColors.muted, fontSize: 12.5),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _CartButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.shopping_bag_outlined, color: AppColors.inkStrong),
          if (count > 0)
            Positioned(
              top: -5,
              right: -6,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.sale,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.background, width: 1.5),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
