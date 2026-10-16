import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/category_style.dart';
import '../utils/formatters.dart';
import 'section_card.dart';

/// Resumen de gastos por categoría: el usuario elige entre ver el total
/// de cada categoría por separado (con barra proporcional) o un único
/// total combinado. El título y el selector van en filas separadas
/// (no compitiendo por espacio horizontal) para que nunca se aplaste el
/// texto en pantallas angostas.
class CategorySummary extends StatefulWidget {
  const CategorySummary({super.key});

  @override
  State<CategorySummary> createState() => _CategorySummaryState();
}

class _CategorySummaryState extends State<CategorySummary> {
  bool _combined = false;

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final currency = context.watch<CurrencyProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    final Map<String, Map<String, double>> raw = finance.totalExpensesByCategoryAndCurrency();

    final Map<String, double> totals = {};
    for (final cat in ExpenseCategory.all) {
      double sum = 0;
      (raw[cat] ?? const {}).forEach((code, amount) {
        sum += currency.convert(amount, code, finance.localCurrency);
      });
      totals[cat] = sum;
    }
    final double grandTotal = totals.values.fold(0.0, (a, b) => a + b);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(locale.t('resumen_categorias')),
          if (grandTotal > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(locale.t('por_categoria')),
                    icon: const Icon(Icons.donut_small_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(locale.t('total_combinado')),
                    icon: const Icon(Icons.functions_rounded, size: 16),
                  ),
                ],
                selected: {_combined},
                onSelectionChanged: (s) => setState(() => _combined = s.first),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: theme.colorScheme.primary,
                  selectedForegroundColor: theme.colorScheme.onPrimary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (grandTotal <= 0)
            Text(locale.t('sin_gastos'), style: TextStyle(color: theme.hintColor))
          else if (_combined)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Column(
                  children: [
                    Text(locale.t('total_gastado'), style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      formatCurrency(grandTotal, finance.localCurrency),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: ExpenseCategory.all.map((cat) {
                final double amount = totals[cat] ?? 0;
                final double pct = grandTotal > 0 ? amount / grandTotal : 0.0;
                final Color color = categoryColor(cat);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(categoryIcon(cat), size: 16, color: color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(locale.t(categoryLabelKey(cat)), style: theme.textTheme.bodyMedium),
                          ),
                          Text(
                            formatCurrency(amount, finance.localCurrency),
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 6,
                          backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(formatPercent(pct * 100), style: theme.textTheme.bodySmall),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
