import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/money.dart';
import '../models/product.dart';
import '../services/catalog_service.dart';
import '../state/auth_state.dart';
import '../state/wishlist_state.dart';
import '../state/cart_state.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import '../widgets/write_review_sheet.dart';
import 'cart_screen.dart';
import 'reviews_screen.dart';

/// Product page laid out like the storefront mock: close / title / cart
/// header, big hero image, centred quantity stepper, title with wishlist
/// toggle, availability pill, price row with discount chip and rating,
/// promo notice, collapsible description, reviews, and a sticky full-width
/// Add To Cart bar.
class ProductDetailScreen extends StatefulWidget {
  final String slug;
  const ProductDetailScreen({super.key, required this.slug});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isLoading = true;
  String? _error;
  Product? _product;
  int _quantity = 1;
  bool _descriptionExpanded = false;
  late bool _wishlisted = false;
  bool _wishlistBusy = false;

  bool _isLoadingReviews = true;
  List<Map> _reviews = [];
  Map? _reviewSummary;

  @override
  void initState() {
    super.initState();
    _load();
    _loadReviews();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await CatalogService.instance.product(widget.slug);
      final data = (response is Map ? response['data'] ?? response : response)
          as Map;
      final productData = (data['product'] ?? data) as Map;
      _product = Product.fromJson(productData.cast<String, dynamic>());
      // The shared wishlist wins once it has been loaded for this account;
      // otherwise trust the flag the product payload carried.
      _wishlisted = WishlistState.instance.loadedForUserId != null
          ? WishlistState.instance.contains(_product!.id)
          : _product!.isWishlisted;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoadingReviews = true);
    try {
      final response = await CatalogService.instance.productReviews(widget.slug);
      final data = (response is Map ? response['data'] ?? response : {}) as Map;
      _reviews = ((data['reviews'] as List?) ?? []).map((e) => e as Map).toList();
      _reviewSummary = data['summary'] as Map?;
    } catch (_) {
      // Reviews are a secondary section — a failure here shouldn't block
      // the rest of the product page from rendering.
    } finally {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  Future<void> _openWriteReview() async {
    final product = _product;
    if (product?.id == null) return;

    if (!AuthState.instance.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to write a review.')),
      );
      return;
    }

    final submitted = await showWriteReviewSheet(context, productId: product!.id!);
    if (submitted == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks for your review!')),
        );
      }
      _loadReviews();
    }
  }

  Future<void> _addToCart() async {
    final product = _product;
    if (product == null) return;
    try {
      await CartState.instance.addProduct(product, quantity: _quantity);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${product.title} to cart')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _toggleWishlist() async {
    final id = _product?.id;
    if (id == null || _wishlistBusy) return;
    if (!AuthState.instance.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save items to your wishlist.')),
      );
      return;
    }
    setState(() => _wishlistBusy = true);
    try {
      final wishlisted = await WishlistState.instance.toggle(_product!);
      if (mounted) setState(() => _wishlisted = wishlisted);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update wishlist')),
        );
      }
    } finally {
      if (mounted) setState(() => _wishlistBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        titleSpacing: 0,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: _RoundIconButton(
            icon: Icons.close_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: const Text('Product Details'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ListenableBuilder(
              listenable: CartState.instance,
              builder: (context, _) => _RoundIconButton(
                icon: Icons.shopping_cart_outlined,
                badge: CartState.instance.totalItems,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : product == null
          ? const EmptyView(
              icon: Icons.production_quantity_limits,
              message: 'Product not found.',
            )
          : _buildDetail(product),
      bottomNavigationBar: product == null
          ? null
          : Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: ElevatedButton.icon(
                    onPressed: product.inStock ? _addToCart : null,
                    icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                    label: Text(product.inStock ? 'Add To Cart' : 'Out of Stock'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildDetail(Product product) {
    final description = product.shortDescription?.trim() ?? '';
    final isLongDescription = description.length > 140;
    final ratingFromReviews = (_reviewSummary?['average'] as num?)?.toDouble();
    final rating = ratingFromReviews != null && ratingFromReviews > 0
        ? ratingFromReviews
        : product.averageRating;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _ImageGallery(images: product.images),
        const SizedBox(height: 8),
        Center(
          child: _QuantityStepper(
            quantity: _quantity,
            max: product.inStock ? (product.stock ?? 99) : 1,
            onChanged: (v) => setState(() => _quantity = v),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + wishlist
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 19,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkStrong,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _RoundIconButton(
                    icon: _wishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    iconColor: _wishlisted ? AppColors.sale : null,
                    busy: _wishlistBusy,
                    onTap: _toggleWishlist,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Availability
              _AvailabilityPill(product: product),
              const SizedBox(height: 14),
              // Price + discount + rating. The price group is a Wrap so a
              // six-digit amount plus old price and discount chip can
              // spill onto a second line instead of overflowing past the
              // rating on the right.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          formatPrice(product.price),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: AppColors.inkStrong,
                          ),
                        ),
                        if (product.referencePrice > product.price)
                          Text(
                            formatPrice(product.referencePrice),
                            style: TextStyle(
                              fontSize: 13.5,
                              color: AppColors.muted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        if (product.discountPercentage > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.inkStrong,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${product.discountPercentage}%',
                              style: TextStyle(
                                color: AppColors.card,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (rating != null && rating > 0)
                    // Compact "★ 5.0" chip — the word "Rating" pushed the
                    // row over the edge next to a six-digit price.
                    Material(
                      color: const Color(0xFFF7B500).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _openReviews,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF7B500)),
                              const SizedBox(width: 3),
                              Text(
                                rating.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.inkStrong,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (product.discountPercentage > 0) ...[
                const SizedBox(height: 16),
                const _PromoNotice(),
              ],
              if (description.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text(
                  'Description',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppColors.inkStrong),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  maxLines: _descriptionExpanded || !isLongDescription ? null : 3,
                  overflow: _descriptionExpanded || !isLongDescription
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, height: 1.55, color: AppColors.body),
                ),
                if (isLongDescription)
                  GestureDetector(
                    onTap: () => setState(() => _descriptionExpanded = !_descriptionExpanded),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _descriptionExpanded ? 'Show less' : 'Read More',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              Divider(color: AppColors.line, height: 1),
              const SizedBox(height: 16),
              _buildReviewsSection(),
            ],
          ),
        ),
      ],
    );
  }

  void _openReviews() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewsScreen(
          slug: widget.slug,
          productId: _product?.id,
          productTitle: _product?.title,
        ),
      ),
    );
  }

  Widget _buildReviewsSection() {
    final average = (_reviewSummary?['average'] as num?)?.toDouble() ?? 0;
    final total = (_reviewSummary?['total'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _openReviews,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Text(
                      'Reviews',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppColors.inkStrong),
                    ),
                    if (total > 0) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF7B500)),
                      const SizedBox(width: 2),
                      Text('${average.toStringAsFixed(1)} · $total', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                    ],
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: _openWriteReview,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('Write a review'),
            ),
          ],
        ),
        if (_isLoadingReviews)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No reviews yet — be the first.', style: TextStyle(color: AppColors.muted)),
          )
        else
          ..._reviews.take(3).map((review) => Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            review['reviewer_name'] as String? ?? 'Customer',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.inkStrong),
                          ),
                        ),
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < ((review['rating'] as num?)?.toInt() ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 15,
                            color: const Color(0xFFF7B500),
                          ),
                        ),
                      ],
                    ),
                    if ((review['comment'] as String?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(
                        review['comment'] as String,
                        style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.body),
                      ),
                    ],
                  ],
                ),
              )),
      ],
    );
  }
}

/// Swipeable product photos on the page background (no card), with dots
/// when there is more than one.
class _ImageGallery extends StatefulWidget {
  final List<String> images;
  const _ImageGallery({required this.images});

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images.where((url) => url.isNotEmpty).toList();
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: images.isEmpty
              ? Icon(Icons.image_not_supported_outlined, size: 56, color: AppColors.muted)
              : PageView.builder(
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: CachedNetworkImage(
                        imageUrl: images[i],
                        fit: BoxFit.contain,
                        placeholder: (_, _) => const Center(
                          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (_, _, _) => Icon(Icons.image_not_supported_outlined, size: 56, color: AppColors.muted),
                      ),
                    ),
                  ),
                ),
        ),
        if (images.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _index ? AppColors.primary : AppColors.lineStrong,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Green "in stock" / red "out of stock" pill under the title.
class _AvailabilityPill extends StatelessWidget {
  final Product product;
  const _AvailabilityPill({required this.product});

  @override
  Widget build(BuildContext context) {
    final inStock = product.inStock;
    final color = inStock ? const Color(0xFF1FA65A) : AppColors.sale;
    final unit = product.unit?.trim();
    final stock = product.stock;
    final label = !inStock
        ? 'Out of stock'
        : stock == null
            ? 'In stock'
            : 'In stock · $stock${unit != null && unit.isNotEmpty ? ' $unit' : ''}';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(inStock ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 14, color: color),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
        if (product.category.isNotEmpty) ...[
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              product.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ),
        ],
      ],
    );
  }
}

class _PromoNotice extends StatelessWidget {
  const _PromoNotice();

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFF7B500);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [amber.withValues(alpha: 0.16), amber.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFC98A00)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This promo is limited and may change at any time depending on product availability.',
              style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.bodyStrong),
            ),
          ),
        ],
      ),
    );
  }
}

/// 44px circular button used for close / cart / wishlist.
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final int badge;
  final bool busy;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.badge = 0,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: CircleBorder(side: BorderSide(color: AppColors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 21, color: iconColor ?? AppColors.inkStrong),
              if (badge > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    decoration: BoxDecoration(color: AppColors.sale, shape: badge > 9 ? BoxShape.rectangle : BoxShape.circle, borderRadius: badge > 9 ? BorderRadius.circular(999) : null),
                    alignment: Alignment.center,
                    child: Text(
                      '$badge',
                      style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700, height: 1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered [−] 01 [+] control: outlined minus, filled plus.
class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final int max;
  final ValueChanged<int> onChanged;

  const _QuantityStepper({required this.quantity, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final canDecrement = quantity > 1;
    final canIncrement = quantity < max;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove_rounded,
          filled: false,
          enabled: canDecrement,
          onTap: () => onChanged(quantity - 1),
        ),
        SizedBox(
          width: 52,
          child: Text(
            quantity.toString().padLeft(2, '0'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.inkStrong),
          ),
        ),
        _StepButton(
          icon: Icons.add_rounded,
          filled: true,
          enabled: canIncrement,
          onTap: () => onChanged(quantity + 1),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final bool enabled;
  final VoidCallback onTap;

  const _StepButton({required this.icon, required this.filled, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = filled ? AppColors.primary : AppColors.card;
    final fg = filled ? AppColors.onAccent : AppColors.inkStrong;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: bg,
        shape: CircleBorder(side: BorderSide(color: filled ? AppColors.primary : AppColors.lineStrong)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(width: 38, height: 38, child: Icon(icon, size: 20, color: fg)),
        ),
      ),
    );
  }
}
