import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../screens/product_detail_screen.dart';
import '../services/wishlist_service.dart';
import '../state/cart_state.dart';
import '../theme/app_theme.dart';

/// Mirrors the web storefront's ProductCard.vue: square product image,
/// category label, title, price row with strike-through original price and
/// a discount chip, plus wishlist/cart quick actions.
class ProductCard extends StatefulWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  late bool _wishlisted = widget.product.isWishlisted;
  bool _wishlistBusy = false;

  Future<void> _toggleWishlist() async {
    final id = widget.product.id;
    if (id == null || _wishlistBusy) return;
    setState(() => _wishlistBusy = true);
    try {
      await WishlistService.instance.toggle(id);
      setState(() => _wishlisted = !_wishlisted);
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

  Future<void> _addToCart() async {
    if (!widget.product.inStock) return;
    try {
      await CartState.instance.addProduct(widget.product);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${widget.product.title} to cart')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add to cart')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(slug: product.slug),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: product.primaryImage.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: product.primaryImage,
                              fit: BoxFit.contain,
                              placeholder: (_, __) => const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Icon(
                                Icons.image_not_supported_outlined,
                                color: AppColors.muted,
                              ),
                            )
                          : Icon(
                              Icons.image_not_supported_outlined,
                              color: AppColors.muted,
                            ),
                    ),
                  ),
                  if (product.discountPercentage > 0)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: _Badge(text: '${product.discountPercentage}% OFF'),
                    ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: _CircleIconButton(
                      icon: _wishlisted ? Icons.favorite : Icons.favorite_border,
                      active: _wishlisted,
                      busy: _wishlistBusy,
                      onTap: _toggleWishlist,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.category.isNotEmpty)
                    Text(
                      product.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 2),
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '৳${product.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.sale,
                        ),
                      ),
                      if (product.referencePrice > product.price) ...[
                        const SizedBox(width: 6),
                        Text(
                          '৳${product.referencePrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                      const Spacer(),
                      InkWell(
                        onTap: _addToCart,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: product.inStock
                                ? AppColors.accent
                                : AppColors.lineStrong,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.shopping_cart_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.sale,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final bool busy;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.active,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.accent : AppColors.line,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 16,
          color: active ? AppColors.accent : AppColors.muted,
        ),
      ),
    );
  }
}
