import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/money.dart';
import '../models/product.dart';
import '../screens/product_detail_screen.dart';
import '../state/cart_state.dart';
import '../state/wishlist_state.dart';
import '../theme/app_theme.dart';

/// The two-column storefront card shared by Home ("Popular Products") and
/// the Products tab, so a product looks the same wherever it is listed:
/// soft-shadow card, image on a tinted tile with a discount pill and a
/// wishlist toggle, then title, rating + category, and the price row with
/// an add-to-cart button.
///
/// Lay it out with `childAspectRatio: 0.68` in a 2-column grid.
class ProductGridCard extends StatefulWidget {
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
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailScreen(slug: product.slug)),
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: AppColors.background,
                      padding: const EdgeInsets.all(12),
                      child: product.primaryImage.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: product.primaryImage,
                              fit: BoxFit.contain,
                              placeholder: (_, _) => const SizedBox.shrink(),
                              errorWidget: (_, _, _) => Icon(Icons.image_not_supported_outlined, color: AppColors.body),
                            )
                          : Icon(Icons.image_not_supported_outlined, color: AppColors.body),
                    ),
                  ),
                  if (product.discountPercentage > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.sale, borderRadius: BorderRadius.circular(999)),
                        child: Text('-${product.discountPercentage}%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  if (!product.inStock)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.inkStrong.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(999)),
                        child: Text('Out of stock', style: TextStyle(color: AppColors.card, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: InkWell(
                      onTap: _busy ? null : _toggleWishlist,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6)],
                        ),
                        child: Icon(
                          _wishlisted ? Icons.favorite : Icons.favorite_border,
                          size: 14,
                          color: _wishlisted ? AppColors.sale : AppColors.body,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkStrong)),
            const SizedBox(height: 3),
            Row(
              children: [
                if (product.averageRating != null && product.averageRating! > 0) ...[
                  const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF7B500)),
                  const SizedBox(width: 2),
                  Text(product.averageRating!.toStringAsFixed(1), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.bodyStrong)),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    product.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Price and the struck-through original stack vertically:
                // side by side they don't fit a half-width card once the
                // amount runs to six digits and the old price got clipped
                // to "$15".
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (product.referencePrice > product.price)
                        Text(
                          formatPrice(product.referencePrice),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.muted, fontSize: 11, decoration: TextDecoration.lineThrough),
                        ),
                      Text(
                        formatPrice(product.price),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.sale, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: product.inStock && !_adding ? _addToCart : null,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: product.inStock ? AppColors.primary : AppColors.lineStrong,
                      shape: BoxShape.circle,
                    ),
                    child: _adding
                        ? const Padding(
                            padding: EdgeInsets.all(7),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.add, color: Colors.white, size: 16),
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
