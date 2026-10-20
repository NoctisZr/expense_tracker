import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/app_theme_extension.dart';
import '../utils/category_style.dart';
import '../utils/formatters.dart';
import 'section_card.dart';

/// Vista anual: ingresos y gastos de cada mes del año elegido, totales y
/// las categorías donde más se gastó. Todo en moneda local.
class AnnualSection extends StatefulWidget {
  const AnnualSection({super.key});

  @override
  State<AnnualSection> createState() => _AnnualSectionState();
}

class _AnnualSectionState extends State<AnnualSection> {
  int _year = DateTime.now().year;

  static String _compact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final currency = context.watch<CurrencyProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final extras = theme.extension<AppThemeExtras>()!;

    final List<double> expenseByMonth = List<double>.filled(12, 0);
    final List<double> incomeByMonth = List<double>.filled(12, 0);
    final Map<String, double> byCategory = {};

    for (final Expense e in finance.expensesInPeriod(DateTime(_year), DateTime(_year + 1))) {
      final double value = finance.expenseLocalValue(e, currency);
      expenseByMonth[e.date.month - 1] += value;
      byCategory[e.category] = (byCategory[e.category] ?? 0) + value;
    }
    for (final i in finance.incomes) {
      if (i.date.year != _year) continue;
      incomeByMonth[i.date.month - 1] += currency.convert(i.amount, i.currency, finance.localCurrency);
    }

    final double totalExpenses = expenseByMonth.fold(0.0, (a, b) => a + b);
    final double totalIncome = incomeByMonth.fold(0.0, (a, b) => a + b);
    double maxValue = 0;
    for (int m = 0; m < 12; m++) {
      if (expenseByMonth[m] > maxValue) maxValue = expenseByMonth[m];
      if (incomeByMonth[m] > maxValue) maxValue = incomeByMonth[m];
    }
    final List<MapEntry<String, double>> topCategories = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SectionLabel(locale.t('vista_anual'))),
              IconButton(
                onPressed: () => setState(() => _year--),
                icon: const Icon(Icons.chevron_left_rounded),
                visualDensity: VisualDensity.compact,
              ),
              Text('$_year', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: _year >= DateTime.now().year ? null : () => setState(() => _year++),
                icon: const Icon(Icons.chevron_right_rounded),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (maxValue <= 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(locale.t('sin_datos_anio'), style: TextStyle(color: theme.hintColor)),
            )
          else ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (int m = 0; m < 12; m++)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                width: 6,
                                height: (incomeByMonth[m] / maxValue * 88).clamp(1.5, 88.0).toDouble(),
                                decoration: BoxDecoration(
                                  color: extras.success.withValues(alpha: incomeByMonth[m] > 0 ? 0.9 : 0.2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Container(
                                width: 6,
                                height: (expenseByMonth[m] / maxValue * 88).clamp(1.5, 88.0).toDouble(),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: expenseByMonth[m] > 0 ? 0.9 : 0.2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${m + 1}', style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: extras.success, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(locale.t('ingresos_del_mes'), style: theme.textTheme.bodySmall),
                const SizedBox(width: 14),
                Container(width: 10, height: 10, decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(locale.t('gastos_del_mes'), style: theme.textTheme.bodySmall),
              ],
            ),
            const Divider(height: 24),
            _row(theme, locale.t('ingresos_del_anio'), formatCurrency(totalIncome, finance.localCurrency)),
            const SizedBox(height: 4),
            _row(theme, locale.t('gastos_del_anio'), formatCurrency(totalExpenses, finance.localCurrency)),
            const SizedBox(height: 4),
            _row(theme, locale.t('ahorro_del_anio'), formatCurrency(totalIncome - totalExpenses, finance.localCurrency), bold: true),
            if (topCategories.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(locale.t('donde_mas_gastaste'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              for (final entry in topCategories.take(3))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(categoryIcon(entry.key), size: 18, color: categoryColor(entry.key)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(locale.t(categoryLabelKey(entry.key)))),
                      Text('${_compact(entry.value)} ${finance.localCurrency}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: bold ? FontWeight.bold : null))),
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
      ],
    );
  }
}
