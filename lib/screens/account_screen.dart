import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_config.dart';
import '../core/api_exception.dart';
import '../core/money.dart';
import '../models/user.dart';
import '../services/content_service.dart';
import '../services/order_service.dart';
import '../l10n/app_localizations.dart';
import '../state/auth_state.dart';
import '../state/locale_state.dart';
import '../state/referral_state.dart';
import '../state/theme_state.dart';
import '../theme/app_theme.dart';
import '../widgets/referral_card.dart';
import 'addresses_screen.dart';
import 'blog_list_screen.dart';
import 'contact_screen.dart';
import 'coupons_screen.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'order_detail_screen.dart';
import 'order_tracking_screen.dart';
import 'orders_screen.dart';
import 'shop_by_category_screen.dart';
import 'static_page_screen.dart';
import 'wishlist_screen.dart';

/// Profile tab laid out like the storefront mock: dotted header panel with a
/// ringed avatar, name + handle, a gradient promo banner, then bordered menu
/// tiles with a small ↗ action, legal links, logout, recent orders and the
/// store's social links. It is also the app's menu — everything the old
/// side drawer offered lives here.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

enum _ProfileMenuAction { editProfile, notifications, logout }

class _AccountScreenState extends State<AccountScreen> {
  bool _isLoadingOrders = true;
  bool _uploadingPhoto = false;
  final _picker = ImagePicker();
  List<Map> _recentOrders = [];

  /// `social_links` from `/footer` — `[{label, url}]`.
  List<Map> _socialLinks = [];

  @override
  void initState() {
    super.initState();
    if (AuthState.instance.isAuthenticated) _loadOrders();
    _loadSocialLinks();
  }

  Future<void> _loadSocialLinks() async {
    try {
      final response = await ContentService.instance.footer();
      final data = (response is Map ? response['data'] ?? response : {}) as Map;
      final links = ((data['social_links'] as List?) ?? [])
          .whereType<Map>()
          .where((link) => (link['url'] as String?)?.isNotEmpty == true)
          .toList();
      if (mounted) setState(() => _socialLinks = links);
    } catch (_) {
      // The "Follow us" row just stays hidden.
    }
  }

  Future<void> _openUrl(String? url) async {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the link.')));
    }
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoadingOrders = true);
    try {
      final response = await OrderService.instance.myOrders();
      final data = (response is Map ? response['data'] ?? response : {}) as Map;
      final orders = ((data['orders'] as List?) ?? []).map((e) => e as Map).toList();
      _recentOrders = orders.take(3).toList();
    } catch (_) {
      // Recent orders are a secondary section on the account page.
    } finally {
      if (mounted) setState(() => _isLoadingOrders = false);
    }
  }

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  void _openPage(String slug, String title) =>
      _push(StaticPageScreen(slug: slug, fallbackTitle: title));

  /// Camera / gallery chooser, then upload. Picks are downscaled to 1024px
  /// so a 12-megapixel shot does not become a multi-megabyte avatar.
  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Profile photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.inkStrong)),
              ),
            ),
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: AppColors.inkStrong),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: AppColors.inkStrong),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final XFile? picked;
    try {
      picked = await _picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 88);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the ${source == ImageSource.camera ? "camera" : "gallery"}.')),
        );
      }
      return;
    }
    if (picked == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      await AuthState.instance.updateProfilePhoto(picked.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not upload the photo. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can sign back in at any time.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out', style: TextStyle(color: Color(0xFFE0796B))),
          ),
        ],
      ),
    );
    if (confirmed == true) await AuthState.instance.logout();
  }

  String _modeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  String _languageLabel(BuildContext context, Locale? locale) {
    final l10n = AppLocalizations.of(context);
    return switch (locale?.languageCode) {
      'en' => l10n.languageEnglish,
      'bn' => l10n.languageBangla,
      _ => l10n.languageSystem,
    };
  }

  Future<void> _openLanguageSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final options = <String, Locale?>{
      l10n.languageSystem: null,
      l10n.languageEnglish: const Locale('en'),
      l10n.languageBangla: const Locale('bn'),
    };
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.language,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.inkStrong),
                ),
              ),
            ),
            for (final entry in options.entries)
              ListTile(
                title: Text(entry.key),
                trailing: LocaleState.instance.locale?.languageCode == entry.value?.languageCode
                    ? Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  LocaleState.instance.setLocale(entry.value);
                  Navigator.of(sheetContext).pop();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _openAppearanceSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ListenableBuilder(
          listenable: ThemeState.instance,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Appearance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.inkStrong)),
                ),
              ),
              for (final option in const [ThemeMode.system, ThemeMode.light, ThemeMode.dark])
                RadioListTile<ThemeMode>(
                  value: option,
                  // ignore: deprecated_member_use
                  groupValue: ThemeState.instance.mode,
                  // ignore: deprecated_member_use
                  onChanged: (value) {
                    if (value != null) ThemeState.instance.setMode(value);
                  },
                  activeColor: AppColors.accent,
                  title: Text(_modeLabel(option)),
                  subtitle: option == ThemeMode.system ? const Text('Match device setting') : null,
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Profile'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ListenableBuilder(
              listenable: AuthState.instance,
              builder: (context, _) => _RoundMenuButton(
                isAuthenticated: AuthState.instance.isAuthenticated,
                onSelected: (action) {
                  switch (action) {
                    case _ProfileMenuAction.editProfile:
                      _push(const EditProfileScreen());
                    case _ProfileMenuAction.notifications:
                      _push(const NotificationsScreen());
                    case _ProfileMenuAction.logout:
                      _confirmLogout();
                  }
                },
              ),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: AuthState.instance,
        builder: (context, _) {
          final auth = AuthState.instance;
          final user = auth.isAuthenticated ? auth.user : null;

          return RefreshIndicator(
            // Re-fetches orders and the referral card together.
            onRefresh: user == null
                ? () async {}
                : () async {
                    await Future.wait([_loadOrders(), ReferralState.instance.refresh()]);
                  },
            child: ListView(
              // AlwaysScrollable so pull-to-refresh works even when the
              // signed-out menu fits on screen; the bottom inset clears
              // MainShell's floating nav, which otherwise hides the last rows.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 4, 20, 32 + MediaQuery.paddingOf(context).bottom),
              children: [
                _ProfileHeader(
                  user: user,
                  onSignIn: () => _push(const LoginScreen()),
                  onChangePhoto: _changePhoto,
                  uploadingPhoto: _uploadingPhoto,
                ),
                const SizedBox(height: 18),
                _PromoBanner(
                  icon: Icons.local_offer_rounded,
                  title: 'Coupons & Offers',
                  subtitle: 'Explore deals and save on your next order',
                  onTap: () => _push(const CouponsScreen()),
                ),
                if (user != null) ...[
                  const SizedBox(height: 18),
                  const ReferralCard(),
                ],
                const SizedBox(height: 18),
                _MenuCard(
                  tiles: [
                    if (user != null) ...[
                      _MenuTile(icon: Icons.person_outline_rounded, label: 'Edit Profile', onTap: () => _push(const EditProfileScreen())),
                      _MenuTile(icon: Icons.receipt_long_outlined, label: 'My Orders', onTap: () => _push(const OrdersScreen())),
                      _MenuTile(icon: Icons.location_on_outlined, label: 'Shipping Addresses', onTap: () => _push(const AddressesScreen())),
                      _MenuTile(icon: Icons.favorite_border_rounded, label: 'Wishlist', onTap: () => _push(const WishlistScreen())),
                    ],
                    _MenuTile(icon: Icons.grid_view_rounded, label: 'Categories', onTap: () => _push(const ShopByCategoryScreen())),
                    _MenuTile(icon: Icons.local_shipping_outlined, label: 'Track an Order', onTap: () => _push(const OrderTrackingScreen())),
                    _MenuTile(icon: Icons.support_agent_outlined, label: 'Help & Support', onTap: () => _push(const ContactScreen())),
                    _MenuTile(icon: Icons.article_outlined, label: 'Blog', onTap: () => _push(const BlogListScreen())),
                    ListenableBuilder(
                      listenable: ThemeState.instance,
                      builder: (context, _) => _MenuTile(
                        icon: Icons.dark_mode_outlined,
                        label: 'Appearance',
                        trailingText: _modeLabel(ThemeState.instance.mode),
                        onTap: () => _openAppearanceSheet(context),
                      ),
                    ),
                    ListenableBuilder(
                      listenable: LocaleState.instance,
                      builder: (context, _) => _MenuTile(
                        icon: Icons.translate_rounded,
                        label: AppLocalizations.of(context).language,
                        trailingText: _languageLabel(context, LocaleState.instance.locale),
                        onTap: () => _openLanguageSheet(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _MenuCard(
                  tiles: [
                    _MenuTile(icon: Icons.info_outline_rounded, label: 'About Us', onTap: () => _openPage('about-us', 'About Us')),
                    _MenuTile(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy', onTap: () => _openPage('privacy-policy', 'Privacy Policy')),
                    _MenuTile(icon: Icons.description_outlined, label: 'Terms & Conditions', onTap: () => _openPage('terms-and-conditions', 'Terms & Conditions')),
                  ],
                ),
                if (user != null) ...[
                  const SizedBox(height: 14),
                  _MenuCard(
                    tiles: [
                      _MenuTile(icon: Icons.logout_rounded, label: 'Logout', danger: true, onTap: _confirmLogout),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Text(
                        'Recent Orders',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.inkStrong),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _push(const OrdersScreen()),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), visualDensity: VisualDensity.compact),
                        child: const Text('See all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingOrders)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (_recentOrders.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('No orders yet.', style: TextStyle(color: AppColors.muted)),
                    )
                  else
                    ..._recentOrders.map((order) => _RecentOrderCard(order: order)),
                ],
                if (_socialLinks.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text(
                    'Follow us',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.inkStrong),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final link in _socialLinks)
                        _SocialButton(
                          label: (link['label'] as String?) ?? '',
                          onTap: () => _openUrl(link['url'] as String?),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Round button for one of the store's social profiles, iconed by its label.
class _SocialButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SocialButton({required this.label, required this.onTap});

  static const _icons = <String, IconData>{
    'facebook': Icons.facebook,
    'instagram': Icons.camera_alt_outlined,
    'youtube': Icons.play_circle_outline,
    'twitter': Icons.alternate_email,
    'x': Icons.alternate_email,
    'linkedin': Icons.business_center_outlined,
    'tiktok': Icons.music_note_outlined,
    'whatsapp': Icons.chat_bubble_outline,
  };

  IconData get _icon {
    final lower = label.toLowerCase();
    for (final entry in _icons.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return Icons.link;
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: AppColors.card,
        shape: CircleBorder(side: BorderSide(color: AppColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(_icon, size: 20, color: AppColors.inkStrong),
          ),
        ),
      ),
    );
  }
}

/// Circular ⋮ button opening the profile actions menu.
class _RoundMenuButton extends StatelessWidget {
  final bool isAuthenticated;
  final ValueChanged<_ProfileMenuAction> onSelected;
  const _RoundMenuButton({required this.isAuthenticated, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ProfileMenuAction>(
      onSelected: onSelected,
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: AppColors.card,
      itemBuilder: (context) => [
        if (isAuthenticated)
          const PopupMenuItem(value: _ProfileMenuAction.editProfile, child: Text('Edit profile')),
        const PopupMenuItem(value: _ProfileMenuAction.notifications, child: Text('Notifications')),
        if (isAuthenticated)
          const PopupMenuItem(
            value: _ProfileMenuAction.logout,
            child: Text('Log out', style: TextStyle(color: Color(0xFFE0796B))),
          ),
      ],
      child: Material(
        color: AppColors.card,
        shape: CircleBorder(side: BorderSide(color: AppColors.line)),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.more_vert_rounded, size: 21, color: AppColors.inkStrong),
        ),
      ),
    );
  }
}

/// Dotted panel with a ringed avatar, then name + handle. Signed-out users
/// get a placeholder avatar and a Sign In button instead.
class _ProfileHeader extends StatelessWidget {
  final AppUser? user;
  final VoidCallback onSignIn;
  final VoidCallback? onChangePhoto;
  final bool uploadingPhoto;
  const _ProfileHeader({
    required this.user,
    required this.onSignIn,
    this.onChangePhoto,
    this.uploadingPhoto = false,
  });

  @override
  Widget build(BuildContext context) {
    final user = this.user;
    final handle = user?.email ?? user?.phone;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: ColoredBox(
            color: AppColors.card,
            child: CustomPaint(
              painter: _DotGridPainter(color: AppColors.inkStrong.withValues(alpha: 0.10)),
              child: SizedBox(
                height: 190,
                width: double.infinity,
                child: Center(
                  child: _Avatar(
                    user: user,
                    uploading: uploadingPhoto,
                    onChangePhoto: user == null ? null : onChangePhoto,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user?.name?.trim().isNotEmpty == true ? user!.name!.trim() : (user == null ? 'Welcome' : 'Your account'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: AppColors.inkStrong),
        ),
        const SizedBox(height: 4),
        if (user == null)
          Text('Sign in to manage orders, addresses and more.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.muted))
        else if (handle != null && handle.isNotEmpty)
          Text(handle, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: AppColors.muted)),
        if (user == null) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: 160,
            child: ElevatedButton(
              onPressed: onSignIn,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 46)),
              child: const Text('Sign In'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Ringed avatar with a small camera badge (bottom-right) that opens the
/// photo picker; the whole avatar dims behind a spinner while uploading.
class _Avatar extends StatelessWidget {
  final AppUser? user;
  final bool uploading;
  final VoidCallback? onChangePhoto;
  const _Avatar({required this.user, this.uploading = false, this.onChangePhoto});

  @override
  Widget build(BuildContext context) {
    final url = user?.avatarUrl;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: uploading ? null : onChangePhoto,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2.5),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: ClipOval(
              child: SizedBox(
                width: 104,
                height: 104,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (url != null && url.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => _Initials(user: user),
                        errorWidget: (_, _, _) => _Initials(user: user),
                      )
                    else
                      _Initials(user: user),
                    if (uploading)
                      ColoredBox(
                        color: Colors.black.withValues(alpha: 0.45),
                        child: const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (onChangePhoto != null)
          Positioned(
            right: -2,
            bottom: -2,
            child: Material(
              color: AppColors.primary,
              shape: CircleBorder(side: BorderSide(color: AppColors.card, width: 3)),
              clipBehavior: Clip.antiAlias,
              elevation: 2,
              child: InkWell(
                onTap: uploading ? null : onChangePhoto,
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(Icons.photo_camera_rounded, size: 17, color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Initials extends StatelessWidget {
  final AppUser? user;
  const _Initials({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.accentSoft,
      alignment: Alignment.center,
      child: user == null
          ? Icon(Icons.person_rounded, size: 52, color: AppColors.primaryLight)
          : Text(
              user!.initials,
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.primaryLight),
            ),
    );
  }
}

/// Subtle grid of dots behind the avatar.
class _DotGridPainter extends CustomPainter {
  final Color color;
  const _DotGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const step = 14.0;
    for (double y = step / 2; y < size.height; y += step) {
      for (double x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) => oldDelegate.color != color;
}

/// Gradient call-to-action card: icon bubble, title/subtitle, ↗ button.
class _PromoBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _PromoBanner({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryLight, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.arrow_outward_rounded, color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// White card holding a stack of bordered [_MenuTile] rows.
class _MenuCard extends StatelessWidget {
  final List<Widget> tiles;
  const _MenuCard({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            tiles[i],
          ],
        ],
      ),
    );
  }
}

/// One bordered row: icon in a soft square, label, optional value, ↗ bubble.
class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailingText;
  final bool danger;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailingText,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    const dangerColor = Color(0xFFE0796B);
    final fg = danger ? dangerColor : AppColors.inkStrong;
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: danger ? dangerColor.withValues(alpha: 0.35) : AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: danger ? dangerColor.withValues(alpha: 0.10) : AppColors.background,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: danger ? dangerColor : AppColors.bodyStrong),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: fg),
                ),
              ),
              if (trailingText != null) ...[
                Text(trailingText!, style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                const SizedBox(width: 10),
              ],
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: danger ? dangerColor.withValues(alpha: 0.5) : AppColors.lineStrong),
                ),
                child: Icon(Icons.arrow_outward_rounded, size: 14, color: danger ? dangerColor : AppColors.bodyStrong),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentOrderCard extends StatelessWidget {
  final Map order;
  const _RecentOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final id = order['id'] as int;
    final code = order['order_code'] as String? ?? 'Order #$id';
    final status = order['current_status'] as String? ?? '';
    final total = (order['total_amount'] as num?)?.toDouble() ?? 0;
    final items = (order['items'] as List?) ?? [];
    // The orders list endpoint only sends `total_items`; `items` (with the
    // first product's title/image) is present on the detail payload, so
    // fall back to a count-only row when it is missing.
    final firstItem = items.isNotEmpty ? items.first as Map : null;
    final totalItems = (order['total_items'] as num?)?.toInt() ?? items.length;
    final title = firstItem?['product_title'] as String? ?? '$totalItems item${totalItems == 1 ? '' : 's'}';
    final image = ApiConfig.resolveUrl(firstItem?['product_image'] as String?);
    final qty = (firstItem?['quantity'] as num?)?.toInt();
    final delivered = status.toLowerCase() == 'delivered';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ORDER #$code',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(fontSize: 11, color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: image != null && image.isNotEmpty
                      ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover)
                      : Container(
                          color: AppColors.background,
                          child: Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.muted),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.inkStrong)),
                    const SizedBox(height: 2),
                    Text(
                      qty != null ? 'Qty: $qty' : 'Tap to see what\x27s inside',
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Text(formatPrice(total), style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: id)),
            ),
            child: Text(delivered ? 'Buy Again' : 'View Details'),
          ),
        ],
      ),
    );
  }
}
