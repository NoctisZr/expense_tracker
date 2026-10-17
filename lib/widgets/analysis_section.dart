import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/app_theme_extension.dart';
import '../utils/category_style.dart';
import '../utils/formatters.dart';
import 'section_card.dart';

/// Análisis del gasto: tendencia de los últimos 6 meses, comparación con
/// el mes anterior, promedio diario y los 5 gastos más grandes del mes.
/// Todo en moneda local.
class AnalysisSection extends StatelessWidget {
  const AnalysisSection({super.key});

  static String _compact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final currency = context.watch<CurrencyProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final extras = theme.extension<AppThemeExtras>()!;

    final DateTime now = DateTime.now();
    final List<DateTime> months = [
      for (int back = 5; back >= 0; back--) DateTime(now.year, now.month - back, 1),
    ];

    final List<double> totals = [];
    for (final m in months) {
      final DateTime end = DateTime(m.year, m.month + 1, 1);
      double sum = 0;
      for (final e in finance.expensesInPeriod(m, end)) {
        sum += finance.expenseLocalValue(e, currency);
      }
      totals.add(sum);
    }

    final double current = totals.last;
    final double previous = totals[totals.length - 2];
    final double maxTotal = totals.fold(0.0, (a, b) => a > b ? a : b);
    final bool hasData = maxTotal > 0;

    final DateTime monthStart = months.last;
    final DateTime monthEnd = DateTime(now.year, now.month + 1, 1);
    final List<Expense> monthExpenses = finance.expensesInPeriod(monthStart, monthEnd)
      ..sort((a, b) => finance
          .expenseLocalValue(b, currency)
          .compareTo(finance.expenseLocalValue(a, currency)));
    final List<Expense> top = monthExpenses.take(5).toList();

    // --- Periodo de pago actual vs anterior (desde el último ingreso) ---
    final Income? payIncome = finance.currentPayIncome;
    double periodSpent = 0;
    int periodDays = 1;
    double? previousTotal;
    int previousDays = 1;
    if (payIncome != null) {
      final int rawDays = now.difference(payIncome.date).inDays + 1;
      periodDays = rawDays < 1 ? 1 : rawDays;
      for (final e in finance.expensesInPeriod(payIncome.date, null)) {
        periodSpent += finance.expenseLocalValue(e, currency);
      }
      final Income? previousIncome = finance.previousPayIncome(payIncome);
      if (previousIncome != null) {
        final int rawPrev = payIncome.date.difference(previousIncome.date).inDays;
        previousDays = rawPrev < 1 ? 1 : rawPrev;
        double sum = 0;
        for (final e in finance.expensesInPeriod(previousIncome.date, payIncome.date)) {
          sum += finance.expenseLocalValue(e, currency);
        }
        previousTotal = sum;
      }
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(locale.t('analisis_titulo')),
          const SizedBox(height: 12),
          if (!hasData)
            Text(locale.t('sin_datos_analisis'), style: TextStyle(color: theme.hintColor))
          else ...[
            // --- Barras de los últimos 6 meses ---
            SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (int i = 0; i < months.length; i++)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _compact(totals[i]),
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            height: maxTotal <= 0 ? 2 : (totals[i] / maxTotal * 84).clamp(2.0, 84.0).toDouble(),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: i == months.length - 1
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${months[i].month.toString().padLeft(2, '0')}/${(months[i].year % 100).toString().padLeft(2, '0')}',
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // --- Este mes vs el anterior ---
            Text(locale.t('este_mes'), style: theme.textTheme.bodySmall),
            Text(
              formatCurrency(current, finance.localCurrency),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (previous > 0)
              Builder(builder: (context) {
                final double change = (current - previous) / previous * 100;
                final bool up = change > 0;
                return Text(
                  '${up ? '▲' : '▼'} ${change.abs().toStringAsFixed(0)}% ${locale.t('vs_mes_anterior')}',
                  style: TextStyle(
                    color: up ? extras.danger : extras.success,
                    fontWeight: FontWeight.w600,
                  ),
                );
              })
            else
              Text(locale.t('sin_mes_anterior'), style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              '${locale.t('promedio_diario')}: ${formatCurrency(current / now.day, finance.localCurrency)}',
              style: theme.textTheme.bodySmall,
            ),
            if (top.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                locale.t('gastos_mayores'),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              for (final e in top)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(categoryIcon(e.category), size: 18, color: categoryColor(e.category)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatCurrency(e.amount, e.currency),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
          ],
          if (payIncome != null) ...[
            const Divider(height: 28),
            Text(
              locale.t('periodo_de_pago'),
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              '${locale.t('desde')} ${formatDateShort(payIncome.date)} · $periodDays ${locale.t('dias')}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              formatCurrency(periodSpent, finance.localCurrency),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              '${locale.t('promedio_diario')}: ${formatCurrency(periodSpent / periodDays, finance.localCurrency)}',
              style: theme.textTheme.bodySmall,
            ),
            if (previousTotal != null && previousTotal > 0)
              Builder(builder: (context) {
                final double prevTotal = previousTotal!;
                final double currentAvg = periodSpent / periodDays;
                final double previousAvg = prevTotal / previousDays;
                final double change = (currentAvg - previousAvg) / previousAvg * 100;
                final bool up = change > 0;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${up ? '▲' : '▼'} ${change.abs().toStringAsFixed(0)}% ${locale.t('vs_periodo_anterior')} '
                    '(${formatCurrency(prevTotal, finance.localCurrency)})',
                    style: TextStyle(
                      color: up ? extras.danger : extras.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }
}
