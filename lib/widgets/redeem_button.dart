import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../core/money.dart';
import '../l10n/app_localizations.dart';
import '../models/referral.dart';
import '../screens/cart_screen.dart';
import '../services/referral_service.dart';
import '../state/referral_state.dart';
import '../theme/app_theme.dart';
import 'referral_widgets.dart';

/// "Redeem {threshold} points" — enabled only when the API says
/// `can_redeem`. Asks for confirmation (terms from `rules`), is disabled
/// while the request runs so a double tap can't redeem twice, then shows the
/// new coupon and refreshes the shared referral data.
class RedeemButton extends StatefulWidget {
  final int threshold;
  final bool canRedeem;
  final ReferralRules rules;

  const RedeemButton({
    super.key,
    required this.threshold,
    required this.canRedeem,
    required this.rules,
  });

  @override
  State<RedeemButton> createState() => _RedeemButtonState();
}

class _RedeemButtonState extends State<RedeemButton> {
  bool _busy = false;

  Future<void> _redeem() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.redeemConfirmTitle),
        content: Text(l10n.redeemConfirmBody(
          formatPoints(context, widget.threshold),
          formatPercent(context, widget.rules.couponPercent),
          formatPrice(widget.rules.couponMinOrder),
        )),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(l10n.redeem)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await ReferralService.instance.redeem();
      await ReferralState.instance.refresh();
      if (!mounted) return;
      await showCouponReadySheet(context, result.coupon);
    } on ApiException catch (e) {
      if (!mounted) return;
      // 422 → errors.points[0] ("You need 1,000 points … you have 900.")
      final message = e.fieldErrors?['points']?.firstOrNull ?? referralErrorMessage(context, e);
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
      ReferralState.instance.refresh();
    } catch (e) {
      if (!mounted) return;
      final message = referralErrorMessage(context, e);
      if (message != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ElevatedButton.icon(
      onPressed: widget.canRedeem && !_busy ? _redeem : null,
      icon: _busy
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.redeem_rounded, size: 20),
      label: Text(l10n.redeemPointsButton(formatPoints(context, widget.threshold))),
      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
    );
  }
}

/// Success sheet after a redeem: the code, Copy and "Use now".
Future<void> showCouponReadySheet(BuildContext context, RewardCoupon coupon) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
              child: Icon(Icons.celebration_rounded, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.couponReadyTitle,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.inkStrong),
            ),
            const SizedBox(height: 6),
            Text(
              couponSummary(sheetContext, coupon),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.body),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: ReferralCodeRow(code: coupon.code),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                openCartWithCoupon(context, coupon.code);
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: Text(l10n.useNow),
            ),
          ],
        ),
      ),
    ),
  );
}

/// "10% off · Min order $200.00 · Up to $50.00 off" from the coupon's own
/// fields.
String couponSummary(BuildContext context, RewardCoupon coupon) {
  final l10n = AppLocalizations.of(context);
  return [
    coupon.isPercentage
        ? l10n.couponPercentOff(formatPercent(context, coupon.value))
        : l10n.couponAmountOff(formatPrice(coupon.value)),
    if (coupon.minOrderAmount > 0) l10n.couponMinOrder(formatPrice(coupon.minOrderAmount)),
    if (coupon.maxDiscountAmount != null && coupon.maxDiscountAmount! > 0)
      l10n.couponMaxDiscount(formatPrice(coupon.maxDiscountAmount!)),
  ].join(' · ');
}

/// "Use now": the cart with the code filled in and applied through the
/// normal coupon check, so any rejection shows the backend's message.
void openCartWithCoupon(BuildContext context, String code) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => CartScreen(initialCoupon: code)));
}
