import 'package:flutter_test/flutter_test.dart';

import 'package:alicom_app/models/referral.dart';

void main() {
  group('extractReferralCode', () {
    test('takes the last segment of a /ref/{CODE} link', () {
      expect(extractReferralCode('https://shop.example.com/ref/ABX829KQ'), 'ABX829KQ');
      expect(extractReferralCode('http://localhost:8000/ref/yrfs3mjk'), 'YRFS3MJK');
      expect(extractReferralCode('https://shop.example.com/ref/ABX829KQ/'), 'ABX829KQ');
    });

    test('accepts a bare code', () {
      expect(extractReferralCode('  abx829kq '), 'ABX829KQ');
      expect(extractReferralCode('SUMMER-2026'), 'SUMMER-2026');
    });

    test('rejects text that is neither', () {
      expect(extractReferralCode(''), isNull);
      expect(extractReferralCode(null), isNull);
      expect(extractReferralCode('https://shop.example.com/products/iphone'), isNull);
      expect(extractReferralCode('hello world!'), isNull);
    });
  });

  test('ReferralInfo parses every number from the API', () {
    final info = ReferralInfo.fromJson({
      'enabled': true,
      'referral_code': 'ABX829KQ',
      'referral_link': 'https://shop.example.com/ref/ABX829KQ',
      'referred_by': {'name': 'Ra***'},
      'can_apply_code': false,
      'stats': {
        'total_referred': 3,
        'pending': 1,
        'rewarded': 2,
        'points_earned': 200,
        'points_balance': 900,
        'redeem_threshold': 1000,
        'can_redeem': false,
        'points_to_next_coupon': 100,
      },
      'rules': {
        'reward_points': 100,
        'redeem_threshold': 1000,
        'coupon_percent': 10,
        'coupon_min_order': 200,
        'coupon_valid_days': 90,
      },
    });
    expect(info.referredByName, 'Ra***');
    expect(info.stats.progress, closeTo(0.9, 1e-9));
    expect(info.stats.pointsToNextCoupon, 100);
    expect(info.rules.couponPercent, 10);
    expect(info.rules.couponMinOrder, 200);
  });

  test('history rows keep the server-masked name and dates', () {
    final page = ReferralHistoryPage.fromJson({
      'referrals': [
        {
          'id': 7,
          'referred_name': 'Ka***',
          'status': 'rewarded',
          'reward_amount': 100,
          'joined_at': '2026-09-01T10:00:00Z',
          'rewarded_at': '2026-09-10T10:00:00Z',
        },
      ],
      'pagination': {'current_page': 1, 'per_page': 20, 'total': 1, 'last_page': 1, 'has_more_pages': false},
    });
    expect(page.items.single.referredName, 'Ka***');
    expect(page.items.single.rewardedAt, isNotNull);
    expect(page.pagination.hasMorePages, isFalse);
  });

  test('reward coupons read status and limits', () {
    final rewards = ReferralRewards.fromJson({
      'points_balance': 50,
      'can_redeem': false,
      'coupons': [
        {'code': 'PTS-1', 'type': 'percentage', 'value': 10, 'min_order_amount': 200, 'status': 'active'},
        {'code': 'PTS-0', 'type': 'percentage', 'value': 10, 'min_order_amount': 200, 'status': 'used'},
      ],
    });
    expect(rewards.coupons.first.isActive, isTrue);
    expect(rewards.coupons.last.isActive, isFalse);
    expect(rewards.coupons.first.minOrderAmount, 200);
  });
}
