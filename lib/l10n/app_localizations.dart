import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  /// No description provided for @referEarnTitle.
  ///
  /// In en, this message translates to:
  /// **'Refer & Earn'**
  String get referEarnTitle;

  /// No description provided for @referEarnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Invite friends and earn loyalty points'**
  String get referEarnSubtitle;

  /// No description provided for @yourReferralCode.
  ///
  /// In en, this message translates to:
  /// **'Your referral code'**
  String get yourReferralCode;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copied;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @referralShareMessage.
  ///
  /// In en, this message translates to:
  /// **'Join Alicom with my code {code} and shop: {link}'**
  String referralShareMessage(String code, String link);

  /// No description provided for @pointsToNextCoupon.
  ///
  /// In en, this message translates to:
  /// **'{points} points to your next {percent}% coupon'**
  String pointsToNextCoupon(String points, String percent);

  /// No description provided for @couponReadyToRedeem.
  ///
  /// In en, this message translates to:
  /// **'You can redeem a {percent}% coupon now!'**
  String couponReadyToRedeem(String percent);

  /// No description provided for @earnRule.
  ///
  /// In en, this message translates to:
  /// **'Earn {points} points when a friend completes their first order.'**
  String earnRule(String points);

  /// No description provided for @invitedByLong.
  ///
  /// In en, this message translates to:
  /// **'You were invited by {name}'**
  String invitedByLong(String name);

  /// No description provided for @haveReferralCode.
  ///
  /// In en, this message translates to:
  /// **'Have a referral code?'**
  String get haveReferralCode;

  /// No description provided for @referralUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Referral programme is currently unavailable'**
  String get referralUnavailable;

  /// No description provided for @pointsBalance.
  ///
  /// In en, this message translates to:
  /// **'Points balance'**
  String get pointsBalance;

  /// No description provided for @pointsShort.
  ///
  /// In en, this message translates to:
  /// **'{points} pts'**
  String pointsShort(String points);

  /// No description provided for @pointsProgress.
  ///
  /// In en, this message translates to:
  /// **'{balance} / {threshold} pts'**
  String pointsProgress(String balance, String threshold);

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get viewDetails;

  /// No description provided for @tabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get tabOverview;

  /// No description provided for @tabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tabHistory;

  /// No description provided for @tabRewards.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get tabRewards;

  /// No description provided for @statTotalReferred.
  ///
  /// In en, this message translates to:
  /// **'Total referred'**
  String get statTotalReferred;

  /// No description provided for @statPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statPending;

  /// No description provided for @statRewarded.
  ///
  /// In en, this message translates to:
  /// **'Rewarded'**
  String get statRewarded;

  /// No description provided for @statPointsEarned.
  ///
  /// In en, this message translates to:
  /// **'Points earned'**
  String get statPointsEarned;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get filterPending;

  /// No description provided for @filterRewarded.
  ///
  /// In en, this message translates to:
  /// **'Rewarded'**
  String get filterRewarded;

  /// No description provided for @filterReversed.
  ///
  /// In en, this message translates to:
  /// **'Reversed'**
  String get filterReversed;

  /// No description provided for @statusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for first order'**
  String get statusWaiting;

  /// No description provided for @statusRewardedPoints.
  ///
  /// In en, this message translates to:
  /// **'+{points} pts'**
  String statusRewardedPoints(String points);

  /// No description provided for @statusReversed.
  ///
  /// In en, this message translates to:
  /// **'Reversed'**
  String get statusReversed;

  /// No description provided for @statusCapped.
  ///
  /// In en, this message translates to:
  /// **'Limit reached'**
  String get statusCapped;

  /// No description provided for @joinedOn.
  ///
  /// In en, this message translates to:
  /// **'Joined {date}'**
  String joinedOn(String date);

  /// No description provided for @rewardedOn.
  ///
  /// In en, this message translates to:
  /// **'Rewarded {date}'**
  String rewardedOn(String date);

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No referrals yet — share your code to start earning.'**
  String get historyEmpty;

  /// No description provided for @redeemPointsButton.
  ///
  /// In en, this message translates to:
  /// **'Redeem {points} points'**
  String redeemPointsButton(String points);

  /// No description provided for @redeemConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Redeem points?'**
  String get redeemConfirmTitle;

  /// No description provided for @redeemConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Spend {points} points for a {percent}% coupon (orders of {minOrder}+ only)?'**
  String redeemConfirmBody(String points, String percent, String minOrder);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @redeem.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get redeem;

  /// No description provided for @couponReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your coupon is ready!'**
  String get couponReadyTitle;

  /// No description provided for @useNow.
  ///
  /// In en, this message translates to:
  /// **'Use now'**
  String get useNow;

  /// No description provided for @yourCoupons.
  ///
  /// In en, this message translates to:
  /// **'Your coupons'**
  String get yourCoupons;

  /// No description provided for @couponsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No coupons yet. Redeem your points to get one.'**
  String get couponsEmpty;

  /// No description provided for @couponPercentOff.
  ///
  /// In en, this message translates to:
  /// **'{percent}% off'**
  String couponPercentOff(String percent);

  /// No description provided for @couponAmountOff.
  ///
  /// In en, this message translates to:
  /// **'{amount} off'**
  String couponAmountOff(String amount);

  /// No description provided for @couponMinOrder.
  ///
  /// In en, this message translates to:
  /// **'Min order {amount}'**
  String couponMinOrder(String amount);

  /// No description provided for @couponMaxDiscount.
  ///
  /// In en, this message translates to:
  /// **'Up to {amount} off'**
  String couponMaxDiscount(String amount);

  /// No description provided for @couponExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String couponExpires(String date);

  /// No description provided for @couponStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get couponStatusActive;

  /// No description provided for @couponStatusUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get couponStatusUsed;

  /// No description provided for @couponStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get couponStatusExpired;

  /// No description provided for @referralCodeField.
  ///
  /// In en, this message translates to:
  /// **'Referral code (optional)'**
  String get referralCodeField;

  /// No description provided for @scanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR'**
  String get scanQr;

  /// No description provided for @scanQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan referral QR'**
  String get scanQrTitle;

  /// No description provided for @scanQrHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at a referral QR code'**
  String get scanQrHint;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera is not available. Allow camera access in Settings and try again.'**
  String get cameraUnavailable;

  /// No description provided for @codeInvitedBy.
  ///
  /// In en, this message translates to:
  /// **'Invited by {name}'**
  String codeInvitedBy(String name);

  /// No description provided for @codeNotValid.
  ///
  /// In en, this message translates to:
  /// **'This referral code is not valid'**
  String get codeNotValid;

  /// No description provided for @applyCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply a referral code'**
  String get applyCodeTitle;

  /// No description provided for @applyCodeBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the code a friend shared with you. They earn points once your first order is completed.'**
  String get applyCodeBody;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @codeApplied.
  ///
  /// In en, this message translates to:
  /// **'Referral code applied. Invited by {name}'**
  String codeApplied(String name);

  /// No description provided for @enterReferralCode.
  ///
  /// In en, this message translates to:
  /// **'Enter a referral code'**
  String get enterReferralCode;

  /// No description provided for @tooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts, please wait a minute.'**
  String get tooManyAttempts;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get somethingWentWrong;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageBangla.
  ///
  /// In en, this message translates to:
  /// **'বাংলা'**
  String get languageBangla;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
