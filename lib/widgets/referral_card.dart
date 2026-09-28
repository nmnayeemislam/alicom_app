import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/referral.dart';
import '../screens/apply_referral_screen.dart';
import '../screens/referral_screen.dart';
import '../state/referral_state.dart';
import '../theme/app_theme.dart';
import 'app_loader.dart';
import 'referral_widgets.dart';

/// "Refer & Earn" on the Profile screen: QR of the referral link, the code
/// with Copy, Share, the points progress and the programme's rules — all
/// from `GET /referral` via [ReferralState]. Tapping it opens the full
/// Referral screen.
///
/// Laid out as a reward card: everything the customer hands to a friend
/// (QR, code, Share) sits on the accent header, everything they earn back
/// (balance, progress, tallies) on the plain body below it.
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
            child: DecoratedBox(
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

  // --- HEADER ----------------------------------------------------------

  /// The accent band. [compact] drops the share block, for the states where
  /// there is no code to hand out (loading, error, programme paused).
  Widget _header(BuildContext context, {ReferralInfo? info}) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Same soft light circle the auth hero uses, for a little depth.
          Positioned(
            top: -48,
            right: -32,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.referEarnTitle,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          l10n.referEarnSubtitle,
                          style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.85)),
                ],
              ),
              if (info != null) ...[
                const SizedBox(height: 16),
                _shareBlock(context, info),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// QR beside the code and the Share button — the three ways to pass the
  /// invite on, grouped together on the accent.
  Widget _shareBlock(BuildContext context, ReferralInfo info) {
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ReferralQr(data: info.link, size: 92),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.yourReferralCode.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 7),
              _codeChip(context, info.code),
              const SizedBox(height: 9),
              SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  onPressed: () => shareReferral(context, info),
                  icon: const Icon(Icons.ios_share_rounded, size: 17),
                  label: Text(l10n.share),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryDark,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The code itself, as a tap-to-copy tile — the copy icon is a hint, the
  /// whole chip is the target.
  Widget _codeChip(BuildContext context, String code) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => copyToClipboard(context, code),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    code,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.copy_rounded, size: 16, color: Colors.white.withValues(alpha: 0.9)),
            ],
          ),
        ),
      ),
    );
  }

  // --- BODY ------------------------------------------------------------

  Widget _buildPlaceholder(BuildContext context, ReferralState state) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Center(
            child: state.isLoading || state.error == null
                ? AppLoader(size: 46)
                : TextButton.icon(
                    onPressed: state.refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(l10n.retry),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, ReferralInfo info) {
    final l10n = AppLocalizations.of(context);
    final stats = info.stats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, info: info.enabled ? info : null),
        const _Perforation(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!info.enabled) ...[
                _noticeRow(Icons.info_outline_rounded, l10n.referralUnavailable, AppColors.muted),
                const SizedBox(height: 14),
              ],
              // The balance stays visible even while the programme is paused.
              PointsProgress(stats: stats, rules: info.rules),
              if (stats.totalReferred > 0) ...[
                const SizedBox(height: 14),
                _statsStrip(context, stats),
              ] else if (info.enabled && info.rules.rewardPoints > 0) ...[
                const SizedBox(height: 12),
                _noticeRow(
                  Icons.auto_awesome_rounded,
                  l10n.earnRule(formatPoints(context, info.rules.rewardPoints)),
                  AppColors.primary,
                ),
              ],
              if (info.referredByName != null) ...[
                const SizedBox(height: 10),
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
              if (info.enabled && info.canApplyCode) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ApplyReferralScreen()),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(l10n.haveReferralCode),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// What the referrals have added up to so far, as three small tallies.
  Widget _statsStrip(BuildContext context, ReferralStats stats) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _stat(context, formatPoints(context, stats.totalReferred), l10n.statTotalReferred),
          _divider(),
          _stat(context, formatPoints(context, stats.rewarded), l10n.statRewarded),
          _divider(),
          _stat(context, formatPoints(context, stats.pointsEarned), l10n.statPointsEarned),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.inkStrong),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 26, color: AppColors.line);

  Widget _noticeRow(IconData icon, String text, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12.5, color: AppColors.body, height: 1.35),
          ),
        ),
      ],
    );
  }
}

/// The voucher-style cut between the accent header and the body: a notch
/// punched out of each edge with a dashed line between them, so the card
/// reads as something you tear off and hand over.
class _Perforation extends StatelessWidget {
  const _Perforation();

  static const double _height = 26;
  static const double _notch = 16;

  @override
  Widget build(BuildContext context) {
    final background = AppColors.background;
    return SizedBox(
      height: _height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(color: AppColors.card),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: CustomPaint(
              size: const Size(double.infinity, 1),
              painter: _DashedLinePainter(color: AppColors.lineStrong),
            ),
          ),
          Positioned(
            left: -_notch / 2,
            child: _dot(background),
          ),
          Positioned(
            right: -_notch / 2,
            child: _dot(background),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: _notch,
        height: _notch,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const dash = 5.0;
    const gap = 5.0;
    for (double x = 0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + dash).clamp(0, size.width), size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) => oldDelegate.color != color;
}
