import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The small red count that sits on a corner of an icon button — unread
/// notifications, items in the cart. Anything past 99 reads "99+" so the
/// pill never grows wider than the button it sits on.
class CountBadge extends StatelessWidget {
  final int count;

  /// Colour drawn around the pill so it separates from whatever is behind
  /// it — the button's own surface, or the page.
  final Color borderColor;

  const CountBadge({super.key, required this.count, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.sale,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 1.8),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.45,
        ),
      ),
    );
  }
}
