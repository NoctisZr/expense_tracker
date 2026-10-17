import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';

/// Gasto de [category] en el periodo de los presupuestos (mes calendario o
/// periodo de pago, según el ajuste), convertido a la moneda local.
double periodSpentLocal(
  FinanceProvider finance,
  CurrencyProvider currency,
  String category,
) {
  final period = finance.budgetPeriod();
  double total = 0;
  for (final e in finance.expensesInPeriod(period.start, period.end)) {
    if (e.category != category) continue;
    total += finance.expenseLocalValue(e, currency);
  }
  return total;
}

/// Sobrante del mes anterior que se suma al presupuesto de este mes. Solo
/// aplica en modo calendario y con la opción "sobrante" activada; si no, 0.
double budgetCarryOver(
  FinanceProvider finance,
  CurrencyProvider currency,
  String category,
  double limit,
) {
  if (!finance.budgetRollover || finance.isPayPeriodBudget) return 0;
  final DateTime now = DateTime.now();
  final DateTime start = DateTime(now.year, now.month - 1, 1);
  final DateTime end = DateTime(now.year, now.month, 1);
  double spent = 0;
  for (final e in finance.expensesInPeriod(start, end)) {
    if (e.category != category) continue;
    spent += finance.expenseLocalValue(e, currency);
  }
  final double left = limit - spent;
  return left > 0 ? left : 0;
}
