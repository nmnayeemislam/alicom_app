import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../state/cart_state.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    CartState.instance.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: ListenableBuilder(
        listenable: CartState.instance,
        builder: (context, _) {
          final cart = CartState.instance;
          if (cart.isLoading && cart.items.isEmpty) {
            return const LoadingView();
          }
          if (cart.items.isEmpty) {
            return const EmptyView(
              icon: Icons.shopping_bag_outlined,
              message: 'Your cart is empty.',
            );
          }

          final subtotal = cart.items.fold<double>(
            0,
            (sum, item) => sum + ((item['subtotal'] as num?)?.toDouble() ?? 0),
          );

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = cart.items[index] as Map;
                    final itemId = item['id'] as int?;
                    final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
                    final price = (item['price'] as num?)?.toDouble() ?? 0;
                    final title = item['product_title'] as String? ?? 'Item';
                    final image = item['product_image'] as String?;
                    final inStock = item['in_stock'] != false;

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: image != null && image.isNotEmpty
                                  ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover)
                                  : Container(color: AppColors.surface),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(
                                  '৳${price.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: AppColors.sale,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (!inStock)
                                  const Text(
                                    'Out of stock',
                                    style: TextStyle(color: Colors.red, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          if (itemId != null) ...[
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 20),
                              onPressed: quantity > 1
                                  ? () => cart.updateQuantity(itemId, quantity - 1)
                                  : () => cart.removeItem(itemId),
                            ),
                            Text('$quantity'),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 20),
                              onPressed: () => cart.updateQuantity(itemId, quantity + 1),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Subtotal', style: TextStyle(color: AppColors.muted)),
                          Text(
                            '৳${subtotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                        ),
                        child: const Text('Checkout'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
