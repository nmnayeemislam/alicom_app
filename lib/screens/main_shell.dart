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
    final items = [
      ('Home', Icons.home_outlined, Icons.home_rounded),
      ('Categories', Icons.grid_view_outlined, Icons.grid_view_rounded),
      ('Wishlist', Icons.favorite_border, Icons.favorite_rounded),
      ('Orders', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
      ('Profile', Icons.person_outline, Icons.person_rounded),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.line, width: 1)),
        ),
        padding: const EdgeInsets.only(top: 10, bottom: 22),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final (label, outline, filled) = items[i];
            final active = _index == i;
            return InkWell(
              onTap: () => setState(() => _index = i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(active ? filled : outline, size: 22, color: active ? AppColors.primary : AppColors.muted),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? AppColors.primary : AppColors.muted,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
