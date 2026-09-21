import 'dart:async';

import 'package:flutter/material.dart';

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

  List<Map> _categories = [];
  List<Map> _brands = [];
  late String? _selectedCategorySlug = widget.initialCategorySlug;
  final Set<String> _selectedBrandSlugs = {};
  String? _selectedSort;

  int _page = 1;
  bool _hasMore = false;
  bool _isLoadingMore = false;

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
      final results = await Future.wait([
        CatalogService.instance.categories(),
        CatalogService.instance.brands(),
      ]);
      final categories = _extractList(results[0]);
      final brands = _extractList(results[1]);
      if (mounted) {
        setState(() {
          _categories = categories.whereType<Map>().toList();
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
    };
  }

  Future<void> _load({String? query}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _page = 1;
      final filters = {..._buildFilters(), 'page': _page};
      final response = query != null && query.isNotEmpty
          ? await CatalogService.instance.search(query, filters: filters)
          : await CatalogService.instance.products(filters: filters);
      final list = _extractList(response);
      _products = list
          .whereType<Map>()
          .map((e) => Product.fromJson(e.cast<String, dynamic>()))
          .toList();
      _hasMore = _extractHasMore(response);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final query = _searchController.text;
      final filters = {..._buildFilters(), 'page': nextPage};
      final response = query.isNotEmpty
          ? await CatalogService.instance.search(query, filters: filters)
          : await CatalogService.instance.products(filters: filters);
      final list = _extractList(response);
      final more = list
          .whereType<Map>()
          .map((e) => Product.fromJson(e.cast<String, dynamic>()))
          .toList();
      if (mounted) {
        setState(() {
          _products = [..._products, ...more];
          _page = nextPage;
          _hasMore = _extractHasMore(response);
        });
      }
    } catch (_) {
      // Leave the already-loaded products on screen; the button just stays
      // tappable to retry.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
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

  bool _extractHasMore(dynamic response) {
    if (response is! Map) return false;
    final data = response['data'];
    if (data is! Map) return false;
    final pagination = data['pagination'];
    if (pagination is! Map) return false;
    return pagination['has_more_pages'] == true;
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(query: value));
  }

  Future<void> _openCategorySheet() async {
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
              child: Text('Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            RadioListTile<String?>(
              value: null,
              // ignore: deprecated_member_use
              groupValue: _selectedCategorySlug,
              // ignore: deprecated_member_use
              onChanged: (v) => Navigator.of(sheetContext).pop(v),
              title: const Text('All Categories'),
            ),
            for (final cat in _categories)
              RadioListTile<String?>(
                value: cat['slug'] as String?,
                // ignore: deprecated_member_use
                groupValue: _selectedCategorySlug,
                // ignore: deprecated_member_use
                onChanged: (v) => Navigator.of(sheetContext).pop(v),
                title: Text((cat['name'] ?? '') as String),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == _selectedCategorySlug) return;
    setState(() => _selectedCategorySlug = selected);
    _load(query: _searchController.text);
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
            for (final entry in _sortOptions.entries)
              RadioListTile<String?>(
                value: entry.key,
                // ignore: deprecated_member_use
                groupValue: _selectedSort,
                // ignore: deprecated_member_use
                onChanged: (v) => Navigator.of(sheetContext).pop(v),
                title: Text(entry.value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == _selectedSort) return;
    setState(() => _selectedSort = selected);
    _load(query: _searchController.text);
  }

  bool get _hasActiveFilters =>
      _selectedCategorySlug != null || _selectedBrandSlugs.isNotEmpty || _selectedSort != null;

  void _clearFilters() {
    setState(() {
      _selectedCategorySlug = null;
      _selectedBrandSlugs.clear();
      _selectedSort = null;
    });
    _load(query: _searchController.text);
  }

  String? get _selectedCategoryName {
    if (_selectedCategorySlug == null) return null;
    final match = _categories.firstWhere(
      (c) => c['slug'] == _selectedCategorySlug,
      orElse: () => const {},
    );
    final name = match['name'] as String?;
    if (name != null) return name;
    // Categories may not have loaded yet; use the name the caller passed.
    return _selectedCategorySlug == widget.initialCategorySlug ? widget.initialCategoryName : null;
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
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeading()),
                  SliverToBoxAdapter(child: _buildFilterRow()),
                  _products.isEmpty
                      ? const SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyView(
                            icon: Icons.search_off,
                            message: 'No products found.',
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 0.68,
                            ),
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

    final count = _hasMore ? '${_products.length}+' : '${_products.length}';

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
              '$count items',
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

  Widget _buildFilterRow() {
    final categoryLabel = _selectedCategoryName ?? 'Category';
    final brandLabel = _selectedBrandSlugs.isEmpty ? 'Brand' : 'Brand · ${_selectedBrandSlugs.length}';
    final sortLabel = _selectedSort == null ? 'Sort' : _sortOptions[_selectedSort]!;

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        children: [
          _FilterChip(
            label: categoryLabel,
            icon: Icons.grid_view_rounded,
            active: _selectedCategorySlug != null,
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
