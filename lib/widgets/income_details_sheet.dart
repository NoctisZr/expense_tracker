import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/income.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/app_theme_extension.dart';
import '../utils/formatters.dart';
import '../utils/income_analysis.dart';
import '../utils/mod_shapes.dart';
import 'income_dialogs.dart';

Future<void> showIncomeDetailsSheet(BuildContext context, {required Income income}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _IncomeDetailsSheet(income: income),
  );
}

class _IncomeDetailsSheet extends StatelessWidget {
  final Income income;
  const _IncomeDetailsSheet({required this.income});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final currency = context.watch<CurrencyProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final extras = theme.extension<AppThemeExtras>()!;

    final Income? next = finance.nextIncomeAfter(income);
    final DateTime periodEnd = next?.date ?? DateTime.now();
    final bool periodClosed = next != null;

    final rawExpenses = finance.expensesInPeriod(income.date, next?.date);
    double totalSpent = 0;
    for (final e in rawExpenses) {
      totalSpent += currency.convert(e.amount, e.currency, income.currency);
    }

    final analysis = analyzeIncomeSpending(
      income: income,
      totalSpentInPeriod: totalSpent,
      periodEnd: periodEnd,
      periodClosed: periodClosed,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: theme.hintColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            income.label,
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(formatDateShort(income.date), style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => showAddIncomeDialog(context, existing: income),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: locale.t('editar_ingreso'),
                      visualDensity: VisualDensity.compact,
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(locale.t('cerrar')),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  formatCurrency(income.amount, income.currency),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: extras.success,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: borderRadiusApproxFor(extras.cardShapeKey, extras.cardRadius - 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv(
                        theme,
                        locale.t('gastado_hasta_ahora'),
                        '${formatCurrency(analysis.totalSpent, income.currency)} '
                        '(${formatPercent(analysis.percentSpent)})',
                        color: analysis.alreadyDepleted ? theme.colorScheme.error : null,
                      ),
                      const SizedBox(height: 10),
                      _kv(
                        theme,
                        periodClosed ? locale.t('duro') : locale.t('dias_transcurridos'),
                        '${analysis.daysElapsed} ${locale.t('dias')}',
                      ),
                      if (analysis.avgPerDay > 0) ...[
                        const SizedBox(height: 10),
                        _kv(
                          theme,
                          locale.t('ritmo_de_gasto'),
                          '${formatCurrency(analysis.avgPerDay, income.currency)} ${locale.t('por_dia')}',
                        ),
                      ],
                      if (!periodClosed && analysis.estimatedDaysUntilDepleted != null) ...[
                        const SizedBox(height: 10),
                        _kv(
                          theme,
                          locale.t('proyeccion_agotamiento'),
                          '${locale.t('aproximadamente')} '
                          '${formatDaysApprox(analysis.estimatedDaysUntilDepleted!, locale.t('dias'), locale.t('meses'))}',
                        ),
                      ],
                      if (analysis.alreadyDepleted) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 16, color: theme.colorScheme.error),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                locale.t('ingreso_agotado'),
                                style: TextStyle(color: theme.colorScheme.error, fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (rawExpenses.isEmpty) ...[
                  const SizedBox(height: 16),
                  Text(locale.t('sin_gastos_en_periodo'), style: TextStyle(color: theme.hintColor)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _kv(ThemeData theme, String label, String value, {Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }
}
