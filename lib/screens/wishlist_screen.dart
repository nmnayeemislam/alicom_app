import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/wishlist_service.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import '../widgets/state_views.dart';
import 'login_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  bool _isLoading = true;
  String? _error;
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    if (AuthState.instance.isAuthenticated) _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await WishlistService.instance.index();
      final data = (response is Map ? response['data'] ?? response : {}) as Map;
      final list = (data['products'] as List?) ?? [];
      _products = list
          .whereType<Map>()
          .map((e) => Product.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthState.instance.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wishlist')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border, size: 48, color: AppColors.muted),
              const SizedBox(height: 12),
              const Text('Sign in to view your wishlist.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const LoadingView()
            : _error != null
            ? ErrorView(message: _error!, onRetry: _load)
            : _products.isEmpty
            ? const EmptyView(
                icon: Icons.favorite_border,
                message: 'Your wishlist is empty.',
              )
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _products.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.62,
                ),
                itemBuilder: (context, index) =>
                    ProductCard(product: _products[index]),
              ),
      ),
    );
  }
}
