import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'count_badge.dart';

/// The app bar every bottom-nav tab uses: centred title, no back arrow
/// unless the screen was pushed, and one round button in the right corner.
///
/// Home is the exception — its greeting header carries the avatar, search
/// and bell instead of a title.
class TabAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  /// The round corner button. Sized and inset here so every tab's button
  /// lands in exactly the same place.
  final Widget? action;

  const TabAppBar({super.key, required this.title, this.action});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return AppBar(
      title: Text(title),
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: canPop
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      actions: [
        if (action != null)
          Padding(padding: const EdgeInsets.only(right: 16), child: action!),
      ],
    );
  }
}

/// 44px circle on the card colour with a hairline edge — the shape shared
/// by every tab's corner button.
class RoundAppBarButton extends StatelessWidget {
  final IconData icon;

  /// Unread items to show in the corner; 0 draws no badge.
  final int count;
  final VoidCallback? onTap;

  const RoundAppBarButton({
    super.key,
    required this.icon,
    this.onTap,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppColors.card,
      shape: CircleBorder(side: BorderSide(color: AppColors.line)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 44,
        height: 44,
        child: onTap == null
            ? Icon(icon, size: 21, color: AppColors.inkStrong)
            : InkWell(
                onTap: onTap,
                child: Icon(icon, size: 21, color: AppColors.inkStrong),
              ),
      ),
    );
    if (count <= 0) return button;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          top: -2,
          right: -2,
          child: IgnorePointer(
            child: CountBadge(count: count, borderColor: AppColors.background),
          ),
        ),
      ],
    );
  }
}
