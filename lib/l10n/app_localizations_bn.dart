// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get referEarnTitle => 'রেফার করে আয় করুন';

  @override
  String get referEarnSubtitle =>
      'বন্ধুদের আমন্ত্রণ জানিয়ে লয়্যালটি পয়েন্ট আয় করুন';

  @override
  String get yourReferralCode => 'আপনার রেফারেল কোড';

  @override
  String get copy => 'কপি';

  @override
  String get copied => 'ক্লিপবোর্ডে কপি হয়েছে';

  @override
  String get share => 'শেয়ার';

  @override
  String referralShareMessage(String code, String link) {
    return 'আমার কোড $code দিয়ে Alicom-এ যোগ দিন এবং কেনাকাটা করুন: $link';
  }

  @override
  String pointsToNextCoupon(String points, String percent) {
    return 'পরবর্তী $percent% কুপনের জন্য আর $points পয়েন্ট দরকার';
  }

  @override
  String couponReadyToRedeem(String percent) {
    return 'আপনি এখনই একটি $percent% কুপন রিডিম করতে পারেন!';
  }

  @override
  String earnRule(String points) {
    return 'কোনো বন্ধু প্রথম অর্ডার সম্পন্ন করলে আপনি $points পয়েন্ট পাবেন।';
  }

  @override
  String invitedByLong(String name) {
    return 'আপনাকে আমন্ত্রণ জানিয়েছেন $name';
  }

  @override
  String get haveReferralCode => 'রেফারেল কোড আছে?';

  @override
  String get referralUnavailable => 'রেফারেল প্রোগ্রাম এই মুহূর্তে বন্ধ আছে';

  @override
  String get pointsBalance => 'পয়েন্ট ব্যালান্স';

  @override
  String pointsShort(String points) {
    return '$points পয়েন্ট';
  }

  @override
  String pointsProgress(String balance, String threshold) {
    return '$balance / $threshold পয়েন্ট';
  }

  @override
  String get viewDetails => 'বিস্তারিত দেখুন';

  @override
  String get tabOverview => 'সারসংক্ষেপ';

  @override
  String get tabHistory => 'ইতিহাস';

  @override
  String get tabRewards => 'পুরস্কার';

  @override
  String get statTotalReferred => 'মোট রেফার';

  @override
  String get statPending => 'অপেক্ষমাণ';

  @override
  String get statRewarded => 'পুরস্কৃত';

  @override
  String get statPointsEarned => 'অর্জিত পয়েন্ট';

  @override
  String get filterAll => 'সব';

  @override
  String get filterPending => 'অপেক্ষমাণ';

  @override
  String get filterRewarded => 'পুরস্কৃত';

  @override
  String get filterReversed => 'বাতিল';

  @override
  String get statusWaiting => 'প্রথম অর্ডারের অপেক্ষায়';

  @override
  String statusRewardedPoints(String points) {
    return '+$points পয়েন্ট';
  }

  @override
  String get statusReversed => 'বাতিল হয়েছে';

  @override
  String get statusCapped => 'সীমা পূর্ণ';

  @override
  String joinedOn(String date) {
    return 'যোগ দিয়েছেন $date';
  }

  @override
  String rewardedOn(String date) {
    return 'পুরস্কার পেয়েছেন $date';
  }

  @override
  String get historyEmpty =>
      'এখনও কোনো রেফারেল নেই — আয় শুরু করতে আপনার কোড শেয়ার করুন।';

  @override
  String redeemPointsButton(String points) {
    return '$points পয়েন্ট রিডিম করুন';
  }

  @override
  String get redeemConfirmTitle => 'পয়েন্ট রিডিম করবেন?';

  @override
  String redeemConfirmBody(String points, String percent, String minOrder) {
    return '$points পয়েন্ট খরচ করে একটি $percent% কুপন নেবেন? (শুধুমাত্র $minOrder বা তার বেশি অর্ডারে)';
  }

  @override
  String get cancel => 'বাতিল';

  @override
  String get redeem => 'রিডিম';

  @override
  String get couponReadyTitle => 'আপনার কুপন তৈরি!';

  @override
  String get useNow => 'এখনই ব্যবহার করুন';

  @override
  String get yourCoupons => 'আপনার কুপন';

  @override
  String get couponsEmpty => 'এখনও কোনো কুপন নেই। পয়েন্ট রিডিম করে কুপন নিন।';

  @override
  String couponPercentOff(String percent) {
    return '$percent% ছাড়';
  }

  @override
  String couponAmountOff(String amount) {
    return '$amount ছাড়';
  }

  @override
  String couponMinOrder(String amount) {
    return 'সর্বনিম্ন অর্ডার $amount';
  }

  @override
  String couponMaxDiscount(String amount) {
    return 'সর্বোচ্চ $amount ছাড়';
  }

  @override
  String couponExpires(String date) {
    return 'মেয়াদ শেষ $date';
  }

  @override
  String get couponStatusActive => 'সক্রিয়';

  @override
  String get couponStatusUsed => 'ব্যবহৃত';

  @override
  String get couponStatusExpired => 'মেয়াদোত্তীর্ণ';

  @override
  String get referralCodeField => 'রেফারেল কোড (ঐচ্ছিক)';

  @override
  String get scanQr => 'QR স্ক্যান';

  @override
  String get scanQrTitle => 'রেফারেল QR স্ক্যান করুন';

  @override
  String get scanQrHint => 'ক্যামেরাটি রেফারেল QR কোডের দিকে ধরুন';

  @override
  String get cameraUnavailable =>
      'ক্যামেরা পাওয়া যাচ্ছে না। সেটিংসে ক্যামেরার অনুমতি দিয়ে আবার চেষ্টা করুন।';

  @override
  String codeInvitedBy(String name) {
    return 'আমন্ত্রণ জানিয়েছেন $name';
  }

  @override
  String get codeNotValid => 'এই রেফারেল কোডটি সঠিক নয়';

  @override
  String get applyCodeTitle => 'রেফারেল কোড প্রয়োগ করুন';

  @override
  String get applyCodeBody =>
      'বন্ধুর দেওয়া কোডটি লিখুন। আপনার প্রথম অর্ডার সম্পন্ন হলে তিনি পয়েন্ট পাবেন।';

  @override
  String get apply => 'প্রয়োগ করুন';

  @override
  String codeApplied(String name) {
    return 'রেফারেল কোড প্রয়োগ হয়েছে। আমন্ত্রণ জানিয়েছেন $name';
  }

  @override
  String get enterReferralCode => 'একটি রেফারেল কোড লিখুন';

  @override
  String get tooManyAttempts =>
      'অনেকবার চেষ্টা করা হয়েছে, এক মিনিট অপেক্ষা করুন।';

  @override
  String get somethingWentWrong => 'কিছু একটা সমস্যা হয়েছে। আবার চেষ্টা করুন।';

  @override
  String get retry => 'আবার চেষ্টা করুন';

  @override
  String get language => 'ভাষা';

  @override
  String get languageSystem => 'সিস্টেম';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageBangla => 'বাংলা';
}
