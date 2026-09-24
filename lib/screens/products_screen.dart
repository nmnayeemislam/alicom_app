import 'dart:async';

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../widgets/product_grid_card.dart';
import '../widgets/state_views.dart';
import 'notifications_screen.dart';

/// Mirrors pages/products/index.vue: a searchable, filterable product grid —
/// context-aware heading with a result count, filter chip row, and the same
/// two-column [ProductGridCard] grid the home screen uses.
class ProductsScreen extends StatefulWidget {
  /// Pre-select a category (e.g. from a Home category chip). The name is
  /// only for the heading while the filter options are still loading.
  final String? initialCategorySlug;
  final String? initialCategoryName;

  const ProductsScreen({super.key, this.initialCategorySlug, this.initialCategoryName});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

/// "Recommended" is the absence of `sort` — the admin's own product order —
/// so it is not in this map; the sheet lists it first as the default.
const _recommendedLabel = 'Recommended';

/// Radio value for "no choice" (All Categories / Recommended) in the pick
/// sheets. Not `null`: a dismissed sheet also completes with `null`, and
/// that must leave the current choice alone rather than clear it.
const _noneValue = '';

const _sortOptions = <String, String>{
  'newest': 'Newest',
  'price_low': 'Price: Low to High',
  'price_high': 'Price: High to Low',
  'offer': 'Best Offers',
  'popular': 'Most Popular',
  'best_selling': 'Best Selling',
};

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  bool _isLoading = true;
  String? _error;
  List<Product> _products = [];
  bool _searching = false;

  /// `/categories` rebuilt into a tree (parents the endpoint omits are
  /// synthesized), for the child chips and the grouped category picker.
  List<Category> _tree = [];

  /// The category this screen is "about" — its name is the AppBar title and
  /// its children are the chips. [_selectedCategorySlug] is either this or
  /// one of those children. A parent slug returns all of its descendants'
  /// products, so "All" is simply this slug.
  late String? _rootSlug = widget.initialCategorySlug;
  List<Map> _brands = [];
  late String? _selectedCategorySlug = widget.initialCategorySlug;
  final Set<String> _selectedBrandSlugs = {};
  String? _selectedSort;

  /// `in_stock=1`, `min_price`, `max_price` — set from the Filter sheet.
  bool _inStockOnly = false;
  double? _minPrice;
  double? _maxPrice;

  /// Bumped by every fresh [_load], so a next-page response that lands
  /// after the filters changed (or a refresh) is dropped, not appended to
  /// the new results.
  int _generation = 0;

  int _page = 1;
  bool _hasMore = false;
  bool _isLoadingMore = false;

  /// Set when a next-page request fails, so scrolling doesn't retry it on
  /// every frame; the "Load more" button clears it.
  bool _autoLoadPaused = false;

  /// `pagination.total` for the filters in force — the real match count,
  /// not how many rows happen to be loaded. Shown in the heading badge so a
  /// filter that silently did nothing (Laravel ignores an unknown query key
  /// rather than erroring) is visible instead of looking like it worked.
  int? _total;

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadFilterOptions() async {
    try {
      // Both chips fill from independent endpoints — fetch them at once
      // rather than paying two round trips in sequence.
      final categoriesFuture = CatalogService.instance.categoryList();
      final brandsFuture = CatalogService.instance.brands();
      final categories = await categoriesFuture;
      final brands = _extractList(await brandsFuture);
      if (mounted) {
        setState(() {
          _tree = Category.buildTree(categories);
          _brands = brands.whereType<Map>().toList();
        });
      }
    } catch (_) {
      // Filter chips just won't have options to pick from; the grid itself
      // still loads fine without them.
    }
  }

  Map<String, dynamic> _buildFilters() {
    return {
      'category_slug': ?_selectedCategorySlug,
      // Dio serializes a List query value as repeated `key=v1&key=v2`
      // (no brackets); PHP only folds that into an array when the key
      // itself carries `[]`, which is what ProductController expects.
      if (_selectedBrandSlugs.isNotEmpty) 'brand_slug[]': _selectedBrandSlugs.toList(),
      'sort': ?_selectedSort,
      if (_inStockOnly) 'in_stock': 1,
      if (_minPrice != null) 'min_price': _minPrice,
      if (_maxPrice != null) 'max_price': _maxPrice,
    };
  }

  Future<void> _load({String? query}) async {
    final generation = ++_generation;
    setState(() {
      _isLoading = true;
      _error = null;
      _isLoadingMore = false;
    });
    try {
      _page = 1;
      _autoLoadPaused = false;
      final filters = {..._buildFilters(), 'page': _page};
      final page = query != null && query.isNotEmpty
          ? await CatalogService.instance.searchPage(query, filters: filters)
          : await CatalogService.instance.productPage(filters: filters);
      // A newer load (filter change, refresh, next keystroke) owns the grid.
      if (generation != _generation) return;
      _products = page.products;
      _hasMore = page.pagination.hasMorePages;
      _total = page.pagination.total;
    } catch (e) {
      if (generation != _generation) return;
      _error = e.toString();
    } finally {
      if (mounted && generation == _generation) setState(() => _isLoading = false);
    }
  }

  /// Infinite scroll: fetch the next page once the user is within a couple
  /// of card rows of the end, for as long as `has_more_pages` says so.
  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical &&
        notification.metrics.extentAfter < 600 &&
        !_autoLoadPaused) {
      _loadMore();
    }
    return false;
  }

  /// One page at a time: the `_isLoadingMore` guard means page N+1 is
  /// never requested twice concurrently, however many scroll events fire.
  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    final generation = _generation;
    setState(() {
      _isLoadingMore = true;
      _autoLoadPaused = false;
    });
    try {
      final nextPage = _page + 1;
      final query = _searchController.text;
      final filters = {..._buildFilters(), 'page': nextPage};
      final page = query.isNotEmpty
          ? await CatalogService.instance.searchPage(query, filters: filters)
          : await CatalogService.instance.productPage(filters: filters);
      if (mounted && generation == _generation) {
        setState(() {
          _products = [..._products, ...page.products];
          _page = nextPage;
          _hasMore = page.pagination.hasMorePages;
          _total = page.pagination.total;
        });
      }
    } catch (_) {
      // Leave the already-loaded products on screen; the button just stays
      // tappable to retry.
      if (generation == _generation) _autoLoadPaused = true;
    } finally {
      if (mounted && generation == _generation) setState(() => _isLoadingMore = false);
    }
  }

  List<dynamic> _extractList(dynamic response) {
    if (response is List) return response;
    if (response is Map) {
      final data = response['data'];
      if (data is List) return data;
      if (data is Map && data['products'] is List) {
        return data['products'] as List;
      }
    }
    return [];
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(query: value));
  }

  /// Every category, parents included, indented under their parent. A
  /// parent's slug returns all of its sub-categories' products combined.
  Future<void> _openCategorySheet() async {
    Iterable<Widget> tiles(BuildContext sheetContext, List<Category> nodes, int depth) sync* {
      for (final cat in nodes) {
        final count = cat.totalProductsDeep;
        yield RadioListTile<String?>(
          value: cat.slug,
          // ignore: deprecated_member_use
          groupValue: _selectedCategorySlug,
          // ignore: deprecated_member_use
          onChanged: (v) => Navigator.of(sheetContext).pop(v),
          contentPadding: EdgeInsets.only(left: 12 + depth * 20.0, right: 16),
          title: Text(
            cat.name,
            style: TextStyle(fontWeight: depth == 0 ? FontWeight.w700 : FontWeight.w500),
          ),
          subtitle: Text(
            '$count ${count == 1 ? 'product' : 'products'}',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        );
        yield* tiles(sheetContext, cat.children, depth + 1);
      }
    }

    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.75),
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text('Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              RadioListTile<String?>(
                value: _noneValue,
                // ignore: deprecated_member_use
                groupValue: _selectedCategorySlug ?? _noneValue,
                // ignore: deprecated_member_use
                onChanged: (v) => Navigator.of(sheetContext).pop(v),
                title: const Text('All Categories', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              ...tiles(sheetContext, _tree, 0),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return; // dismissed
    final slug = selected == _noneValue ? null : selected;
    if (slug == _selectedCategorySlug) return;
    setState(() {
      _rootSlug = slug;
      _selectedCategorySlug = slug;
    });
    _load(query: _searchController.text);
  }

  /// Chip under the filter row: "All" is [_rootSlug] itself, the rest are
  /// its direct children.
  void _selectChildChip(String? slug) {
    if (slug == _selectedCategorySlug) return;
    setState(() => _selectedCategorySlug = slug);
    _load(query: _searchController.text);
  }

  Category? _findCategory(String? slug, [List<Category>? nodes]) {
    if (slug == null) return null;
    for (final node in nodes ?? _tree) {
      if (node.slug == slug) return node;
      final found = _findCategory(slug, node.children);
      if (found != null) return found;
    }
    return null;
  }

  Future<void> _openBrandSheet() async {
    final working = Set<String>.from(_selectedBrandSlugs);
    final applied = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Brand', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final brand in _brands)
                        CheckboxListTile(
                          value: working.contains(brand['slug']),
                          onChanged: (checked) => setSheetState(() {
                            final slug = brand['slug'] as String;
                            checked == true ? working.add(slug) : working.remove(slug);
                          }),
                          title: Text((brand['name'] ?? '') as String),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (applied != true) return;
    setState(() {
      _selectedBrandSlugs
        ..clear()
        ..addAll(working);
    });
    _load(query: _searchController.text);
  }

  Future<void> _openSortSheet() async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Sort By', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            // No `sort` sent: products stay in the order the admin set.
            RadioListTile<String?>(
              value: _noneValue,
              // ignore: deprecated_member_use
              groupValue: _selectedSort ?? _noneValue,
              // ignore: deprecated_member_use
              onChanged: (v) => Navigator.of(sheetContext).pop(v),
              title: const Text(_recommendedLabel),
            ),
            for (final entry in _sortOptions.entries)
              RadioListTile<String?>(
                value: entry.key,
                // ignore: deprecated_member_use
                groupValue: _selectedSort ?? _noneValue,
                // ignore: deprecated_member_use
                onChanged: (v) => Navigator.of(sheetContext).pop(v),
                title: Text(entry.value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null) return; // dismissed
    final sort = selected == _noneValue ? null : selected;
    if (sort == _selectedSort) return;
    setState(() => _selectedSort = sort);
    _load(query: _searchController.text);
  }

  /// In-stock toggle and a price range, from [_FilterSheet].
  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FilterSheet(
        initial: _FilterResult(inStockOnly: _inStockOnly, minPrice: _minPrice, maxPrice: _maxPrice),
      ),
    );
    if (result == null) return;
    setState(() {
      _inStockOnly = result.inStockOnly;
      _minPrice = result.minPrice;
      _maxPrice = result.maxPrice;
    });
    _load(query: _searchController.text);
  }

  bool get _hasPriceOrStockFilter => _inStockOnly || _minPrice != null || _maxPrice != null;

  bool get _hasActiveFilters =>
      _selectedCategorySlug != null ||
      _selectedBrandSlugs.isNotEmpty ||
      _selectedSort != null ||
      _hasPriceOrStockFilter;

  void _clearFilters() {
    setState(() {
      _rootSlug = null;
      _selectedCategorySlug = null;
      _selectedBrandSlugs.clear();
      _selectedSort = null;
      _inStockOnly = false;
      _minPrice = null;
      _maxPrice = null;
    });
    _load(query: _searchController.text);
  }

  String? get _selectedCategoryName => _categoryName(_selectedCategorySlug);

  /// Title for the AppBar: the category the screen was opened for (or last
  /// picked), not whichever child chip is active.
  String? get _rootCategoryName => _categoryName(_rootSlug);

  String? _categoryName(String? slug) {
    if (slug == null) return null;
    final node = _findCategory(slug);
    if (node != null) return node.name;
    // Categories may not have loaded yet; use the name the caller passed.
    return slug == widget.initialCategorySlug ? widget.initialCategoryName : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        // Pushed from Home (category chip / See All) → back arrow; as the
        // storefront tab there is nothing to pop, so show no leading icon.
        automaticallyImplyLeading: false,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                style: TextStyle(color: AppColors.inkStrong),
                decoration: const InputDecoration(
                  hintText: 'Search products',
                  border: InputBorder.none,
                  isDense: true,
                ),
              )
            // The category's name when browsing one; the store name
            // otherwise.
            : _rootCategoryName != null
                ? Text(
                    _rootCategoryName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  )
                : Text(
                    'ALICOM',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          letterSpacing: 3,
                        ),
                    textAlign: TextAlign.center,
                  ),
        centerTitle: !_searching,
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _searchController.clear();
                _load();
              }
            }),
          ),
          if (!_searching)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(query: _searchController.text),
        child: _isLoading
            ? const LoadingView()
            : _error != null
            ? ErrorView(
                message: _error!,
                onRetry: () => _load(query: _searchController.text),
              )
            : NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeading()),
                    SliverToBoxAdapter(child: _buildFilterRow()),
                    SliverToBoxAdapter(child: _buildChildChips()),
                    _products.isEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: EmptyView(
                              icon: Icons.search_off,
                              message: _selectedCategorySlug != null &&
                                      _searchController.text.trim().isEmpty &&
                                      !_hasPriceOrStockFilter &&
                                      _selectedBrandSlugs.isEmpty
                                  ? 'No products in this category yet'
                                  : 'No products found.',
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            sliver: SliverGrid(
                              gridDelegate: ProductGridDelegate.of(context),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => ProductGridCard(product: _products[index]),
                                childCount: _products.length,
                              ),
                            ),
                          ),
                    if (_products.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                          child: _hasMore
                              ? OutlinedButton.icon(
                                  onPressed: _isLoadingMore ? null : _loadMore,
                                  icon: _isLoadingMore
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.expand_more_rounded, size: 18),
                                  label: Text(_isLoadingMore ? 'Loading…' : 'Load more products'),
                                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                                )
                              : Center(
                                  child: Text(
                                    "You've seen everything.",
                                    style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  /// Title reflects what the grid is currently showing (search term or
  /// category) so the page never claims to be a generic "New Arrivals".
  Widget _buildHeading() {
    final query = _searchController.text.trim();
    final categoryName = _selectedCategoryName;

    final String title;
    final String subtitle;
    if (query.isNotEmpty) {
      title = 'Results for “$query”';
      subtitle = categoryName != null ? 'Matches in $categoryName' : 'Matches across the whole store';
    } else if (categoryName != null) {
      title = categoryName;
      subtitle = 'Everything we carry in $categoryName';
    } else {
      title = 'All Products';
      subtitle = 'Browse the full catalogue';
    }

    // The server's match count for the filters in force, not how many rows
    // happen to be loaded — a `category_slug` that narrowed nothing shows up
    // here as the full catalogue total instead of looking like it worked.
    final count = _total ?? _products.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.inkStrong,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count item${count == 1 ? '' : 's'}',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "All" + the root category's direct children, when it has any.
  Widget _buildChildChips() {
    final root = _findCategory(_rootSlug);
    if (root == null || !root.hasChildren) return const SizedBox(height: 8);

    Widget chip(String label, String slug) {
      final selected = _selectedCategorySlug == slug;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => _selectChildChip(slug),
          showCheckmark: false,
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primaryDark : AppColors.body,
          ),
          backgroundColor: AppColors.card,
          selectedColor: AppColors.primarySoft,
          side: BorderSide(color: selected ? AppColors.primary : AppColors.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
        children: [
          chip('All', root.slug),
          for (final child in root.children) chip(child.name, child.slug),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    final categoryLabel = _rootCategoryName ?? 'Category';
    final brandLabel = _selectedBrandSlugs.isEmpty ? 'Brand' : 'Brand · ${_selectedBrandSlugs.length}';
    final sortLabel = _selectedSort == null ? _recommendedLabel : _sortOptions[_selectedSort]!;

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        children: [
          _FilterChip(
            label: categoryLabel,
            icon: Icons.grid_view_rounded,
            active: _rootSlug != null,
            onTap: _openCategorySheet,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: brandLabel,
            icon: Icons.storefront_outlined,
            active: _selectedBrandSlugs.isNotEmpty,
            onTap: _openBrandSheet,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: sortLabel,
            icon: Icons.swap_vert_rounded,
            active: _selectedSort != null,
            onTap: _openSortSheet,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: _hasPriceOrStockFilter ? 'Filter · on' : 'Filter',
            icon: Icons.tune_rounded,
            active: _hasPriceOrStockFilter,
            onTap: _openFilterSheet,
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Clear',
              icon: Icons.close_rounded,
              trailingIcon: false,
              onTap: _clearFilters,
            ),
          ],
        ],
      ),
    );
  }
}

/// Pill-shaped filter trigger. Inactive: outlined on the page background;
/// active: filled with the ink colour so the applied filter reads at a glance.
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool trailingIcon;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    this.active = false,
    this.trailingIcon = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.onAccent : AppColors.inkStrong;
    return Material(
      color: active ? AppColors.inkStrong : AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: active ? AppColors.inkStrong : AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              if (trailingIcon) ...[
                const SizedBox(width: 2),
                Icon(Icons.expand_more_rounded, size: 16, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// What the Filter sheet hands back on Apply.
class _FilterResult {
  final bool inStockOnly;
  final double? minPrice;
  final double? maxPrice;

  const _FilterResult({required this.inStockOnly, this.minPrice, this.maxPrice});
}

/// In-stock toggle plus a min/max price range. Prices are typed in the
/// store's currency; a blank field means "no limit".
///
/// Its own StatefulWidget so the text controllers live and die with the
/// sheet: disposing them from the caller the moment the sheet's future
/// completed tore them down while the closing animation was still drawing
/// the fields, which crashed with `_dependents.isEmpty`.
class _FilterSheet extends StatefulWidget {
  final _FilterResult initial;
  const _FilterSheet({required this.initial});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late bool _inStock = widget.initial.inStockOnly;
  late final _minController = TextEditingController(text: _formatBound(widget.initial.minPrice));
  late final _maxController = TextEditingController(text: _formatBound(widget.initial.maxPrice));
  String? _rangeError;

  static String _formatBound(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble() ? value.toInt().toString() : value.toString();
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _apply() {
    final min = double.tryParse(_minController.text.trim());
    final max = double.tryParse(_maxController.text.trim());
    if (min != null && max != null && min > max) {
      setState(() => _rangeError = 'Min price must be less than max price.');
      return;
    }
    Navigator.of(context).pop(_FilterResult(
      inStockOnly: _inStock,
      minPrice: (min != null && min > 0) ? min : null,
      maxPrice: (max != null && max > 0) ? max : null,
    ));
  }

  InputDecoration _priceField(String label) => InputDecoration(
        labelText: label,
        prefixText: CurrencySettings.symbol.isEmpty ? null : '${CurrencySettings.symbol} ',
        isDense: true,
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lift the sheet above the keyboard while typing a price.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Filter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.inkStrong)),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('In stock only'),
                value: _inStock,
                onChanged: (v) => setState(() => _inStock = v),
              ),
              const SizedBox(height: 8),
              Text('Price range', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.inkStrong)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _priceField('Min'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _priceField('Max'),
                    ),
                  ),
                ],
              ),
              if (_rangeError != null) ...[
                const SizedBox(height: 8),
                Text(_rangeError!, style: TextStyle(color: AppColors.sale, fontSize: 12.5)),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _inStock = false;
                        _minController.clear();
                        _maxController.clear();
                        _rangeError = null;
                      }),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _apply,
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
