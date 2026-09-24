import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/referral.dart';
import '../screens/apply_referral_screen.dart';
import '../screens/referral_screen.dart';
import '../state/referral_state.dart';
import '../theme/app_theme.dart';
import 'referral_widgets.dart';

/// "Refer & Earn" on the Profile screen: QR of the referral link, the code
/// with Copy, Share, the points progress and the programme's rules — all
/// from `GET /referral` via [ReferralState]. Tapping it opens the full
/// Referral screen.
class ReferralCard extends StatefulWidget {
  const ReferralCard({super.key});

  @override
  State<ReferralCard> createState() => _ReferralCardState();
}

class _ReferralCardState extends State<ReferralCard> {
  @override
  void initState() {
    super.initState();
    final state = ReferralState.instance;
    if (state.info == null && !state.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => state.refresh());
    }
  }

  void _open() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReferralScreen()));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ReferralState.instance,
      builder: (context, _) {
        final state = ReferralState.instance;
        final info = state.info;
        return Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: info == null ? null : _open,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.line),
              ),
              child: info == null
                  ? _buildPlaceholder(context, state)
                  : _buildContent(context, info),
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.card_giftcard_rounded, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.referEarnTitle,
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppColors.inkStrong),
              ),
              Text(l10n.referEarnSubtitle, style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      ],
    );
  }

  Widget _buildPlaceholder(BuildContext context, ReferralState state) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context),
        const SizedBox(height: 16),
        if (state.isLoading || state.error == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          Center(
            child: TextButton.icon(
              onPressed: state.refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.retry),
            ),
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, ReferralInfo info) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context),
        const SizedBox(height: 16),
        if (info.enabled) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ReferralQr(data: info.link, size: 104),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.yourReferralCode, style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                    const SizedBox(height: 2),
                    ReferralCodeRow(code: info.code, fontSize: 21, compact: true),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => shareReferral(context, info),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: Text(l10n.share),
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: AppColors.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.referralUnavailable, style: TextStyle(fontSize: 13, color: AppColors.body)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        // The balance stays visible even while the programme is paused.
        PointsProgress(stats: info.stats, rules: info.rules),
        if (info.enabled && info.rules.rewardPoints > 0) ...[
          const SizedBox(height: 10),
          Text(
            l10n.earnRule(formatPoints(context, info.rules.rewardPoints)),
            style: TextStyle(fontSize: 12.5, color: AppColors.body, height: 1.35),
          ),
        ],
        if (info.referredByName != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.favorite_rounded, size: 14, color: AppColors.sale),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.invitedByLong(info.referredByName!),
                  style: TextStyle(fontSize: 12.5, color: AppColors.body),
                ),
              ),
            ],
          ),
        ],
        if (info.enabled && info.canApplyCode)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ApplyReferralScreen()),
              ),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              child: Text(l10n.haveReferralCode),
            ),
          ),
      ],
    );
  }
}
