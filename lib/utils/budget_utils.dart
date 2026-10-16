import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';

/// Gasto del mes en curso para [category], convertido a la moneda local.
double monthSpentLocal(
  FinanceProvider finance,
  CurrencyProvider currency,
  String category,
) {
  final DateTime now = DateTime.now();
  final DateTime start = DateTime(now.year, now.month, 1);
  final DateTime end = DateTime(now.year, now.month + 1, 1);
  double total = 0;
  for (final e in finance.expensesInPeriod(start, end)) {
    if (e.category != category) continue;
    total += currency.convert(e.amount, e.currency, finance.localCurrency);
  }
  return total;
}
