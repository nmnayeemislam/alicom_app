import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/catalog_service.dart';
import '../state/auth_state.dart';
import '../state/cart_state.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import '../widgets/write_review_sheet.dart';
import 'reviews_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_product?.title ?? 'Product')),
      body: _isLoading
          ? const LoadingView()
          : _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : _product == null
          ? const EmptyView(
              icon: Icons.production_quantity_limits,
              message: 'Product not found.',
            )
          : _buildDetail(_product!),
      bottomNavigationBar: _product == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    _QuantityStepper(
                      quantity: _quantity,
                      onChanged: (v) => setState(() => _quantity = v),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _product!.inStock ? _addToCart : null,
                        child: Text(
                          _product!.inStock ? 'Add to Cart' : 'Out of Stock',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDetail(Product product) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: product.primaryImage.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: product.primaryImage,
                    fit: BoxFit.contain,
                  )
                : Icon(
                    Icons.image_not_supported_outlined,
                    size: 48,
                    color: AppColors.muted,
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.category.isNotEmpty)
                Text(product.category, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(product.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '৳${product.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.sale,
                    ),
                  ),
                  if (product.referencePrice > product.price) ...[
                    const SizedBox(width: 10),
                    Text(
                      '৳${product.referencePrice.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: AppColors.muted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                  if (product.discountPercentage > 0) ...[
                    const SizedBox(width: 10),
                    Text(
                      '${product.discountPercentage}% OFF',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                product.inStock ? 'In stock (${product.stock} ${product.unit ?? ''})' : 'Out of stock',
                style: TextStyle(
                  color: product.inStock ? AppColors.body : AppColors.sale,
                ),
              ),
              if (product.shortDescription != null && product.shortDescription!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text('Description', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(product.shortDescription!, style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              _buildReviewsSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection() {
    final average = (_reviewSummary?['average'] as num?)?.toDouble() ?? 0;
    final total = (_reviewSummary?['total'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReviewsScreen(
                slug: widget.slug,
                productId: _product?.id,
                productTitle: _product?.title,
              ),
            ),
          ),
          child: Row(
            children: [
              Text('Reviews', style: Theme.of(context).textTheme.titleSmall),
              if (total > 0) ...[
                const SizedBox(width: 8),
                Icon(Icons.star, size: 14, color: AppColors.accent),
                const SizedBox(width: 2),
                Text('${average.toStringAsFixed(1)} ($total)', style: TextStyle(color: AppColors.muted)),
              ],
              const Spacer(),
              Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: _openWriteReview, child: const Text('Write a review')),
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
          ..._reviews.map((review) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          review['reviewer_name'] as String? ?? 'Customer',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < ((review['rating'] as num?)?.toInt() ?? 0) ? Icons.star : Icons.star_border,
                            size: 13,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                    if ((review['comment'] as String?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(review['comment'] as String),
                    ],
                  ],
                ),
              )),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;

  const _QuantityStepper({required this.quantity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
          ),
          Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => onChanged(quantity + 1),
          ),
        ],
      ),
    );
  }
}
