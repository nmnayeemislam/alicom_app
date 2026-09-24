import '../core/api_client.dart';
import '../core/api_endpoints.dart';
import '../models/referral.dart';

/// Referral programme + loyalty points — mirrors the API ReferralController.
/// The referrer is never sent: the backend derives it from the code.
class ReferralService {
  ReferralService._();
  static final ReferralService instance = ReferralService._();

  final _client = ApiClient.instance;

  static Map<String, dynamic> _data(dynamic body) {
    final data = body is Map ? body['data'] : null;
    return data is Map ? data.cast<String, dynamic>() : const {};
  }

  Future<ReferralInfo> info() async =>
      ReferralInfo.fromJson(_data((await _client.get(ApiEndpoints.referral)).data));

  /// [status]: pending | rewarded | reversed | capped, or `null` for all.
  Future<ReferralHistoryPage> history({int page = 1, int perPage = 20, String? status}) async {
    final response = await _client.get(
      ApiEndpoints.referralHistory,
      queryParameters: {'page': page, 'per_page': perPage, 'status': ?status},
    );
    return ReferralHistoryPage.fromJson(_data(response.data));
  }

  Future<ReferralRewards> rewards() async =>
      ReferralRewards.fromJson(_data((await _client.get(ApiEndpoints.referralRewards)).data));

  /// Spends points on a personal coupon. A 422 (not enough points) surfaces
  /// as an ApiException whose `fieldErrors['points']` carries the reason.
  Future<({RewardCoupon coupon, int pointsBalance})> redeem() async {
    final data = _data((await _client.post(ApiEndpoints.referralRedeem)).data);
    final coupon = data['coupon'];
    return (
      coupon: RewardCoupon.fromJson(coupon is Map ? coupon.cast<String, dynamic>() : const {}),
      pointsBalance: (data['points_balance'] as num?)?.toInt() ?? 0,
    );
  }

  /// Public — works before an account exists (sign-up screen).
  Future<ReferralCodeCheck> validate(String code) async {
    final response = await _client.post(ApiEndpoints.referralValidate, data: {'referral_code': code});
    final body = response.data;
    return ReferralCodeCheck.fromResponse(body is Map ? body.cast<String, dynamic>() : const {});
  }

  /// Attaches a friend's code to the signed-in account; returns the
  /// (masked) referrer name. 422s carry `errors.referral_code`.
  Future<String?> apply(String code) async {
    final data = _data((await _client.post(ApiEndpoints.referralApply, data: {'referral_code': code})).data);
    final referral = data['referral'];
    final referredBy = referral is Map ? referral['referred_by'] : null;
    return referredBy is Map ? referredBy['name'] as String? : null;
  }
}
