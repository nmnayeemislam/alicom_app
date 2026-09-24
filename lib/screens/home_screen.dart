import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/api_config.dart';
import '../core/money.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../services/catalog_service.dart';
import '../services/content_service.dart';
import '../services/settings_service.dart';
import '../state/auth_state.dart';
import '../state/cart_state.dart';
import '../theme/app_theme.dart';
import '../widgets/product_grid_card.dart';
import '../widgets/state_views.dart';
import 'cart_screen.dart';
import 'main_shell.dart';
import 'notifications_screen.dart';
import 'product_detail_screen.dart';
import 'shop_by_category_screen.dart';
import 'products_screen.dart';

/// Decorative-only accent that isn't part of the light/dark palette — the
/// flash-sale flame/clock reads fine unchanged in either theme.
const _flame = Color(0xFFF97316);

typedef _CategoryStyle = ({Color bg, Color fg, IconData icon});

const _fallbackCategoryStyle = (bg: Color(0xFFEDEDF5), fg: Color(0xFF6E7191), icon: Icons.grid_view_rounded);

// Matched by substring, first hit wins — so keep the specific keywords
// ("appliance", "phone") above the broad ones ("home", "electronic").
const _categoryStyles = <String, _CategoryStyle>{
  'phone': (bg: Color(0xFFE8E6FB), fg: Color(0xFF5B4FE5), icon: Icons.smartphone_rounded),
  'mobile': (bg: Color(0xFFE8E6FB), fg: Color(0xFF5B4FE5), icon: Icons.smartphone_rounded),
  'laptop': (bg: Color(0xFFE0F2FE), fg: Color(0xFF0284C7), icon: Icons.laptop_mac_rounded),
  'computer': (bg: Color(0xFFE0F2FE), fg: Color(0xFF0284C7), icon: Icons.computer_rounded),
  'tablet': (bg: Color(0xFFE0F2FE), fg: Color(0xFF0284C7), icon: Icons.tablet_mac_rounded),
  'audio': (bg: Color(0xFFFCE7F3), fg: Color(0xFFDB4C97), icon: Icons.headphones_rounded),
  'headphone': (bg: Color(0xFFFCE7F3), fg: Color(0xFFDB4C97), icon: Icons.headphones_rounded),
  'speaker': (bg: Color(0xFFFCE7F3), fg: Color(0xFFDB4C97), icon: Icons.speaker_rounded),
  'wearable': (bg: Color(0xFFFFF1E0), fg: Color(0xFFF97316), icon: Icons.watch_rounded),
  'watch': (bg: Color(0xFFFFF1E0), fg: Color(0xFFF97316), icon: Icons.watch_rounded),
  'appliance': (bg: Color(0xFFE3F6E8), fg: Color(0xFF2E9E5B), icon: Icons.kitchen_rounded),
  'camera': (bg: Color(0xFFE8E6FB), fg: Color(0xFF5B4FE5), icon: Icons.photo_camera_rounded),
  'gaming': (bg: Color(0xFFE8E6FB), fg: Color(0xFF5B4FE5), icon: Icons.sports_esports_rounded),
  'tv': (bg: Color(0xFFE0F2FE), fg: Color(0xFF0284C7), icon: Icons.tv_rounded),
  'accessor': (bg: Color(0xFFEDEDF5), fg: Color(0xFF6E7191), icon: Icons.cable_rounded),
  'electronic': (bg: Color(0xFFE8E6FB), fg: Color(0xFF5B4FE5), icon: Icons.devices_rounded),
  'shirt': (bg: Color(0xFFFCE4EC), fg: Color(0xFFE94560), icon: Icons.checkroom_rounded),
  'fashion': (bg: Color(0xFFFCE4EC), fg: Color(0xFFE94560), icon: Icons.checkroom_rounded),
  'cloth': (bg: Color(0xFFFCE4EC), fg: Color(0xFFE94560), icon: Icons.checkroom_rounded),
  'shoe': (bg: Color(0xFFFCE4EC), fg: Color(0xFFE94560), icon: Icons.hiking_rounded),
  'furniture': (bg: Color(0xFFE3F6E8), fg: Color(0xFF2E9E5B), icon: Icons.weekend_rounded),
  'home': (bg: Color(0xFFE3F6E8), fg: Color(0xFF2E9E5B), icon: Icons.weekend_rounded),
  'beauty': (bg: Color(0xFFFFE7EC), fg: Color(0xFFDB4C97), icon: Icons.spa_rounded),
  'sport': (bg: Color(0xFFFFF1E0), fg: Color(0xFFF97316), icon: Icons.sports_basketball_rounded),
  'grocery': (bg: Color(0xFFE3F6E8), fg: Color(0xFF2E9E5B), icon: Icons.local_grocery_store_rounded),
  'food': (bg: Color(0xFFFFF1E0), fg: Color(0xFFF97316), icon: Icons.restaurant_rounded),
  'fiction': (bg: Color(0xFFE8E6FB), fg: Color(0xFF5B4FE5), icon: Icons.auto_stories_rounded),
  'book': (bg: Color(0xFFE8E6FB), fg: Color(0xFF5B4FE5), icon: Icons.menu_book_rounded),
  'toy': (bg: Color(0xFFFCE7F3), fg: Color(0xFFDB4C97), icon: Icons.toys_rounded),
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

  /// `featured_categories` from `/home/fetch-data`, trimmed the way the
  /// website trims it (see [_featuredRows]).
  List<_CategoryProducts> _byCategory = [];
  List<Map<String, dynamic>> _banners = [];

  /// Banner products the home feed didn't already include, fetched by slug
  /// so every slide can show its discount badge (see [_productBySlug]).
  final Map<String, Product> _bannerProducts = {};
  Map<String, dynamic>? _flashSale;
  List<Product> _flashProducts = [];

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

      // Pull-to-refresh re-reads branding too, so a currency changed in the
      // admin panel shows up without restarting the app.
      CurrencySettings.applyBranding(results[5]);
      final branding = (results[5] is Map ? results[5]['data'] ?? results[5] : results[5]) as Map?;
      final hex = branding?['theme_primary_color'] as String?;
      final parsed = _parseHexColor(hex);
      if (parsed != null) AppColors.setBrandPrimary(parsed);

      final home = (results[0] is Map ? results[0]['data'] ?? results[0] : results[0]) as Map?;
      _popular = _extractProducts(home, ['best_seller_products', 'best_seller', 'featured_products']);
      _categories = _extractList(results[1], ['categories']);
      _byCategory = _featuredRows(home?['featured_categories']);

      final heroBanners = _extractList(results[2], ['hero_banners']);
      final plainBanners = _extractList(results[3], ['banners']);
      _banners = (heroBanners.isNotEmpty ? heroBanners : plainBanners)
          .take(_maxBannerSlides)
          .toList();

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
      _loadBannerProducts();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Rows arrive in the order the admin set, and that order is kept. The
  /// API sends every featured category, so the website's rules are applied
  /// here: drop rows with fewer than [_minRowProducts] products, then show
  /// only the first [_maxRows].
  List<_CategoryProducts> _featuredRows(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => _CategoryProducts.fromJson(e.cast<String, dynamic>()))
        .where((row) => row.products.length >= _minRowProducts)
        .take(_maxRows)
        .toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const _HomeSkeleton()
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
                      // No "See All" here — the grid's own "More" tile does that job.
                      _buildSectionHeader(context, 'Categories'),
                      _buildCategoryGrid(context),
                      if (_flashProducts.isNotEmpty) ...[
                        _buildFlashHeader(context),
                        _buildFlashRow(context),
                      ],
                      _buildSectionHeader(context, 'Popular Products', onSeeAll: () => _goToProducts(context)),
                      _buildPopularGrid(context),
                      ..._buildCategorySections(context),
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

  void _goToCategories(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ShopByCategoryScreen()),
      );

  void _goToCategory(BuildContext context, _CategoryProducts row) {
    // Without a slug the grid has nothing to filter by, so fall back to the
    // full catalogue rather than opening an empty screen.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => row.slug.isEmpty
            ? const ProductsScreen()
            : ProductsScreen(
                initialCategorySlug: row.slug,
                initialCategoryName: row.name,
              ),
      ),
    );
  }

  // --- TOP BAR ---------------------------------------------------------

  /// Greeting header: the shopper's avatar with a time-of-day greeting and
  /// their name (tap → Profile tab, which holds everything the old side
  /// menu did), then round bell and cart buttons.
  /// Guests get a neutral avatar and "Welcome to Alicom".
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: AuthState.instance,
              builder: (context, _) {
                final user = AuthState.instance.user;
                final firstName = (user?.name ?? '').trim().split(RegExp(r'\s+')).first;
                return InkWell(
                  onTap: () => MainShell.selectTab(context, MainShell.profileTab),
                  borderRadius: BorderRadius.circular(30),
                  child: Row(
                    children: [
                      _GreetingAvatar(user: user),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _greeting(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              firstName.isNotEmpty ? firstName : 'Welcome to Alicom',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: AppColors.inkStrong,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          _RoundIconButton(
            icon: Icons.notifications_none_rounded,
            showDot: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          const SizedBox(width: 10),
          ListenableBuilder(
            listenable: CartState.instance,
            builder: (context, _) => _RoundIconButton(
              icon: Icons.shopping_bag_outlined,
              count: CartState.instance.totalItems,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CartScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good Morning';
    if (hour >= 12 && hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  // --- SEARCH ------------------------------------------------------------
  Widget _buildSearchRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
                  border: Border.all(color: AppColors.line),
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
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5)),
                ],
              ),
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
              if (image == null || image.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _fallbackBannerCard(context),
                  ),
                );
              }
              // `product_url` is a storefront path (`/products/<slug>`); the
              // slug is all the detail screen needs.
              final slug = _bannerSlug(banner);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _PromoSlide(
                  image: image,
                  title: (banner['product_title'] as String?) ?? 'Special Offer',
                  discount: slug == null ? 0 : _productBySlug(slug)?.discountPercentage ?? 0,
                  onShopNow: () => slug == null
                      ? _goToProducts(context)
                      : Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ProductDetailScreen(slug: slug)),
                        ),
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

  static String? _bannerSlug(Map<String, dynamic> banner) {
    final url = banner['product_url'] as String?;
    return url == null || url.isEmpty ? null : Uri.parse(url).pathSegments.lastOrNull;
  }

  /// Fetches `/products/{slug}` for banner products not found in the home
  /// feed — e.g. one from a category row hidden for having under three
  /// products. Decoration only: a failure just leaves that slide unbadged.
  Future<void> _loadBannerProducts() async {
    final missing = _banners
        .map(_bannerSlug)
        .whereType<String>()
        .where((slug) => _productBySlug(slug) == null)
        .toSet();
    if (missing.isEmpty) return;
    await Future.wait(missing.map((slug) async {
      try {
        final response = await CatalogService.instance.product(slug);
        final data = response is Map ? response['data'] : null;
        final raw = data is Map ? data['product'] : null;
        if (raw is Map) {
          _bannerProducts[slug] = Product.fromJson(raw.cast<String, dynamic>());
        }
      } catch (_) {}
    }));
    if (mounted) setState(() {});
  }

  /// The banner payload carries no price, so a slide's discount badge is
  /// borrowed from the same product wherever else the home feed loaded it.
  Product? _productBySlug(String slug) {
    final fetched = _bannerProducts[slug];
    if (fetched != null) return fetched;
    for (final product in [
      ..._popular,
      ..._flashProducts,
      for (final row in _byCategory) ...row.products,
    ]) {
      if (product.slug == slug) return product;
    }
    return null;
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
  Widget _buildSectionHeader(BuildContext context, String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
              ),
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.inkStrong)),
            ],
          ),
          if (onSeeAll != null)
          InkWell(
            onTap: onSeeAll,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(999)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View All', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12.5)),
                  const SizedBox(width: 3),
                  Icon(Icons.arrow_forward, size: 13, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- CATEGORIES ----------------------------------------------------------
  /// Four across, two rows: the first seven categories from `/categories`
  /// (featured first) with their `img`, then a "More" tile into the full
  /// categories screen.
  Widget _buildCategoryGrid(BuildContext context) {
    if (_categories.isEmpty) return const SizedBox.shrink();
    final items = _categories.take(_homeCategoryCount).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length + 1,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        // Square image plus room for a two-line name ("Fruits & Vegs").
        childAspectRatio: 0.64,
      ),
      itemBuilder: (context, i) {
        if (i == items.length) {
          return _CategoryTile(
            label: 'More',
            onTap: () => _goToCategories(context),
            child: Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: AppColors.line, shape: BoxShape.circle),
                child: Icon(Icons.grid_view_rounded, size: 22, color: AppColors.inkStrong),
              ),
            ),
          );
        }
        final cat = items[i];
        final name = (cat['name'] ?? cat['title'] ?? '').toString();
        final slug = cat['slug'] as String?;
        final image = ApiConfig.resolveUrl(cat['img'] as String?);
        final style = _styleForCategory(name);
        // Without an image, fall back to the keyword icon on its tint.
        final fallback = Container(
          color: style.bg,
          child: Icon(style.icon, size: 28, color: style.fg),
        );
        return _CategoryTile(
          label: name,
          // Open the catalogue filtered to this category.
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductsScreen(initialCategorySlug: slug, initialCategoryName: name),
            ),
          ),
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
        );
      },
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
              decoration: BoxDecoration(
                color: AppColors.sale.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 13, color: AppColors.sale),
                  const SizedBox(width: 4),
                  Text(
                    '${_twoDigits(_timeLeft.inHours)} : ${_twoDigits(_timeLeft.inMinutes % 60)} : ${_twoDigits(_timeLeft.inSeconds % 60)}',
                    style: TextStyle(color: AppColors.sale, fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                ],
              ),
            )
          else
            InkWell(
              onTap: () => _goToProducts(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View All', style: TextStyle(color: AppColors.body, fontWeight: FontWeight.w500, fontSize: 13.5)),
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

  // --- PRODUCTS BY CATEGORY ------------------------------------------------

  /// One horizontal row per featured category, each with its own "See All"
  /// into the paginated, filtered grid.
  List<Widget> _buildCategorySections(BuildContext context) {
    if (_byCategory.isEmpty) return const [];
    return [
      for (final row in _byCategory) ...[
        _buildSectionHeader(context, row.name,
            onSeeAll: () => _goToCategory(context, row)),
        SizedBox(
          // A 158-wide ProductGridCard with a square photo on top.
          height: _rowCardWidth + ProductGridCard.infoHeightFor(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: row.products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) => SizedBox(
              width: _rowCardWidth,
              child: ProductGridCard(product: row.products[i]),
            ),
          ),
        ),
      ],
    ];
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
        gridDelegate: ProductGridDelegate.of(context),
        itemBuilder: (context, i) => ProductGridCard(product: _popular[i]),
      ),
    );
  }
}

/// One hero-banner slide: a "Limited Time Offer" chip, the product name and
/// a Shop Now button on a soft brand gradient, with the banner image on the
/// right and a round discount badge when the product is on sale.
class _PromoSlide extends StatelessWidget {
  final String image;
  final String title;
  final int discount;
  final VoidCallback onShopNow;

  const _PromoSlide({
    required this.image,
    required this.title,
    required this.discount,
    required this.onShopNow,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onShopNow,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.lerp(AppColors.primarySoft, AppColors.primary, 0.18)!,
                AppColors.primarySoft,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Soft decorative rings, as in the mock's background.
              Positioned(
                top: -40,
                left: -30,
                child: _ring(130),
              ),
              Positioned(
                bottom: -60,
                right: 90,
                child: _ring(150),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 11,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.card.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_fire_department_rounded, size: 13, color: _flame),
                                const SizedBox(width: 4),
                                Text(
                                  'Limited Time Offer',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              color: AppColors.inkStrong,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Material(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(999),
                            elevation: 0,
                            child: InkWell(
                              onTap: onShopNow,
                              borderRadius: BorderRadius.circular(999),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                                child: Text(
                                  'Shop Now',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.inkStrong,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 9,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: CachedNetworkImage(
                                imageUrl: image,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(color: AppColors.card.withValues(alpha: 0.5)),
                                errorWidget: (_, _, _) => Icon(
                                  Icons.image_not_supported_outlined,
                                  color: AppColors.body,
                                ),
                              ),
                            ),
                          ),
                          if (discount > 0)
                            Positioned(
                              left: -12,
                              bottom: 10,
                              child: Container(
                                width: 50,
                                height: 50,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5E6C8),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 3)),
                                  ],
                                ),
                                child: Text(
                                  '$discount%\nOFF',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    height: 1.1,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF7A4B12),
                                  ),
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
        ),
      ),
    );
  }

  Widget _ring(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.card.withValues(alpha: 0.35), width: 18),
        ),
      );
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
                Text(formatPrice(product.price), style: TextStyle(color: AppColors.sale, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(width: 6),
                Expanded(
                  child: product.referencePrice > product.price
                      ? Text(
                          formatPrice(product.referencePrice),
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

/// The home slider shows at most this many banners, in API order.
const _maxBannerSlides = 3;

/// Card width in the horizontal per-category product rows.
const _rowCardWidth = 158.0;

/// Categories shown in the home grid before the "More" tile — two rows of
/// four with "More" as the eighth.
const _homeCategoryCount = 7;

/// Website rules for the featured-category rows: a row needs at least this
/// many products to be shown...
const _minRowProducts = 3;

/// ...and only this many rows are shown.
const _maxRows = 6;

/// Grid cell for the home Categories section: a square picture over a
/// centred name of up to two lines.
class _CategoryTile extends StatelessWidget {
  final String label;
  final Widget child;
  final VoidCallback onTap;

  const _CategoryTile({required this.label, required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          AspectRatio(aspectRatio: 1, child: child),
          const SizedBox(height: 7),
          // Takes whatever height is left, so a large system font size
          // ellipsizes the name instead of overflowing the cell.
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: AppColors.inkStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One entry of `featured_categories`: a category and up to 10 of its
/// products.
class _CategoryProducts {
  final String name;

  /// Passed straight to `/products?category_slug=` for "View All"; any
  /// level works, a parent returning its sub-categories' products too.
  final String slug;

  final List<Product> products;

  const _CategoryProducts({
    required this.name,
    required this.slug,
    required this.products,
  });

  factory _CategoryProducts.fromJson(Map<String, dynamic> json) {
    final raw = json['products'];
    return _CategoryProducts(
      name: json['category_name'] as String? ?? '',
      slug: json['category_slug'] as String? ?? '',
      products: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Product.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
    );
  }
}

/// Grey placeholder blocks in the shape of the home screen — banner,
/// category grid, then a product row — pulsing gently while the first
/// load is in flight, so the layout doesn't jump when real content lands.
class _HomeSkeleton extends StatefulWidget {
  const _HomeSkeleton();

  @override
  State<_HomeSkeleton> createState() => _HomeSkeletonState();
}

class _HomeSkeletonState extends State<_HomeSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _box({double? width, required double height, double radius = 14}) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.line,
          borderRadius: BorderRadius.circular(radius),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cardWidth = _rowCardWidth;
    final cardHeight = cardWidth + ProductGridCard.infoHeightFor(context);
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_pulse),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              _box(width: 42, height: 42),
              const SizedBox(width: 12),
              _box(width: 90, height: 28, radius: 8),
              const Spacer(),
              _box(width: 42, height: 42),
              const SizedBox(width: 10),
              _box(width: 42, height: 42),
            ],
          ),
          const SizedBox(height: 18),
          _box(height: 50, radius: 16),
          const SizedBox(height: 16),
          _box(height: 190, radius: 22),
          const SizedBox(height: 26),
          _box(width: 130, height: 20, radius: 6),
          const SizedBox(height: 14),
          for (var row = 0; row < 2; row++) ...[
            Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        AspectRatio(aspectRatio: 1, child: _box(height: 0, radius: 16)),
                        const SizedBox(height: 8),
                        _box(width: 50, height: 10, radius: 4),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 10),
          _box(width: 150, height: 20, radius: 6),
          const SizedBox(height: 14),
          SizedBox(
            height: cardHeight,
            child: Row(
              children: [
                _box(width: cardWidth, height: cardHeight, radius: 20),
                const SizedBox(width: 14),
                Expanded(child: _box(height: cardHeight, radius: 20)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Round profile picture for the home greeting: the uploaded photo, else
/// the user's initials, else (guest) a person icon — on a brand ring.
class _GreetingAvatar extends StatelessWidget {
  final AppUser? user;
  const _GreetingAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final url = ApiConfig.resolveUrl(user?.avatarUrl);
    final fallback = Container(
      color: AppColors.primarySoft,
      alignment: Alignment.center,
      child: user == null
          ? Icon(Icons.person_rounded, color: AppColors.primary, size: 24)
          : Text(
              user!.initials,
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 16),
            ),
    );
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.55), width: 2),
      ),
      child: ClipOval(
        child: SizedBox(
          width: 42,
          height: 42,
          child: url == null
              ? fallback
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => fallback,
                  errorWidget: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}

/// 46px round button on the card colour with a soft shadow; optional red
/// dot (bell) or count badge (cart).
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;
  final int count;

  const _RoundIconButton({required this.icon, required this.onTap, this.showDot = false, this.count = 0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 4)),
              ],
            ),
            child: Material(
              color: AppColors.card,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: SizedBox.expand(
                  child: Icon(icon, size: 22, color: AppColors.inkStrong),
                ),
              ),
            ),
          ),
          if (showDot)
            Positioned(
              top: 12,
              right: 13,
              child: IgnorePointer(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.sale,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.card, width: 1.5),
                  ),
                ),
              ),
            ),
          if (count > 0)
            Positioned(
              top: -3,
              right: -3,
              child: IgnorePointer(
                child: Container(
                  constraints: const BoxConstraints(minWidth: 19),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.background, width: 2),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
