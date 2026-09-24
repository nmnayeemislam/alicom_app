import 'product_page.dart';

/// Shapes from the referral API (`/referral`, `/referral/history`,
/// `/referral/rewards`, `/referral/redeem`, `/referral/validate`). Every
/// number here — points, thresholds, percentages, minimum orders — comes
/// from the server; nothing is assumed on the device.

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

double? _doubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

bool _bool(dynamic value) => value == true || value == 1 || value == '1' || value == 'true';

DateTime? _date(dynamic value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? value.cast<String, dynamic>() : const <String, dynamic>{};

/// `stats` block of `GET /referral`.
class ReferralStats {
  final int totalReferred;
  final int pending;
  final int rewarded;
  final int reversed;
  final int capped;
  final int pointsEarned;
  final int pointsPending;
  final int pointsReversed;
  final int pointsBalance;
  final int redeemThreshold;
  final bool canRedeem;
  final int pointsToNextCoupon;

  const ReferralStats({
    this.totalReferred = 0,
    this.pending = 0,
    this.rewarded = 0,
    this.reversed = 0,
    this.capped = 0,
    this.pointsEarned = 0,
    this.pointsPending = 0,
    this.pointsReversed = 0,
    this.pointsBalance = 0,
    this.redeemThreshold = 0,
    this.canRedeem = false,
    this.pointsToNextCoupon = 0,
  });

  factory ReferralStats.fromJson(Map<String, dynamic> json) => ReferralStats(
        totalReferred: _int(json['total_referred']),
        pending: _int(json['pending']),
        rewarded: _int(json['rewarded']),
        reversed: _int(json['reversed']),
        capped: _int(json['capped']),
        pointsEarned: _int(json['points_earned']),
        pointsPending: _int(json['points_pending']),
        pointsReversed: _int(json['points_reversed']),
        pointsBalance: _int(json['points_balance']),
        redeemThreshold: _int(json['redeem_threshold']),
        canRedeem: _bool(json['can_redeem']),
        pointsToNextCoupon: _int(json['points_to_next_coupon']),
      );

  /// 0..1 for the progress bar; a zero threshold (misconfigured) reads full.
  double get progress => redeemThreshold <= 0 ? 1 : (pointsBalance / redeemThreshold).clamp(0, 1).toDouble();
}

/// `rules` block of `GET /referral` — the admin-configured programme terms.
class ReferralRules {
  final int rewardPoints;
  final String qualifyingStatus;
  final double minOrderAmount;
  final int redeemThreshold;
  final double couponPercent;
  final double couponMinOrder;
  final double? couponMaxDiscount;
  final int couponValidDays;

  const ReferralRules({
    this.rewardPoints = 0,
    this.qualifyingStatus = '',
    this.minOrderAmount = 0,
    this.redeemThreshold = 0,
    this.couponPercent = 0,
    this.couponMinOrder = 0,
    this.couponMaxDiscount,
    this.couponValidDays = 0,
  });

  factory ReferralRules.fromJson(Map<String, dynamic> json) => ReferralRules(
        rewardPoints: _int(json['reward_points']),
        qualifyingStatus: '${json['qualifying_status'] ?? ''}',
        minOrderAmount: _double(json['min_order_amount']),
        redeemThreshold: _int(json['redeem_threshold']),
        couponPercent: _double(json['coupon_percent']),
        couponMinOrder: _double(json['coupon_min_order']),
        couponMaxDiscount: _doubleOrNull(json['coupon_max_discount']),
        couponValidDays: _int(json['coupon_valid_days']),
      );
}

/// `GET /referral` — the profile card and the Overview tab.
class ReferralInfo {
  final bool enabled;
  final String code;
  final String link;

  /// Already masked by the server ("Ra***").
  final String? referredByName;
  final bool canApplyCode;
  final ReferralStats stats;
  final ReferralRules rules;

  const ReferralInfo({
    required this.enabled,
    required this.code,
    required this.link,
    this.referredByName,
    this.canApplyCode = false,
    this.stats = const ReferralStats(),
    this.rules = const ReferralRules(),
  });

  factory ReferralInfo.fromJson(Map<String, dynamic> json) {
    final referredBy = json['referred_by'];
    return ReferralInfo(
      enabled: _bool(json['enabled']),
      code: '${json['referral_code'] ?? ''}',
      link: '${json['referral_link'] ?? ''}',
      referredByName: referredBy is Map ? referredBy['name'] as String? : null,
      canApplyCode: _bool(json['can_apply_code']),
      stats: ReferralStats.fromJson(_map(json['stats'])),
      rules: ReferralRules.fromJson(_map(json['rules'])),
    );
  }
}

/// One row of `GET /referral/history`.
class ReferralHistoryItem {
  final int id;

  /// Masked by the server — shown as-is.
  final String referredName;

  /// pending | rewarded | reversed | capped
  final String status;
  final String? rewardStatus;
  final double rewardAmount;
  final DateTime? joinedAt;
  final DateTime? rewardedAt;

  const ReferralHistoryItem({
    required this.id,
    required this.referredName,
    required this.status,
    this.rewardStatus,
    this.rewardAmount = 0,
    this.joinedAt,
    this.rewardedAt,
  });

  factory ReferralHistoryItem.fromJson(Map<String, dynamic> json) => ReferralHistoryItem(
        id: _int(json['id']),
        referredName: '${json['referred_name'] ?? ''}',
        status: '${json['status'] ?? ''}',
        rewardStatus: json['reward_status'] as String?,
        rewardAmount: _double(json['reward_amount']),
        joinedAt: _date(json['joined_at']),
        rewardedAt: _date(json['rewarded_at']),
      );
}

class ReferralHistoryPage {
  final List<ReferralHistoryItem> items;
  final Pagination pagination;

  const ReferralHistoryPage({required this.items, required this.pagination});

  factory ReferralHistoryPage.fromJson(Map<String, dynamic> json) {
    final raw = json['referrals'];
    return ReferralHistoryPage(
      items: raw is List
          ? raw.whereType<Map>().map((e) => ReferralHistoryItem.fromJson(e.cast<String, dynamic>())).toList()
          : const [],
      pagination: Pagination.fromJson(_map(json['pagination'])),
    );
  }
}

/// A personal coupon bought with points.
class RewardCoupon {
  final String code;
  final String title;

  /// percentage | fixed
  final String type;
  final double value;
  final double minOrderAmount;
  final double? maxDiscountAmount;
  final DateTime? expiresAt;

  /// active | used | expired
  final String status;
  final DateTime? createdAt;

  const RewardCoupon({
    required this.code,
    this.title = '',
    this.type = 'percentage',
    this.value = 0,
    this.minOrderAmount = 0,
    this.maxDiscountAmount,
    this.expiresAt,
    this.status = 'active',
    this.createdAt,
  });

  bool get isActive => status == 'active';
  bool get isPercentage => type != 'fixed';

  factory RewardCoupon.fromJson(Map<String, dynamic> json) => RewardCoupon(
        code: '${json['code'] ?? ''}',
        title: '${json['title'] ?? ''}',
        type: '${json['type'] ?? 'percentage'}',
        value: _double(json['value']),
        minOrderAmount: _double(json['min_order_amount']),
        maxDiscountAmount: _doubleOrNull(json['max_discount_amount']),
        expiresAt: _date(json['expires_at']),
        status: '${json['status'] ?? 'active'}',
        createdAt: _date(json['created_at']),
      );
}

/// `GET /referral/rewards`.
class ReferralRewards {
  final int pointsBalance;
  final int totalEarned;
  final int pending;
  final int completed;
  final int reversed;
  final int redeemThreshold;
  final bool canRedeem;
  final int pointsToNextCoupon;
  final List<RewardCoupon> coupons;

  const ReferralRewards({
    this.pointsBalance = 0,
    this.totalEarned = 0,
    this.pending = 0,
    this.completed = 0,
    this.reversed = 0,
    this.redeemThreshold = 0,
    this.canRedeem = false,
    this.pointsToNextCoupon = 0,
    this.coupons = const [],
  });

  factory ReferralRewards.fromJson(Map<String, dynamic> json) {
    final raw = json['coupons'];
    return ReferralRewards(
      pointsBalance: _int(json['points_balance']),
      totalEarned: _int(json['total_earned']),
      pending: _int(json['pending']),
      completed: _int(json['completed']),
      reversed: _int(json['reversed']),
      redeemThreshold: _int(json['redeem_threshold']),
      canRedeem: _bool(json['can_redeem']),
      pointsToNextCoupon: _int(json['points_to_next_coupon']),
      coupons: raw is List
          ? raw.whereType<Map>().map((e) => RewardCoupon.fromJson(e.cast<String, dynamic>())).toList()
          : const [],
    );
  }
}

/// `POST /referral/validate`.
class ReferralCodeCheck {
  final bool valid;
  final bool? eligible;
  final String? reason;
  final String? referrerName;
  final String message;

  const ReferralCodeCheck({
    required this.valid,
    this.eligible,
    this.reason,
    this.referrerName,
    this.message = '',
  });

  factory ReferralCodeCheck.fromResponse(Map<String, dynamic> body) {
    final data = _map(body['data']);
    final referrer = data['referrer'];
    return ReferralCodeCheck(
      valid: _bool(data['valid']),
      eligible: data['eligible'] == null ? null : _bool(data['eligible']),
      reason: data['reason'] as String?,
      referrerName: referrer is Map ? referrer['name'] as String? : null,
      message: '${body['message'] ?? ''}',
    );
  }
}

/// Pulls a referral code out of whatever a QR / deep link carried:
/// `https://<domain>/ref/ABX829KQ` → `ABX829KQ`; a bare code passes through.
/// Returns `null` for text that is neither.
String? extractReferralCode(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri != null && uri.hasScheme) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final refIndex = segments.lastIndexOf('ref');
    if (refIndex >= 0 && refIndex + 1 < segments.length) return segments[refIndex + 1].toUpperCase();
    // Storefront's register page also accepts ?ref=CODE.
    final query = uri.queryParameters['ref'] ?? uri.queryParameters['referral_code'];
    return query?.trim().isNotEmpty == true ? query!.trim().toUpperCase() : null;
  }
  // A bare code: letters, digits and hyphens (what the backend accepts).
  final code = text.toUpperCase();
  return RegExp(r'^[A-Z0-9-]{4,32}$').hasMatch(code) ? code : null;
}
