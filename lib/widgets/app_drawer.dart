import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/account_screen.dart';
import '../screens/blog_list_screen.dart';
import '../screens/contact_screen.dart';
import '../screens/coupons_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell.dart';
import '../screens/order_tracking_screen.dart';
import '../screens/products_screen.dart';
import '../screens/static_page_screen.dart';
import '../screens/wishlist_screen.dart';
import '../services/content_service.dart';
import '../state/auth_state.dart';
import '../theme/app_theme.dart';

const _socialIcons = <String, IconData>{
  'facebook': Icons.facebook,
  'instagram': Icons.camera_alt_outlined,
  'youtube': Icons.play_circle_outline,
  'twitter': Icons.alternate_email,
  'x': Icons.alternate_email,
  'linkedin': Icons.business_center_outlined,
  'tiktok': Icons.music_note_outlined,
  'whatsapp': Icons.chat_bubble_outline,
};

IconData _socialIcon(String label) {
  final lower = label.toLowerCase();
  for (final entry in _socialIcons.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return Icons.link;
}

/// App-wide navigation menu opened from the home screen's hamburger icon.
/// Loads `/footer` for the social links row so those aren't dead weight in
/// the backend — everything else routes to screens that already exist.
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  List<Map> _socialLinks = [];

  @override
  void initState() {
    super.initState();
    _loadFooter();
  }

  Future<void> _loadFooter() async {
    try {
      final response = await ContentService.instance.footer();
      final data = (response is Map ? response['data'] ?? response : {}) as Map;
      final links = ((data['social_links'] as List?) ?? []).map((e) => e as Map).toList();
      if (mounted) setState(() => _socialLinks = links);
    } catch (_) {
      // The menu still works without the social row.
    }
  }

  void _navigate(Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _goHome() {
    Navigator.of(context).pop();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthState.instance,
      builder: (context, _) {
        final auth = AuthState.instance;
        return Drawer(
          backgroundColor: AppColors.background,
          child: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.accentSoft,
                        child: Icon(
                          auth.isAuthenticated ? Icons.person : Icons.person_outline,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.isAuthenticated ? (auth.user?.name ?? 'Account') : 'Welcome',
                              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.inkStrong, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            InkWell(
                              onTap: () => auth.isAuthenticated
                                  ? _navigate(const AccountScreen())
                                  : _navigate(const LoginScreen()),
                              child: Text(
                                auth.isAuthenticated ? 'View profile' : 'Sign in',
                                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),
                _tile(Icons.home_outlined, 'Home', _goHome),
                _tile(Icons.grid_view_outlined, 'Categories', () => _navigate(const ProductsScreen())),
                _tile(Icons.favorite_border, 'Wishlist', () => _navigate(const WishlistScreen())),
                _tile(Icons.local_offer_outlined, 'Coupons & Offers', () => _navigate(const CouponsScreen())),
                _tile(Icons.article_outlined, 'Blog', () => _navigate(const BlogListScreen())),
                _tile(Icons.local_shipping_outlined, 'Track an Order', () => _navigate(const OrderTrackingScreen())),
                const Divider(height: 24),
                _tile(Icons.info_outline, 'About Us', () => _navigate(const StaticPageScreen(slug: 'about-us', fallbackTitle: 'About Us'))),
                _tile(Icons.support_agent_outlined, 'Contact Us', () => _navigate(const ContactScreen())),
                _tile(Icons.privacy_tip_outlined, 'Privacy Policy', () => _navigate(const StaticPageScreen(slug: 'privacy-policy', fallbackTitle: 'Privacy Policy'))),
                _tile(Icons.description_outlined, 'Terms & Conditions', () => _navigate(const StaticPageScreen(slug: 'terms-and-conditions', fallbackTitle: 'Terms & Conditions'))),
                if (auth.isAuthenticated) ...[
                  const Divider(height: 24),
                  _tile(Icons.logout, 'Logout', () async {
                    Navigator.of(context).pop();
                    await auth.logout();
                  }, danger: true),
                ],
                if (_socialLinks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Row(
                      children: [
                        for (final link in _socialLinks)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: InkWell(
                              onTap: () => _openUrl(link['url'] as String?),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(color: AppColors.card, shape: BoxShape.circle, border: Border.all(color: AppColors.line)),
                                child: Icon(_socialIcon(link['label'] as String? ?? ''), size: 18, color: AppColors.body),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ] else
                  const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _tile(IconData icon, String label, VoidCallback onTap, {bool danger = false}) {
    final color = danger ? const Color(0xFFE0796B) : AppColors.ink;
    return ListTile(
      leading: Icon(icon, size: 20, color: color),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}
