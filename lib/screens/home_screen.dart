import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/product.dart';
import '../services/catalog_service.dart';
import '../services/content_service.dart';
import '../services/settings_service.dart';
import '../services/wishlist_service.dart';
import '../state/cart_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/state_views.dart';
import 'cart_screen.dart';
import 'notifications_screen.dart';
import 'product_detail_screen.dart';
import 'products_screen.dart';

/// Decorative-only accent that isn't part of the light/dark palette — the
/// flash-sale flame/clock reads fine unchanged in either theme.
const _flame = Color(0xFFF97316);

typedef _CategoryStyle = ({Color bg, Color fg, IconData icon});

const _fallbackCategoryStyle = (bg: Color(0xFFEDEDF5), fg: Color(0xFF6E7191), icon: Icons.grid_view_rounded);

const _categoryStyles = <String, _CategoryStyle>{
  'electronic': (bg: Color(0xFFE8E6FB), fg: Color(0xFF5B4FE5), icon: Icons.headphones),
  'fashion': (bg: Color(0xFFFCE4EC), fg: Color(0xFFE94560), icon: Icons.checkroom),
  'cloth': (bg: Color(0xFFFCE4EC), fg: Color(0xFFE94560), icon: Icons.checkroom),
  'home': (bg: Color(0xFFE3F6E8), fg: Color(0xFF2E9E5B), icon: Icons.weekend),
  'furniture': (bg: Color(0xFFE3F6E8), fg: Color(0xFF2E9E5B), icon: Icons.weekend),
  'beauty': (bg: Color(0xFFFFE7EC), fg: Color(0xFFDB4C97), icon: Icons.spa),
  'sport': (bg: Color(0xFFFFF1E0), fg: Color(0xFFF97316), icon: Icons.sports_basketball),
  'grocery': (bg: Color(0xFFE3F6E8), fg: Color(0xFF2E9E5B), icon: Icons.local_grocery_store_outlined),
  'food': (bg: Color(0xFFFFF1E0), fg: Color(0xFFF97316), icon: Icons.restaurant_outlined),
  'book': (bg: Color(0xFFE8E6FB), fg: Color(0xFF5B4FE5), icon: Icons.menu_book_outlined),
  'toy': (bg: Color(0xFFFCE7F3), fg: Color(0xFFDB4C97), icon: Icons.toys_outlined),
};

_CategoryStyle _styleForCategory(String name) {
  final lower = name.toLowerCase();
  for (final entry in _categoryStyles.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return _fallbackCategoryStyle;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String? _error;

  List<Product> _popular = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _banners = [];
  Map<String, dynamic>? _flashSale;
  List<Product> _flashProducts = [];
  String _siteName = 'Alicom';

  final _bannerController = PageController();
  int _bannerIndex = 0;
  Timer? _bannerTimer;
  Timer? _countdownTimer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _countdownTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ContentService.instance.homeFetchData(),
        CatalogService.instance.categories(),
        ContentService.instance.heroBanners(),
        ContentService.instance.banners(),
        ContentService.instance.flashSales(),
        SettingsService.instance.brandingSettings(),
      ]);

      final branding = (results[5] is Map ? results[5]['data'] ?? results[5] : results[5]) as Map?;
      final siteName = branding?['site_name'] as String?;
      if (siteName != null && siteName.isNotEmpty) _siteName = siteName;
      final hex = branding?['theme_primary_color'] as String?;
      final parsed = _parseHexColor(hex);
      if (parsed != null) AppColors.setBrandPrimary(parsed);

      final home = (results[0] is Map ? results[0]['data'] ?? results[0] : results[0]) as Map?;
      _popular = _extractProducts(home, ['best_seller_products', 'best_seller', 'featured_products']);
      _categories = _extractList(results[1], ['categories']);

      final heroBanners = _extractList(results[2], ['hero_banners']);
      final plainBanners = _extractList(results[3], ['banners']);
      _banners = heroBanners.isNotEmpty ? heroBanners : plainBanners;

      final flashData = (results[4] is Map ? results[4]['data'] ?? results[4] : results[4]) as Map?;
      final flashSale = (flashData?['flash_sale']) as Map?;
      _flashSale = flashSale?.cast<String, dynamic>();
      final flashRaw = (flashSale?['products'] as List?) ?? [];
      _flashProducts = flashRaw
          .whereType<Map>()
          .map((e) => Product.fromJson(e.cast<String, dynamic>()))
          .toList();

      _startCountdown();
      _startBannerAutoplay();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Product> _extractProducts(Map? data, List<String> keys) {
    if (data == null) return [];
    for (final key in keys) {
      final raw = data[key];
      if (raw is List && raw.isNotEmpty) {
        return raw
            .whereType<Map>()
            .map((e) => Product.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    }
    return [];
  }

  List<Map<String, dynamic>> _extractList(dynamic response, List<String> keys) {
    final data = response is Map ? response['data'] ?? response : response;
    // Some endpoints (e.g. /categories) return `data` as a bare array rather
    // than {key: [...]}.
    if (data is List) {
      return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    if (data is Map) {
      for (final key in keys) {
        final raw = data[key];
        if (raw is List) return raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
    }
    return [];
  }

  void _startBannerAutoplay() {
    _bannerTimer?.cancel();
    if (_banners.length < 2) return;
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_bannerController.hasClients) return;
      final next = (_bannerIndex + 1) % _banners.length;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    final endRaw = _flashSale?['end_time'] as String?;
    final end = endRaw != null ? DateTime.tryParse(endRaw) : null;
    if (end == null) return;

    void tick() {
      final remaining = end.difference(DateTime.now());
      if (!mounted) return;
      setState(() => _timeLeft = remaining.isNegative ? Duration.zero : remaining);
    }

    tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  Color? _parseHexColor(String? hex) {
    if (hex == null) return null;
    var value = hex.trim().replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return null;
    final parsed = int.tryParse(value, radix: 16);
    return parsed != null ? Color(parsed) : null;
  }

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: _isLoading
            ? const LoadingView()
            : _error != null
            ? ErrorView(message: _error!, onRetry: _load)
            : RefreshIndicator(
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopBar(context),
                      _buildSearchRow(context),
                      _buildBanner(context),
                      _buildSectionHeader(context, 'Categories', onSeeAll: () => _goToProducts(context)),
                      _buildCategoryRow(context),
                      if (_flashProducts.isNotEmpty) ...[
                        _buildFlashHeader(context),
                        _buildFlashRow(context),
                      ],
                      _buildSectionHeader(context, 'Popular Products', onSeeAll: () => _goToProducts(context)),
                      _buildPopularGrid(context),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  void _goToProducts(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProductsScreen()),
      );

  // --- TOP BAR ---------------------------------------------------------
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _iconSquare(Icons.menu, onTap: () => _scaffoldKey.currentState?.openDrawer()),
          const SizedBox(width: 12),
          SvgPicture.asset('assets/images/alicom-mark.svg', width: 26, height: 26),
          const SizedBox(width: 8),
          Text(
            _siteName,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.inkStrong),
          ),
          const Spacer(),
          _iconSquare(
            Icons.notifications_none_rounded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
            badged: true,
          ),
          const SizedBox(width: 10),
          ListenableBuilder(
            listenable: CartState.instance,
            builder: (context, _) => _iconSquare(
              Icons.shopping_cart_outlined,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CartScreen()),
              ),
              count: CartState.instance.totalItems,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconSquare(IconData icon, {required VoidCallback onTap, bool badged = false, int count = 0}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(child: Icon(icon, size: 20, color: AppColors.inkStrong)),
            if (badged)
              Positioned(
                top: 10,
                right: 11,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: AppColors.sale, shape: BoxShape.circle),
                ),
              ),
            if (count > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    '$count',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- SEARCH ------------------------------------------------------------
  Widget _buildSearchRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _goToProducts(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 20, color: AppColors.body),
                    const SizedBox(width: 10),
                    Text('Search for products...', style: TextStyle(color: AppColors.body.withValues(alpha: 0.8), fontSize: 14.5)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: () => _goToProducts(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // --- BANNER --------------------------------------------------------------
  Widget _buildBanner(BuildContext context) {
    if (_banners.isEmpty) return _buildFallbackBanner(context);

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _bannerController,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _bannerIndex = i),
            itemBuilder: (context, i) {
              final banner = _banners[i];
              final image = banner['image'] as String?;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: image != null && image.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (_, __) => Container(color: AppColors.line),
                          errorWidget: (_, __, ___) => _fallbackBannerCard(context),
                        )
                      : _fallbackBannerCard(context),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (i) {
            final active = i == _bannerIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.line,
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildFallbackBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(height: 190, child: _fallbackBannerCard(context)),
      ),
    );
  }

  Widget _fallbackBannerCard(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFDEDBFC), Color(0xFFF4EEFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative floating shapes, echoing the confetti bits in the mock.
          Positioned(
            top: 24,
            left: 118,
            child: Transform.rotate(
              angle: 0.5,
              child: Container(width: 14, height: 14, decoration: BoxDecoration(color: const Color(0xFF6FD3E8), borderRadius: BorderRadius.circular(4))),
            ),
          ),
          Positioned(
            top: 60,
            right: 96,
            child: Transform.rotate(
              angle: -0.4,
              child: Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(3))),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 30,
            child: Transform.rotate(
              angle: 0.3,
              child: Container(width: 12, height: 24, decoration: BoxDecoration(color: const Color(0xFFF5B7C6), borderRadius: BorderRadius.circular(4))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🔥', style: TextStyle(fontSize: 12)),
                            SizedBox(width: 4),
                            Text('Summer Sale', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _flame)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: AppColors.inkStrong, height: 1.15),
                          children: [
                            const TextSpan(text: 'Get '),
                            TextSpan(text: '30% ', style: TextStyle(color: AppColors.primary)),
                            const TextSpan(text: 'OFF'),
                          ],
                        ),
                      ),
                      Text('On All Products', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: AppColors.inkStrong, height: 1.15)),
                      const SizedBox(height: 8),
                      Text('Limited time offer. Shop now!', style: TextStyle(fontSize: 12.5, color: AppColors.body.withValues(alpha: 0.85))),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () => _goToProducts(context),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Shop Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      const Text('👜', style: TextStyle(fontSize: 78)),
                      const Positioned(left: 4, bottom: 14, child: Text('👟', style: TextStyle(fontSize: 40))),
                      const Positioned(right: 2, bottom: 30, child: Text('⌚', style: TextStyle(fontSize: 30))),
                      Positioned(
                        top: -10,
                        right: -14,
                        child: Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: AppColors.sale, shape: BoxShape.circle),
                          child: const Text(
                            '30%\nOFF',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, height: 1.1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION HEADER --------------------------------------------------
  Widget _buildSectionHeader(BuildContext context, String title, {required VoidCallback onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.inkStrong)),
          InkWell(
            onTap: onSeeAll,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('See All', style: TextStyle(color: AppColors.body, fontWeight: FontWeight.w500, fontSize: 13.5)),
                const SizedBox(width: 2),
                Icon(Icons.arrow_forward, size: 15, color: AppColors.body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- CATEGORIES ----------------------------------------------------------
  Widget _buildCategoryRow(BuildContext context) {
    if (_categories.isEmpty) return const SizedBox.shrink();
    final items = _categories.take(6).toList();
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (context, i) {
          final cat = items[i];
          final name = (cat['name'] ?? cat['title'] ?? '').toString();
          final style = _styleForCategory(name);
          return InkWell(
            onTap: () => _goToProducts(context),
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 64,
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: style.bg, shape: BoxShape.circle),
                    child: Icon(style.icon, size: 24, color: style.fg),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: AppColors.inkStrong, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- FLASH SALE ------------------------------------------------------
  Widget _buildFlashHeader(BuildContext context) {
    final showTimer = _flashSale?['end_time'] != null && _timeLeft > Duration.zero;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: _flame, size: 20),
              const SizedBox(width: 4),
              Text('Flash Sale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.inkStrong)),
            ],
          ),
          if (showTimer)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(999)),
              child: Text(
                '${_twoDigits(_timeLeft.inHours)} : ${_twoDigits(_timeLeft.inMinutes % 60)} : ${_twoDigits(_timeLeft.inSeconds % 60)}',
                style: TextStyle(color: AppColors.sale, fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            )
          else
            InkWell(
              onTap: () => _goToProducts(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('See All', style: TextStyle(color: AppColors.body, fontWeight: FontWeight.w500, fontSize: 13.5)),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_forward, size: 15, color: AppColors.body),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFlashRow(BuildContext context) {
    return SizedBox(
      height: 224,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _flashProducts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) => SizedBox(width: 150, child: _FlashCard(product: _flashProducts[i])),
      ),
    );
  }

  // --- POPULAR PRODUCTS --------------------------------------------------
  Widget _buildPopularGrid(BuildContext context) {
    if (_popular.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: EmptyView(icon: Icons.storefront_outlined, message: 'No products to show yet.'),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _popular.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 0.62,
        ),
        itemBuilder: (context, i) => _PopularCard(product: _popular[i]),
      ),
    );
  }
}

class _FlashCard extends StatelessWidget {
  final Product product;
  const _FlashCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailScreen(slug: product.slug)),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: AppColors.background,
                      padding: const EdgeInsets.all(8),
                      child: product.primaryImage.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: product.primaryImage,
                              fit: BoxFit.contain,
                              placeholder: (_, __) => const SizedBox.shrink(),
                              errorWidget: (_, __, ___) => Icon(Icons.image_not_supported_outlined, color: AppColors.body),
                            )
                          : Icon(Icons.image_not_supported_outlined, color: AppColors.body),
                    ),
                  ),
                ),
                if (product.discountPercentage > 0)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.sale, borderRadius: BorderRadius.circular(999)),
                      child: Text('-${product.discountPercentage}%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.inkStrong)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('\$${product.price.toStringAsFixed(2)}', style: TextStyle(color: AppColors.sale, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(width: 6),
                Expanded(
                  child: product.referencePrice > product.price
                      ? Text(
                          '\$${product.referencePrice.toStringAsFixed(2)}',
                          maxLines: 1,
                          style: TextStyle(color: AppColors.body, fontSize: 11, decoration: TextDecoration.lineThrough),
                        )
                      : const SizedBox.shrink(),
                ),
                InkWell(
                  onTap: () => CartState.instance.addProduct(product),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.add, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularCard extends StatefulWidget {
  final Product product;
  const _PopularCard({required this.product});

  @override
  State<_PopularCard> createState() => _PopularCardState();
}

class _PopularCardState extends State<_PopularCard> {
  late bool _wishlisted = widget.product.isWishlisted;
  bool _busy = false;

  Future<void> _toggleWishlist() async {
    final id = widget.product.id;
    if (id == null || _busy) return;
    setState(() => _busy = true);
    try {
      await WishlistService.instance.toggle(id);
      if (mounted) setState(() => _wishlisted = !_wishlisted);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update wishlist')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailScreen(slug: product.slug)),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: AppColors.card,
                    padding: const EdgeInsets.all(10),
                    child: product.primaryImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: product.primaryImage,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const SizedBox.shrink(),
                            errorWidget: (_, __, ___) => Icon(Icons.image_not_supported_outlined, color: AppColors.body),
                          )
                        : Icon(Icons.image_not_supported_outlined, color: AppColors.body),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: InkWell(
                    onTap: _busy ? null : _toggleWishlist,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)],
                      ),
                      child: Icon(
                        _wishlisted ? Icons.favorite : Icons.favorite_border,
                        size: 12,
                        color: _wishlisted ? AppColors.sale : AppColors.body,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkStrong)),
          const SizedBox(height: 2),
          Text('\$${product.price.toStringAsFixed(2)}', style: TextStyle(color: AppColors.sale, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ],
      ),
    );
  }
}
