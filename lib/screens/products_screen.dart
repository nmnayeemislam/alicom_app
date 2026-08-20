import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import 'notifications_screen.dart';
import 'product_detail_screen.dart';

/// Mirrors pages/products/index.vue: a searchable, filterable product grid,
/// styled to the "Lumina" dark storefront pattern — filter chip row, section
/// heading with a result count, and a two-column white-tile grid.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

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
  String? _selectedCategorySlug;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
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
                  SliverToBoxAdapter(child: _buildFilterRow()),
                  SliverToBoxAdapter(child: _buildHeading()),
                  _products.isEmpty
                      ? const SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyView(
                            icon: Icons.search_off,
                            message: 'No products found.',
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 20,
                              crossAxisSpacing: 16,
                              childAspectRatio: 0.66,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _ProductTile(product: _products[index]),
                              childCount: _products.length,
                            ),
                          ),
                        ),
                  if (_products.isNotEmpty && _hasMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                        child: Center(
                          child: OutlinedButton(
                            onPressed: _isLoadingMore ? null : _loadMore,
                            child: _isLoadingMore
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Load More'),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildFilterRow() {
    final categoryLabel = _selectedCategorySlug == null
        ? 'Category'
        : (_categories.firstWhere(
                (c) => c['slug'] == _selectedCategorySlug,
                orElse: () => {'name': 'Category'},
              )['name'] as String? ??
              'Category');
    final brandLabel = _selectedBrandSlugs.isEmpty ? 'Brand' : 'Brand (${_selectedBrandSlugs.length})';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
      child: SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _FilterChip(
              label: categoryLabel,
              icon: Icons.category_outlined,
              active: _selectedCategorySlug != null,
              onTap: _openCategorySheet,
            ),
            const SizedBox(width: 10),
            _FilterChip(
              label: brandLabel,
              icon: Icons.storefront_outlined,
              active: _selectedBrandSlugs.isNotEmpty,
              onTap: _openBrandSheet,
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: _selectedSort == null ? 'Sort' : _sortOptions[_selectedSort]!,
              icon: Icons.sort,
              plain: true,
              onTap: _openSortSheet,
            ),
            const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeading() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New Arrivals', style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ) ?? Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'Curated essentials for the modern wardrobe.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Text(
            '${_products.length} Items',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool active;
  final bool plain;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    this.active = false,
    this.plain = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (plain) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(color: AppColors.inkStrong, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(icon, size: 16, color: AppColors.inkStrong),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.inkStrong : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? AppColors.inkStrong : AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? AppColors.onAccent : AppColors.ink,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 6),
              Icon(icon, size: 15, color: active ? AppColors.onAccent : AppColors.ink),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailScreen(slug: product.slug)),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.all(14),
                child: product.primaryImage.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: product.primaryImage,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.muted,
                        ),
                      )
                    : Icon(Icons.image_not_supported_outlined, color: AppColors.muted),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            product.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.inkStrong,
              fontWeight: FontWeight.w600,
              fontSize: 14.5,
            ),
          ),
          if (product.category.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              product.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '\$${product.price.toStringAsFixed(2)}',
            style: TextStyle(
              color: AppColors.sale,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}
