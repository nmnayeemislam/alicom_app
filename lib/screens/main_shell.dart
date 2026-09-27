import 'package:flutter/material.dart';

import '../core/deep_links.dart';
import '../core/push_notifications.dart';
import '../state/auth_state.dart';
import '../state/cart_state.dart';
import '../state/notification_state.dart';
import '../theme/app_theme.dart';
import 'account_screen.dart';
import 'cart_screen.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'wishlist_screen.dart';

/// Bottom nav: Home / Wishlist / Orders / Profile around a raised cart
/// button in the middle — the cart is what a shopper reaches for most, so
/// it gets the one control that is always in the same place.
///
/// Categories are not a tab: Home's "Categories → See All" and Profile →
/// Categories both open [ShopByCategoryScreen].
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// Index of the Profile tab in the bottom nav.
  static const profileTab = 3;

  /// Switches the bottom-nav tab from inside one of the tab screens (e.g.
  /// Home's avatar → Profile). No-op outside the shell.
  static void selectTab(BuildContext context, int index) =>
      context.findAncestorStateOfType<_MainShellState>()?._select(index);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _select(int index) {
    if (index != _index) setState(() => _index = index);
  }

  @override
  void initState() {
    super.initState();
    // A /ref/{CODE} link that opened the app is acted on now that the
    // shell (and its navigator) is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinks.instance.markShellReady();
      // A tapped notification routes from here, over the shell.
      PushNotifications.instance.markShellReady();
      // Only for a session restored from storage — a guest is asked once
      // they sign in (PushNotifications listens to AuthState), so the
      // prompt never lands on someone with no orders to be told about.
      if (AuthState.instance.isAuthenticated) {
        PushNotifications.instance.requestPermissionAndRegister();
        NotificationState.instance.refresh();
      }
    });
  }

  final _screens = const [
    HomeScreen(),
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

  /// Floating rounded bar with the raised circular cart button in the
  /// middle.
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
                  // The outer slots are narrower than the inner ones, so
                  // the end icons sit closer to the bar's edges instead of
                  // leaving half an empty slot at each end.
                  _navItem(0, Icons.home_outlined, Icons.home_rounded, flex: 3),
                  _navItem(1, Icons.favorite_border, Icons.favorite_rounded, flex: 4),
                  const Expanded(flex: 6, child: SizedBox()),
                  _navItem(2, Icons.inventory_2_outlined, Icons.inventory_2_rounded, flex: 4),
                  _navItem(3, Icons.person_outline, Icons.person_rounded, flex: 3),
                ],
              ),
            ),
            // Raised centre button — the cart. It opens over the current
            // tab rather than replacing it, so a shopper lands back where
            // they were browsing when they close it.
            Positioned(
              top: 0,
              child: ListenableBuilder(
                listenable: CartState.instance,
                builder: (context, _) => _cartButton(context, CartState.instance.totalItems),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartButton(BuildContext context, int count) {
    return SizedBox(
      width: 56,
      height: 62,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: AppColors.primary,
            // Soft brand ring rather than a background-coloured one, so the
            // button reads as a lit-up halo over the white bar.
            shape: CircleBorder(
              side: BorderSide(color: AppColors.primaryLight, width: 4),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CartScreen()),
              ),
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 24),
              ),
            ),
          ),
          if (count > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 19),
                decoration: BoxDecoration(
                  color: AppColors.sale,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.background, width: 2),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _navItem(int i, IconData outline, IconData filled, {int flex = 1}) {
    final active = _index == i;
    return Expanded(
      flex: flex,
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
