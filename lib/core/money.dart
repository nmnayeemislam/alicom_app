/// Single place that decides how a price is rendered, so every screen agrees
/// on the currency symbol and precision.
///
/// The symbol and decimals come from the store's settings
/// (`GET /settings/branding` → `currency_symbol`, `currency_decimals`,
/// `currency_code`), applied once at startup by the splash screen via
/// [CurrencySettings.applyBranding] — nothing here hardcodes a currency.
/// Amounts get thousands separators (`$151,999.05`); negatives put the sign
/// before the symbol (`-$1,000.00`); `null` renders as zero.
class CurrencySettings {
  CurrencySettings._();

  /// Empty until branding loads. Splash waits for it, so in practice a price
  /// is never drawn before this is set; if the request fails, prices show
  /// as bare numbers rather than in a guessed currency.
  static String symbol = '';
  static String code = '';
  static int decimals = 2;

  /// Reads the currency fields from a `/settings/branding` response — the
  /// full `{data: {...}}` body or just its `data` map.
  static void applyBranding(dynamic response) {
    final data = response is Map && response['data'] is Map ? response['data'] : response;
    if (data is! Map) return;
    final newSymbol = data['currency_symbol'];
    final newCode = data['currency_code'];
    final newDecimals = data['currency_decimals'];
    if (newSymbol is String && newSymbol.isNotEmpty) symbol = newSymbol;
    if (newCode is String && newCode.isNotEmpty) code = newCode;
    final parsedDecimals = newDecimals is num ? newDecimals.toInt() : int.tryParse('$newDecimals');
    if (parsedDecimals != null && parsedDecimals >= 0 && parsedDecimals <= 4) {
      decimals = parsedDecimals;
    }
  }
}

String formatPrice(num? value) {
  final amount = (value ?? 0).toDouble();
  final sign = amount < 0 ? '-' : '';
  final fixed = amount.abs().toStringAsFixed(CurrencySettings.decimals);
  final dot = fixed.indexOf('.');
  final whole = dot == -1 ? fixed : fixed.substring(0, dot);
  final fraction = dot == -1 ? '' : fixed.substring(dot);
  final grouped = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  // With no symbol (branding not loaded), fall back to the ISO code with a
  // space ("USD 44.10") when known, else the bare number.
  final prefix = CurrencySettings.symbol.isNotEmpty
      ? CurrencySettings.symbol
      : (CurrencySettings.code.isNotEmpty ? '${CurrencySettings.code} ' : '');
  return '$sign$prefix$grouped$fraction';
}
