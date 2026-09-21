import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/wishlist_service.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';
import '../widgets/product_grid_card.dart';
import '../widgets/state_views.dart';
import 'login_screen.dart';

/// Saved products, in the same two-column [ProductGridCard] grid as Home
/// and Products. Un-hearting a card removes it from the grid immediately.
class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  bool _isLoading = true;
  String? _error;
  List<Product> _products = [];
  // Which account the current list belongs to, so a sign-in/out while this
  // tab stays alive in the shell reloads instead of showing stale items.
  int? _loadedForUserId;

  @override
  void initState() {
    super.initState();
    AuthState.instance.addListener(_onAuthChanged);
    if (AuthState.instance.isAuthenticated) _load();
  }

  @override
  void dispose() {
    AuthState.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final auth = AuthState.instance;
    if (auth.isAuthenticated && auth.user?.id != _loadedForUserId) {
      _load();
    } else if (!auth.isAuthenticated) {
      setState(() {
        _products = [];
        _loadedForUserId = null;
      });
    }
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
      _loadedForUserId = AuthState.instance.user?.id;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final appBar = AppBar(
      title: const Text('Wishlist'),
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: canPop
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
    );

    return ListenableBuilder(
      listenable: AuthState.instance,
      builder: (context, _) {
        if (!AuthState.instance.isAuthenticated) {
          return Scaffold(
            appBar: appBar,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border_rounded, size: 48, color: AppColors.muted),
                    const SizedBox(height: 12),
                    Text(
                      'Sign in to view your wishlist.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.body),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 160,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        ),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 46)),
                        child: const Text('Sign In'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: appBar,
          body: RefreshIndicator(
            onRefresh: _load,
            child: _isLoading
                ? const LoadingView()
                : _error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : _products.isEmpty
                ? const EmptyView(
                    icon: Icons.favorite_border_rounded,
                    message: 'Your wishlist is empty.',
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _products.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.68,
                    ),
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      return ProductGridCard(
                        key: ValueKey(product.id ?? product.slug),
                        product: product,
                        onWishlistChanged: (wishlisted) {
                          if (!wishlisted && mounted) {
                            setState(() => _products.removeWhere((p) => p.id == product.id));
                          }
                        },
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}
