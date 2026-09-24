import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/referral.dart';
import '../services/referral_service.dart';
import '../state/referral_state.dart';
import '../theme/app_theme.dart';
import '../widgets/redeem_button.dart';
import '../widgets/referral_widgets.dart';
import 'apply_referral_screen.dart';

/// Refer & Earn: Overview (code, QR, share, progress, stats), History
/// (paginated referrals with status filter) and Rewards (points balance,
/// redeem, personal coupons).
class ReferralScreen extends StatefulWidget {
  /// 0 Overview · 1 History · 2 Rewards
  final int initialTab;

  const ReferralScreen({super.key, this.initialTab = 0});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    await ReferralState.instance.refresh();
    if (mounted && ReferralState.instance.unauthorized) openLoginForExpiredSession(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab.clamp(0, 2),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(l10n.referEarnTitle),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.body,
            indicatorColor: AppColors.primary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: l10n.tabOverview),
              Tab(text: l10n.tabHistory),
              Tab(text: l10n.tabRewards),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(onRefresh: _refresh),
            const _HistoryTab(),
            _RewardsTab(onRefresh: _refresh),
          ],
        ),
      ),
    );
  }
}

/// Spinner / retry while the shared referral data is missing.
Widget _stateFallback(BuildContext context, ReferralState state, Future<void> Function() onRefresh) {
  if (state.isLoading || state.error == null) {
    return const Center(child: CircularProgressIndicator());
  }
  final l10n = AppLocalizations.of(context);
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            state.error!.isEmpty ? l10n.somethingWentWrong : state.error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.body),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRefresh, child: Text(l10n.retry)),
        ],
      ),
    ),
  );
}

// --- OVERVIEW ---------------------------------------------------------------

class _OverviewTab extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _OverviewTab({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: ReferralState.instance,
      builder: (context, _) {
        final state = ReferralState.instance;
        final info = state.info;
        if (info == null) return _stateFallback(context, state, onRefresh);
        final stats = info.stats;
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              if (info.enabled) ...[
                Center(child: ReferralQr(data: info.link, size: 200)),
                const SizedBox(height: 18),
                Text(l10n.yourReferralCode, textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 4),
                ReferralCodeRow(code: info.code, fontSize: 28),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => shareReferral(context, info),
                  icon: const Icon(Icons.share_rounded, size: 20),
                  label: Text(l10n.share),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                ),
                const SizedBox(height: 22),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
                  child: Text(l10n.referralUnavailable, style: TextStyle(color: AppColors.body)),
                ),
                const SizedBox(height: 18),
              ],
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.line),
                ),
                child: PointsProgress(stats: stats, rules: info.rules),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.9,
                children: [
                  _StatTile(label: l10n.statTotalReferred, value: formatPoints(context, stats.totalReferred), icon: Icons.group_rounded),
                  _StatTile(label: l10n.statPending, value: formatPoints(context, stats.pending), icon: Icons.hourglass_top_rounded),
                  _StatTile(label: l10n.statRewarded, value: formatPoints(context, stats.rewarded), icon: Icons.verified_rounded),
                  _StatTile(label: l10n.statPointsEarned, value: formatPoints(context, stats.pointsEarned), icon: Icons.stars_rounded),
                ],
              ),
              if (info.enabled && info.rules.rewardPoints > 0) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.earnRule(formatPoints(context, info.rules.rewardPoints)),
                  style: TextStyle(color: AppColors.body, height: 1.4),
                ),
              ],
              if (info.referredByName != null) ...[
                const SizedBox(height: 10),
                Text(l10n.invitedByLong(info.referredByName!), style: TextStyle(color: AppColors.body)),
              ],
              if (info.enabled && info.canApplyCode) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ApplyReferralScreen()),
                    ),
                    child: Text(l10n.haveReferralCode),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 19, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.inkStrong)),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- HISTORY ----------------------------------------------------------------

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> with AutomaticKeepAliveClientMixin {
  /// null = All
  String? _status;
  final List<ReferralHistoryItem> _items = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  /// Bumped on filter change / refresh so a late page for the old filter
  /// is dropped; together with [_loading] it also means a page is never
  /// requested twice at once.
  int _generation = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    _generation++;
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
      _loading = false;
    });
    await _loadNext();
  }

  Future<void> _loadNext() async {
    if (_loading || !_hasMore) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ReferralService.instance.history(page: _page + 1, status: _status);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _page += 1;
        _hasMore = page.pagination.hasMorePages;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = referralErrorMessage(context, e) ?? '');
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  void _setStatus(String? status) {
    if (status == _status) return;
    _status = status;
    _reload();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.extentAfter < 400 && _error == null) _loadNext();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final filters = <String?, String>{
      null: l10n.filterAll,
      'pending': l10n.filterPending,
      'rewarded': l10n.filterRewarded,
      'reversed': l10n.filterReversed,
    };
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            children: [
              for (final entry in filters.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: _status == entry.key,
                    onSelected: (_) => _setStatus(entry.key),
                    showCheckmark: false,
                    selectedColor: AppColors.primarySoft,
                    backgroundColor: AppColors.card,
                    side: BorderSide(color: _status == entry.key ? AppColors.primary : AppColors.line),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _status == entry.key ? AppColors.primaryDark : AppColors.body,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: _buildList(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_items.isEmpty) {
      Widget body;
      if (_loading) {
        body = const CircularProgressIndicator();
      } else if (_error != null) {
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!.isEmpty ? l10n.somethingWentWrong : _error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _reload, child: Text(l10n.retry)),
          ],
        );
      } else {
        body = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_add_outlined, size: 48, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(l10n.historyEmpty, textAlign: TextAlign.center, style: TextStyle(color: AppColors.body)),
          ],
        );
      }
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 260, child: Center(child: Padding(padding: const EdgeInsets.all(24), child: body))),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: _items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == _items.length) {
          if (_loading) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          if (_error != null) {
            return Center(child: TextButton(onPressed: _loadNext, child: Text(l10n.retry)));
          }
          return const SizedBox(height: 8);
        }
        return _HistoryRow(item: _items[i]);
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final ReferralHistoryItem item;
  const _HistoryRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, color) = switch (item.status) {
      'rewarded' => (l10n.statusRewardedPoints(formatPoints(context, item.rewardAmount)), const Color(0xFF1FA65A)),
      'reversed' => (l10n.statusReversed, AppColors.sale),
      'capped' => (l10n.statusCapped, const Color(0xFFD97706)),
      _ => (l10n.statusWaiting, AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primarySoft,
            child: Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Masked by the server ("Ra***") — shown exactly as sent.
                Text(item.referredName, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.inkStrong)),
                if (item.joinedAt != null)
                  Text(
                    l10n.joinedOn(formatShortDate(context, item.joinedAt!)),
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                if (item.rewardedAt != null)
                  Text(
                    l10n.rewardedOn(formatShortDate(context, item.rewardedAt!)),
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(label: label, color: color),
        ],
      ),
    );
  }
}

// --- REWARDS ----------------------------------------------------------------

class _RewardsTab extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _RewardsTab({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: ReferralState.instance,
      builder: (context, _) {
        final state = ReferralState.instance;
        final rewards = state.rewards;
        final info = state.info;
        if (rewards == null || info == null) return _stateFallback(context, state, onRefresh);
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.pointsBalance, style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
                    const SizedBox(height: 4),
                    Text(
                      l10n.pointsShort(formatPoints(context, rewards.pointsBalance)),
                      style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rewards.canRedeem
                          ? l10n.couponReadyToRedeem(formatPercent(context, info.rules.couponPercent))
                          : l10n.pointsToNextCoupon(
                              formatPoints(context, rewards.pointsToNextCoupon),
                              formatPercent(context, info.rules.couponPercent),
                            ),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              RedeemButton(
                threshold: rewards.redeemThreshold,
                canRedeem: rewards.canRedeem,
                rules: info.rules,
              ),
              const SizedBox(height: 26),
              Text(
                l10n.yourCoupons,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.inkStrong),
              ),
              const SizedBox(height: 10),
              if (rewards.coupons.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(l10n.couponsEmpty, style: TextStyle(color: AppColors.muted)),
                )
              else
                for (final coupon in rewards.coupons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CouponTile(coupon: coupon),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _CouponTile extends StatelessWidget {
  final RewardCoupon coupon;
  const _CouponTile({required this.coupon});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, color) = switch (coupon.status) {
      'used' => (l10n.couponStatusUsed, AppColors.muted),
      'expired' => (l10n.couponStatusExpired, AppColors.sale),
      _ => (l10n.couponStatusActive, const Color(0xFF1FA65A)),
    };
    return Opacity(
      opacity: coupon.isActive ? 1 : 0.65,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: coupon.isActive ? AppColors.primary.withValues(alpha: 0.35) : AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    coupon.code,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppColors.inkStrong,
                    ),
                  ),
                ),
                StatusBadge(label: label, color: color),
                IconButton(
                  tooltip: l10n.copy,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () => copyToClipboard(context, coupon.code),
                ),
              ],
            ),
            Text(couponSummary(context, coupon), style: TextStyle(fontSize: 13, color: AppColors.body)),
            if (coupon.expiresAt != null) ...[
              const SizedBox(height: 2),
              Text(
                l10n.couponExpires(formatShortDate(context, coupon.expiresAt!)),
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
            if (coupon.isActive) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: () => openCartWithCoupon(context, coupon.code),
                  child: Text(l10n.useNow),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
