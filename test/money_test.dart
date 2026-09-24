import 'package:flutter_test/flutter_test.dart';

import 'package:alicom_app/core/money.dart';

void main() {
  tearDown(() {
    CurrencySettings.symbol = '';
    CurrencySettings.code = '';
    CurrencySettings.decimals = 2;
  });

  test('uses the symbol and decimals from /settings/branding', () {
    CurrencySettings.applyBranding({
      'data': {'currency_code': 'USD', 'currency_symbol': r'$', 'currency_decimals': 2},
    });
    expect(formatPrice(44.1), r'$44.10');
    expect(formatPrice(151999.05), r'$151,999.05');
    expect(formatPrice(-1000), r'-$1,000.00');
    expect(formatPrice(null), r'$0.00');
  });

  test('follows a different store currency without code changes', () {
    CurrencySettings.applyBranding({
      'data': {'currency_code': 'BDT', 'currency_symbol': '৳', 'currency_decimals': 0},
    });
    expect(formatPrice(1234.6), '৳1,235');
  });

  test('falls back to the currency code, never a guessed symbol', () {
    CurrencySettings.applyBranding({'data': {'currency_code': 'USD'}});
    expect(formatPrice(5), 'USD 5.00');
  });
}
