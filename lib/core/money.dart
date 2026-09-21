/// Single place that decides how a price is rendered, so every screen agrees
/// on the currency symbol and precision (home used to show `$3149.10` while
/// the cart showed `৳3149` for the same product).
///
/// Prices are shown in US dollars with two decimals (`$3149.10`, `$49086.00`)
/// — change [currencySymbol] here to switch the whole app. Negatives put the
/// sign before the symbol (`-$1000.00`), and `null` renders as zero.
const currencySymbol = '\$';

String formatPrice(num? value) {
  final amount = (value ?? 0).toDouble();
  final magnitude = amount.abs();
  final sign = amount < 0 ? '-' : '';
  return '$sign$currencySymbol${magnitude.toStringAsFixed(2)}';
}
