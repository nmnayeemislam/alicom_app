import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../core/api_exception.dart';
import '../l10n/app_localizations.dart';
import '../models/referral.dart';
import '../screens/login_screen.dart';
import '../theme/app_theme.dart';

/// Pieces shared by the Profile referral card and the Referral screen.

/// Points as a plain grouped integer in the current language ("1,050",
/// Bangla digits in bn).
String formatPoints(BuildContext context, num points) =>
    NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(points);

/// A percentage from the API without a pointless ".0" ("10", "12.5"), in
/// the current language's digits.
String formatPercent(BuildContext context, num value) =>
    NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(value);

String formatShortDate(BuildContext context, DateTime date) => DateFormat.yMMMd(
  Localizations.localeOf(context).toLanguageTag(),
).format(date);

Future<void> copyToClipboard(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).copied)),
    );
}

Future<void> shareReferral(BuildContext context, ReferralInfo info) {
  final text = AppLocalizations.of(
    context,
  ).referralShareMessage(info.code, info.link);
  // Anchor for the iPad share popover.
  final box = context.findRenderObject() as RenderBox?;
  return SharePlus.instance.share(
    ShareParams(
      text: text,
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    ),
  );
}

/// Turns a failed referral call into what the user should see.
/// 401 → the login screen (returns null); 429 → the "wait a minute" line;
/// otherwise the server's message, or a generic fallback.
String? referralErrorMessage(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  if (error is ApiException) {
    if (error.statusCode == 401) {
      openLoginForExpiredSession(context);
      return null;
    }
    if (error.statusCode == 429) return l10n.tooManyAttempts;
    if (error.message.isNotEmpty) return error.message;
  }
  return l10n.somethingWentWrong;
}

void openLoginForExpiredSession(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
}

/// The referral link as a QR code, drawn on the device, with the app mark on
/// a white tile in the middle. Error correction "H" keeps it scannable with
/// the centre covered.
class ReferralQr extends StatelessWidget {
  final String data;
  final double size;

  const ReferralQr({super.key, required this.data, this.size = 160});

  @override
  Widget build(BuildContext context) {
    final logo = size * 0.22;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            QrImageView(
              data: data,
              size: size,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF0F0D16),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF0F0D16),
              ),
            ),
            Container(
              width: logo,
              height: logo,
              padding: EdgeInsets.all(logo * 0.1),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(logo * 0.22),
              ),
              child: Image.asset(
                'assets/icons/app_icon.png',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big code with a Copy button next to it.
class ReferralCodeRow extends StatelessWidget {
  final String code;
  final double fontSize;

  /// Icon-only Copy, for narrow spots (the Profile card) so the code keeps
  /// its size.
  final bool compact;

  const ReferralCodeRow({
    super.key,
    required this.code,
    this.fontSize = 22,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SelectableText(
              code,
              maxLines: 1,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: AppColors.inkStrong,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (compact)
          IconButton.outlined(
            tooltip: l10n.copy,
            onPressed: () => copyToClipboard(context, code),
            icon: const Icon(Icons.copy_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          )
        else
          OutlinedButton.icon(
            onPressed: () => copyToClipboard(context, code),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: Text(l10n.copy),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
      ],
    );
  }
}

/// points_balance / redeem_threshold, with the "N points to your next X%
/// coupon" line (or "redeem now" once it is reachable).
class PointsProgress extends StatelessWidget {
  final ReferralStats stats;
  final ReferralRules rules;

  const PointsProgress({super.key, required this.stats, required this.rules});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final percent = formatPercent(context, rules.couponPercent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.stars_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              l10n.pointsBalance,
              style: TextStyle(fontSize: 13, color: AppColors.body),
            ),
            const Spacer(),
            Text(
              l10n.pointsProgress(
                formatPoints(context, stats.pointsBalance),
                formatPoints(context, stats.redeemThreshold),
              ),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.inkStrong,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: stats.progress,
            minHeight: 8,
            backgroundColor: AppColors.line,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          stats.canRedeem
              ? l10n.couponReadyToRedeem(percent)
              : l10n.pointsToNextCoupon(
                  formatPoints(context, stats.pointsToNextCoupon),
                  percent,
                ),
          style: TextStyle(
            fontSize: 12.5,
            color: stats.canRedeem ? AppColors.primary : AppColors.muted,
            fontWeight: stats.canRedeem ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Small rounded status label.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
