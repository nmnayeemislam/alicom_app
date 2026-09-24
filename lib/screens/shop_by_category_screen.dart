import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/category.dart';
import '../services/catalog_service.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import 'products_screen.dart';

/// "Shop by Category": every category from `GET /categories` as a tile
/// (`img`, name, "{total_product} items"), grouped under its `parent_name`.
/// Each tile opens that category's products; each group header's "View all"
/// opens the parent, whose slug returns all of its sub-categories combined.
class ShopByCategoryScreen extends StatefulWidget {
  const ShopByCategoryScreen({super.key});

  @override
  State<ShopByCategoryScreen> createState() => _ShopByCategoryScreenState();
}

class _ShopByCategoryScreenState extends State<ShopByCategoryScreen> {
  bool _isLoading = true;
  String? _error;
  List<MapEntry<String, List<Category>>> _groups = [];

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
      final categories = await CatalogService.instance.categoryList();
      _groups = _group(categories);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Buckets by `parent_name`, keeping the order the API sent both the
  /// groups (first appearance) and the tiles within them. Categories with no
  /// parent go in a trailing "More" group rather than being dropped.
  static List<MapEntry<String, List<Category>>> _group(List<Category> categories) {
    const orphans = 'More';
    final groups = <String, List<Category>>{};
    for (final category in categories) {
      if (category.totalProduct <= 0) continue;
      final parent = category.parentName?.trim().isNotEmpty == true ? category.parentName!.trim() : orphans;
      groups.putIfAbsent(parent, () => []).add(category);
    }
    final entries = groups.entries.toList();
    final orphanIndex = entries.indexWhere((e) => e.key == orphans);
    if (orphanIndex >= 0) entries.add(entries.removeAt(orphanIndex));
    return entries;
  }

  void _open(Category category) => _openSlug(category.slug, category.name);

  void _openSlug(String slug, String name) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductsScreen(
            initialCategorySlug: slug,
            initialCategoryName: name,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Shop by Category')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const LoadingView()
            : _error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : _groups.isEmpty
                    ? const EmptyView(icon: Icons.category_outlined, message: 'No categories yet.')
                    : CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          for (final group in _groups) ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 18,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        group.key,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.inkStrong,
                                        ),
                                      ),
                                    ),
                                    if (group.value.first.parentSlug?.isNotEmpty == true)
                                      TextButton(
                                        onPressed: () => _openSlug(group.value.first.parentSlug!, group.key),
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                        ),
                                        child: const Text('View all'),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              sliver: SliverGrid(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 12,
                                  // Square image plus two short lines of text.
                                  childAspectRatio: 0.7,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) => _CategoryTile(
                                    category: group.value[i],
                                    onTap: () => _open(group.value[i]),
                                  ),
                                  childCount: group.value.length,
                                ),
                              ),
                            ),
                          ],
                          // Clears MainShell's floating nav if this is ever
                          // shown as a tab.
                          SliverToBoxAdapter(
                            child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
                          ),
                        ],
                      ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final VoidCallback onTap;

  const _CategoryTile({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final count = category.totalProduct;
    final image = category.imageUrl;
    final fallback = Container(
      color: AppColors.primarySoft,
      child: Icon(Icons.category_outlined, color: AppColors.primary),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: image == null
                  ? fallback
                  : CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: AppColors.line),
                      errorWidget: (_, _, _) => fallback,
                    ),
            ),
          ),
          const SizedBox(height: 7),
          Expanded(
            child: Column(
              children: [
                Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.inkStrong),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count ${count == 1 ? 'item' : 'items'}',
                  maxLines: 1,
                  style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
