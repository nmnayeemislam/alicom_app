import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/order_service.dart';
import '../state/auth_state.dart';
import '../state/theme_state.dart';
import '../theme/app_theme.dart';
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
import 'static_page_screen.dart';
import 'wishlist_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _isLoadingOrders = true;
  List<Map> _recentOrders = [];

  @override
  void initState() {
    super.initState();
    if (AuthState.instance.isAuthenticated) _loadOrders();
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

  Widget _appearanceTile(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeState.instance,
      builder: (context, _) => ListTile(
        leading: Icon(Icons.dark_mode_outlined, color: AppColors.inkStrong, size: 20),
        title: Text('Appearance', style: TextStyle(color: AppColors.inkStrong, fontWeight: FontWeight.w500)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_modeLabel(ThemeState.instance.mode), style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
          ],
        ),
        onTap: () => _openAppearanceSheet(context),
      ),
    );
  }

  List<Widget> _legalTiles(BuildContext context) {
    void openPage(String slug, String title) => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => StaticPageScreen(slug: slug, fallbackTitle: title)),
        );

    return [
      _AccountTile(
        icon: Icons.info_outline,
        label: 'About Us',
        onTap: () => openPage('about-us', 'About Us'),
      ),
      _AccountTile(
        icon: Icons.privacy_tip_outlined,
        label: 'Privacy Policy',
        onTap: () => openPage('privacy-policy', 'Privacy Policy'),
      ),
      _AccountTile(
        icon: Icons.description_outlined,
        label: 'Terms & Conditions',
        onTap: () => openPage('terms-and-conditions', 'Terms & Conditions'),
        isLast: true,
      ),
    ];
  }

  String _modeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

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
        title: const Text('ALICOM', style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: AuthState.instance,
        builder: (context, _) {
          final auth = AuthState.instance;
          if (!auth.isAuthenticated) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 40),
                Icon(Icons.person_outline, size: 48, color: AppColors.muted),
                const SizedBox(height: 12),
                const Center(child: Text('Sign in to view your account.')),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: const Text('Sign In'),
                  ),
                ),
                const Divider(height: 48),
                _SettingsCard(children: [
                  _appearanceTile(context),
                  _AccountTile(
                    icon: Icons.local_offer_outlined,
                    label: 'Coupons & Offers',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CouponsScreen()),
                    ),
                  ),
                  _AccountTile(
                    icon: Icons.article_outlined,
                    label: 'Blog',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BlogListScreen()),
                    ),
                  ),
                  _AccountTile(
                    icon: Icons.local_shipping_outlined,
                    label: 'Track an Order',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OrderTrackingScreen()),
                    ),
                  ),
                  _AccountTile(
                    icon: Icons.support_agent_outlined,
                    label: 'Contact Us',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ContactScreen()),
                    ),
                    isLast: true,
                  ),
                ]),
                const SizedBox(height: 16),
                _SettingsCard(children: _legalTiles(context)),
              ],
            );
          }

          final user = auth.user!;
          return RefreshIndicator(
            onRefresh: _loadOrders,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.accentSoft,
                        child: Text(
                          (user.name?.isNotEmpty == true ? user.name![0] : '?').toUpperCase(),
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(user.name ?? '', style: Theme.of(context).textTheme.titleLarge),
                      if (user.email != null) ...[
                        const SizedBox(height: 4),
                        Text(user.email!, style: TextStyle(color: AppColors.muted)),
                      ],
                      const SizedBox(height: 14),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                        ),
                        child: const Text('Edit Profile'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _SettingsCard(children: [
                  _appearanceTile(context),
                  _AccountTile(
                    icon: Icons.receipt_long_outlined,
                    label: 'My Orders',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OrdersScreen()),
                    ),
                  ),
                  _AccountTile(
                    icon: Icons.location_on_outlined,
                    label: 'Shipping Addresses',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddressesScreen()),
                    ),
                  ),
                  _AccountTile(
                    icon: Icons.favorite_border,
                    label: 'Wishlist',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WishlistScreen()),
                    ),
                  ),
                  _AccountTile(
                    icon: Icons.local_offer_outlined,
                    label: 'Coupons & Offers',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CouponsScreen()),
                    ),
                  ),
                  _AccountTile(
                    icon: Icons.article_outlined,
                    label: 'Blog',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BlogListScreen()),
                    ),
                  ),
                  _AccountTile(
                    icon: Icons.local_shipping_outlined,
                    label: 'Track an Order',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OrderTrackingScreen()),
                    ),
                  ),
                  _AccountTile(
                    icon: Icons.support_agent_outlined,
                    label: 'Contact Us',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ContactScreen()),
                    ),
                  ),
                  _AccountTile(
                    icon: Icons.logout,
                    label: 'Logout',
                    danger: true,
                    onTap: () => auth.logout(),
                    isLast: true,
                  ),
                ]),
                const SizedBox(height: 16),
                _SettingsCard(children: _legalTiles(context)),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.inkStrong),
                    const SizedBox(width: 8),
                    Text('Recent Orders', style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 14),
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
            ),
          );
        },
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(children: children),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final bool isLast;

  const _AccountTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFE0796B) : AppColors.inkStrong;
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: color, size: 20),
          title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          trailing: danger ? null : Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
          onTap: onTap,
        ),
        if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
      ],
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
    final firstItem = items.isNotEmpty ? items.first as Map : null;
    final title = firstItem?['product_title'] as String? ?? 'Order';
    final image = firstItem?['product_image'] as String?;
    final qty = (firstItem?['quantity'] as num?)?.toInt() ?? 1;
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
                      : Container(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('Qty: $qty', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              Text('\$${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
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
