// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get referEarnTitle => 'Refer & Earn';

  @override
  String get referEarnSubtitle => 'Invite friends and earn loyalty points';

  @override
  String get yourReferralCode => 'Your referral code';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied to clipboard';

  @override
  String get share => 'Share';

  @override
  String referralShareMessage(String code, String link) {
    return 'Join Alicom with my code $code and shop: $link';
  }

  @override
  String pointsToNextCoupon(String points, String percent) {
    return '$points points to your next $percent% coupon';
  }

  @override
  String couponReadyToRedeem(String percent) {
    return 'You can redeem a $percent% coupon now!';
  }

  @override
  String earnRule(String points) {
    return 'Earn $points points when a friend completes their first order.';
  }

  @override
  String invitedByLong(String name) {
    return 'You were invited by $name';
  }

  @override
  String get haveReferralCode => 'Have a referral code?';

  @override
  String get referralUnavailable =>
      'Referral programme is currently unavailable';

  @override
  String get pointsBalance => 'Points balance';

  @override
  String pointsShort(String points) {
    return '$points pts';
  }

  @override
  String pointsProgress(String balance, String threshold) {
    return '$balance / $threshold pts';
  }

  @override
  String get viewDetails => 'View details';

  @override
  String get tabOverview => 'Overview';

  @override
  String get tabHistory => 'History';

  @override
  String get tabRewards => 'Rewards';

  @override
  String get statTotalReferred => 'Total referred';

  @override
  String get statPending => 'Pending';

  @override
  String get statRewarded => 'Rewarded';

  @override
  String get statPointsEarned => 'Points earned';

  @override
  String get filterAll => 'All';

  @override
  String get filterPending => 'Pending';

  @override
  String get filterRewarded => 'Rewarded';

  @override
  String get filterReversed => 'Reversed';

  @override
  String get statusWaiting => 'Waiting for first order';

  @override
  String statusRewardedPoints(String points) {
    return '+$points pts';
  }

  @override
  String get statusReversed => 'Reversed';

  @override
  String get statusCapped => 'Limit reached';

  @override
  String joinedOn(String date) {
    return 'Joined $date';
  }

  @override
  String rewardedOn(String date) {
    return 'Rewarded $date';
  }

  @override
  String get historyEmpty =>
      'No referrals yet — share your code to start earning.';

  @override
  String redeemPointsButton(String points) {
    return 'Redeem $points points';
  }

  @override
  String get redeemConfirmTitle => 'Redeem points?';

  @override
  String redeemConfirmBody(String points, String percent, String minOrder) {
    return 'Spend $points points for a $percent% coupon (orders of $minOrder+ only)?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get redeem => 'Redeem';

  @override
  String get couponReadyTitle => 'Your coupon is ready!';

  @override
  String get useNow => 'Use now';

  @override
  String get yourCoupons => 'Your coupons';

  @override
  String get couponsEmpty => 'No coupons yet. Redeem your points to get one.';

  @override
  String couponPercentOff(String percent) {
    return '$percent% off';
  }

  @override
  String couponAmountOff(String amount) {
    return '$amount off';
  }

  @override
  String couponMinOrder(String amount) {
    return 'Min order $amount';
  }

  @override
  String couponMaxDiscount(String amount) {
    return 'Up to $amount off';
  }

  @override
  String couponExpires(String date) {
    return 'Expires $date';
  }

  @override
  String get couponStatusActive => 'Active';

  @override
  String get couponStatusUsed => 'Used';

  @override
  String get couponStatusExpired => 'Expired';

  @override
  String get referralCodeField => 'Referral code (optional)';

  @override
  String get scanQr => 'Scan QR';

  @override
  String get scanQrTitle => 'Scan referral QR';

  @override
  String get scanQrHint => 'Point the camera at a referral QR code';

  @override
  String get cameraUnavailable =>
      'Camera is not available. Allow camera access in Settings and try again.';

  @override
  String codeInvitedBy(String name) {
    return 'Invited by $name';
  }

  @override
  String get codeNotValid => 'This referral code is not valid';

  @override
  String get applyCodeTitle => 'Apply a referral code';

  @override
  String get applyCodeBody =>
      'Enter the code a friend shared with you. They earn points once your first order is completed.';

  @override
  String get apply => 'Apply';

  @override
  String codeApplied(String name) {
    return 'Referral code applied. Invited by $name';
  }

  @override
  String get enterReferralCode => 'Enter a referral code';

  @override
  String get tooManyAttempts => 'Too many attempts, please wait a minute.';

  @override
  String get somethingWentWrong => 'Something went wrong. Please try again.';

  @override
  String get retry => 'Retry';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageBangla => 'বাংলা';
}
