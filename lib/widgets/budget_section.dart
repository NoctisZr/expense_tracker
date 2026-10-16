import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/app_colors.dart';
import '../utils/budget_utils.dart';
import '../utils/category_style.dart';
import '../utils/formatters.dart';
import 'section_card.dart';

/// Presupuesto mensual por categoría, en la moneda local. Muestra una
/// barra por categoría con presupuesto y avisa al llegar al 80 % y al
/// pasarse del 100 %.
class BudgetSection extends StatelessWidget {
  const BudgetSection({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final currency = context.watch<CurrencyProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    final Map<String, double> budgets = finance.budgets;
    final List<String> budgetedCategories =
        ExpenseCategory.all.where((c) => budgets.containsKey(c)).toList();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionLabel(
                  locale.t('presupuesto_mensual'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => showEditBudgetsDialog(context),
                icon: Icon(Icons.tune_rounded, color: theme.colorScheme.primary),
                tooltip: locale.t('editar_presupuestos'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (budgetedCategories.isEmpty)
            Text(locale.t('sin_presupuestos'), style: TextStyle(color: theme.hintColor))
          else
            for (final cat in budgetedCategories)
              _BudgetRow(
                category: cat,
                limit: budgets[cat]!,
                spent: monthSpentLocal(finance, currency, cat),
                currencyCode: finance.localCurrency,
                locale: locale,
              ),
          if (budgetedCategories.length > 1) ...[
            const Divider(height: 24),
            Builder(builder: (context) {
              double totalLimit = 0;
              double totalSpent = 0;
              for (final cat in budgetedCategories) {
                totalLimit += budgets[cat]!;
                totalSpent += monthSpentLocal(finance, currency, cat);
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(locale.t('presupuesto_total'),
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text(
                    '${formatAmount(totalSpent)} / ${formatCurrency(totalLimit, finance.localCurrency)}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final String category;
  final double limit;
  final double spent;
  final String currencyCode;
  final LocaleProvider locale;

  const _BudgetRow({
    required this.category,
    required this.limit,
    required this.spent,
    required this.currencyCode,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double fraction = limit <= 0 ? 0 : spent / limit;
    final Color baseColor = categoryColor(category);
    final Color barColor = fraction >= 1
        ? theme.colorScheme.error
        : fraction >= 0.8
            ? AppColors.expenseColor
            : baseColor;

    final String status;
    if (fraction >= 1) {
      status = '${locale.t('presupuesto_excedido')} ${formatCurrency(spent - limit, currencyCode)}';
    } else {
      status = '${locale.t('presupuesto_restante')} ${formatCurrency(limit - spent, currencyCode)}';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(categoryIcon(category), size: 18, color: baseColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  locale.t(categoryLabelKey(category)),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${formatAmount(spent)} / ${formatCurrency(limit, currencyCode)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: theme.textTheme.bodySmall?.copyWith(
              color: fraction >= 1 ? theme.colorScheme.error : null,
              fontWeight: fraction >= 0.8 ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showEditBudgetsDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const _EditBudgetsDialog(),
  );
}

class _EditBudgetsDialog extends StatefulWidget {
  const _EditBudgetsDialog();

  @override
  State<_EditBudgetsDialog> createState() => _EditBudgetsDialogState();
}

class _EditBudgetsDialogState extends State<_EditBudgetsDialog> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    final Map<String, double> budgets = context.read<FinanceProvider>().budgets;
    for (final cat in ExpenseCategory.all) {
      final double? value = budgets[cat];
      _controllers[cat] = TextEditingController(
        text: value == null ? '' : value.toStringAsFixed(2),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final Map<String, double> result = {};
    _controllers.forEach((cat, controller) {
      final double? value =
          double.tryParse(controller.text.trim().replaceAll(',', '.'));
      if (value != null && value > 0) result[cat] = value;
    });
    context.read<FinanceProvider>().setBudgets(result);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final finance = context.watch<FinanceProvider>();

    return AlertDialog(
      title: Text(locale.t('editar_presupuestos')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${locale.t('presupuesto_ayuda')} (${finance.localCurrency})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final cat in ExpenseCategory.all)
              TextField(
                controller: _controllers[cat],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: locale.t(categoryLabelKey(cat)),
                  prefixIcon: Icon(categoryIcon(cat), color: categoryColor(cat), size: 20),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(locale.t('cancelar')),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(locale.t('guardar')),
        ),
      ],
    );
  }
}
