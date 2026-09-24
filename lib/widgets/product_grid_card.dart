import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/money.dart';
import '../models/product.dart';
import '../screens/product_detail_screen.dart';
import '../state/cart_state.dart';
import '../state/wishlist_state.dart';
import '../theme/app_theme.dart';

/// The two-column storefront card shared by Home, the Products tab and
/// Wishlist, so a product looks the same wherever it is listed: an
/// edge-to-edge photo with a "New" badge and a wishlist heart,
/// then the brand, a one-line name, and the price beside a round add button.
///
/// Lay it out with [ProductGridDelegate] (or, in a horizontal row, a height
/// of `width + infoHeightFor(context)`), which makes the photo square.
class ProductGridCard extends StatefulWidget {
  /// Height of everything under the photo — brand line, name, price row and
  /// padding. The text parts grow with the system font size; the paddings
  /// and the 36px add button do not. Measured at 1.0 scale as ~104px, with
  /// a few px spare so a large font never overflows.
  static double infoHeightFor(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return 36 + 72 * scale;
  }

  final Product product;
  /// Fired after the wishlist toggle round-trips, with the new state — the
  /// Wishlist tab uses it to drop un-hearted items from its grid.
  final ValueChanged<bool>? onWishlistChanged;
  const ProductGridCard({super.key, required this.product, this.onWishlistChanged});

  @override
  State<ProductGridCard> createState() => _ProductGridCardState();
}

class _ProductGridCardState extends State<ProductGridCard> {
  bool _busy = false;
  bool _adding = false;

  /// Briefly true after a successful add, so the + turns into a ✓.
  bool _justAdded = false;
  Timer? _justAddedTimer;

  /// Finger is down on the card — drives the slight press-in scale.
  bool _pressed = false;

  @override
  void dispose() {
    _justAddedTimer?.cancel();
    super.dispose();
  }

  /// Prefer the shared wishlist once it has been loaded for this account —
  /// a heart tapped on another screen has to show here too. Before that,
  /// fall back to the flag the listing payload carried.
  bool get _wishlisted => WishlistState.instance.loadedForUserId != null
      ? WishlistState.instance.contains(widget.product.id)
      : widget.product.isWishlisted;

  Future<void> _toggleWishlist() async {
    final id = widget.product.id;
    if (id == null || _busy) return;
    setState(() => _busy = true);
    try {
      final wishlisted = await WishlistState.instance.toggle(widget.product);
      widget.onWishlistChanged?.call(wishlisted);
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

  Future<void> _addToCart() async {
    if (_adding || !widget.product.inStock) return;
    setState(() => _adding = true);
    try {
      await CartState.instance.addProduct(widget.product);
      if (mounted) {
        setState(() => _justAdded = true);
        _justAddedTimer?.cancel();
        _justAddedTimer = Timer(const Duration(milliseconds: 1400), () {
          if (mounted) setState(() => _justAdded = false);
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Added ${widget.product.title} to cart'),
              duration: const Duration(seconds: 2),
            ),
          );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add to cart')),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    // Rebuilds the heart when the wishlist changes anywhere else in the app.
    return ListenableBuilder(
      listenable: WishlistState.instance,
      builder: (context, _) => _buildCard(context, product),
    );
  }

  Widget _buildCard(BuildContext context, Product product) {
    final label = (product.brandName?.isNotEmpty == true ? product.brandName! : product.category).toUpperCase();
    const radius = BorderRadius.all(Radius.circular(20));
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      // The shadow sits on an outer box: painted as Ink inside the Material
      // it filled the card itself and turned the white info area grey.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 6)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 3, offset: const Offset(0, 1)),
          ],
        ),
        child: Material(
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            // Hairline edge keeps the white card crisp on the pale page.
            side: BorderSide(color: AppColors.line.withValues(alpha: 0.8)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProductDetailScreen(slug: product.slug)),
            ),
            onHighlightChanged: (down) => setState(() => _pressed = down),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildImage(product)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          // `discount_label` from the API ("10% OFF"), only
                          // when there is an original price to strike through.
                          if (product.referencePrice > product.price && product.discountBadge != null)
                            _DiscountPill(label: product.discountBadge!),
                        ],
                      ),
                      const SizedBox(height: 5),
                      // One line, ellipsized — keeps every card the same
                      // height so price rows line up across the grid.
                      SizedBox(
                        height: 14.5 * 1.25,
                        child: Text(
                          product.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.1,
                            color: AppColors.inkStrong,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Old price struck through above the new one, so
                          // the "-12%" pill has the price it came off. The
                          // line is kept (empty) on full-price cards so price
                          // rows still line up across the grid. Both shrink
                          // rather than truncate — a six-digit price must
                          // never read as "\$133,399....".
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 16,
                                  child: product.referencePrice > product.price
                                      ? FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            formatPrice(product.referencePrice),
                                            maxLines: 1,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.muted,
                                              decoration: TextDecoration.lineThrough,
                                              decorationColor: AppColors.muted,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    formatPrice(product.price),
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                      color: AppColors.inkStrong,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildAddButton(product),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Edge-to-edge photo with the "New" badge top-left and the
  /// wishlist heart top-right. Sold-out stock is washed out so it reads as
  /// unavailable at a glance.
  Widget _buildImage(Product product) {
    // Only "New" gets a badge. A "Best Seller" pill was tried and dropped:
    // nearly every product carries the flag, so it cluttered every photo
    // without telling shoppers anything.
    final badge = product.isNew
        ? _Badge(label: 'New', background: AppColors.sale, foreground: Colors.white)
        : null;
    final fallback = Center(
      child: Icon(Icons.image_outlined, size: 30, color: AppColors.lineStrong),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: AppColors.background,
          child: product.primaryImage.isNotEmpty
              ? LayoutBuilder(
                  // Decode at the size it is drawn, not the 900px original:
                  // sharper downscaling and far less memory while scrolling.
                  builder: (context, constraints) => CachedNetworkImage(
                    imageUrl: product.primaryImage,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.medium,
                    memCacheWidth: constraints.maxWidth.isFinite
                        ? (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context)).round()
                        : null,
                    fadeInDuration: const Duration(milliseconds: 250),
                    placeholder: (_, _) => fallback,
                    errorWidget: (_, _, _) => fallback,
                  ),
                )
              : fallback,
        ),
        if (!product.inStock) ColoredBox(color: AppColors.card.withValues(alpha: 0.45)),
        if (badge != null) Positioned(top: 10, left: 10, child: badge),
        if (!product.inStock)
          Positioned(
            bottom: 10,
            left: 10,
            child: _Badge(
              label: 'Out of stock',
              background: AppColors.inkStrong.withValues(alpha: 0.8),
              foreground: AppColors.card,
            ),
          ),
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: AppColors.card,
            shape: const CircleBorder(),
            elevation: 0,
            child: InkWell(
              onTap: _busy ? null : _toggleWishlist,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 34,
                height: 34,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                    child: child,
                  ),
                  child: Icon(
                    _wishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    key: ValueKey(_wishlisted),
                    size: 17,
                    color: _wishlisted ? AppColors.sale : AppColors.inkStrong,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Grey "+" that turns into a brand-coloured ✓ for a moment after the
  /// product lands in the cart.
  Widget _buildAddButton(Product product) {
    final enabled = product.inStock && !_adding;
    final Widget icon;
    if (_adding) {
      icon = SizedBox(
        key: const ValueKey('busy'),
        width: 15,
        height: 15,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.inkStrong),
      );
    } else if (_justAdded) {
      icon = const Icon(Icons.check_rounded, key: ValueKey('done'), size: 19, color: Colors.white);
    } else {
      icon = Icon(
        Icons.add_rounded,
        key: const ValueKey('add'),
        size: 20,
        color: product.inStock ? AppColors.inkStrong : AppColors.muted,
      );
    }
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? _addToCart : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _justAdded
                ? AppColors.primary
                : product.inStock
                    ? AppColors.line
                    : AppColors.line.withValues(alpha: 0.5),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
            child: icon,
          ),
        ),
      ),
    );
  }
}

/// Small rounded label on the product photo ("New", "Out of stock").
class _Badge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _Badge({required this.label, required this.background, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.1, color: foreground),
      ),
    );
  }
}

/// Soft red "10% OFF" chip on the brand line.
class _DiscountPill extends StatelessWidget {
  final String label;
  const _DiscountPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.sale.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.sale),
      ),
    );
  }
}

/// Two-column grid for [ProductGridCard] where every tile is exactly its
/// width plus [infoHeight] tall — so the (square) product photo is drawn
/// square on any screen width, instead of being cropped by a fixed aspect
/// ratio that only fits one phone.
class ProductGridDelegate extends SliverGridDelegate {
  final double infoHeight;
  final double spacing;

  const ProductGridDelegate({required this.infoHeight, this.spacing = 14});

  /// Convenience for the common case: info height from the current text
  /// scale.
  factory ProductGridDelegate.of(BuildContext context) =>
      ProductGridDelegate(infoHeight: ProductGridCard.infoHeightFor(context));

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final tileWidth = (constraints.crossAxisExtent - spacing) / 2;
    final tileHeight = tileWidth + infoHeight;
    return SliverGridRegularTileLayout(
      crossAxisCount: 2,
      mainAxisStride: tileHeight + spacing,
      crossAxisStride: tileWidth + spacing,
      childMainAxisExtent: tileHeight,
      childCrossAxisExtent: tileWidth,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(ProductGridDelegate oldDelegate) =>
      oldDelegate.infoHeight != infoHeight || oldDelegate.spacing != spacing;
}
