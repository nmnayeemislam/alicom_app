import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'account_screen.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'products_screen.dart';
import 'wishlist_screen.dart';

/// Mirrors the reference mock's bottom nav: Home / Categories / Wishlist /
/// Orders / Profile — the cart itself lives behind the home screen's
/// top-bar icon instead of a tab here.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    ProductsScreen(),
    WishlistScreen(),
    OrdersScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: _buildFloatingNav(context),
    );
  }

  /// Floating rounded bar with a raised circular Categories button in the
  /// middle, echoing the reference mock's "+" pill nav.
  Widget _buildFloatingNav(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SizedBox(
        height: 84,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.line),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 24, offset: const Offset(0, 8)),
                ],
              ),
              child: Row(
                children: [
                  _navItem(0, Icons.home_outlined, Icons.home_rounded),
                  _navItem(2, Icons.favorite_border, Icons.favorite_rounded),
                  const Expanded(child: SizedBox()),
                  _navItem(3, Icons.inventory_2_outlined, Icons.inventory_2_rounded),
                  _navItem(4, Icons.person_outline, Icons.person_rounded),
                ],
              ),
            ),
            // Raised center button — Categories.
            Positioned(
              top: 0,
              child: InkWell(
                onTap: () => setState(() => _index = 1),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _index == 1 ? AppColors.primaryDark : AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 4),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: const Icon(Icons.storefront_outlined, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData outline, IconData filled) {
    final active = _index == i;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _index = i),
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? filled : outline, size: 24, color: active ? AppColors.primary : AppColors.muted),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: active ? 5 : 0,
              height: 5,
              decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}
