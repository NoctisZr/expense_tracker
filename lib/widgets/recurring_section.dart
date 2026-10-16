import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../models/recurring_expense.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/category_style.dart';
import '../utils/formatters.dart';
import 'category_selector_row.dart';
import 'currency_dropdown.dart';
import 'section_card.dart';

/// Gastos que se repiten cada mes (suscripciones, alquiler...). Se
/// registran solos como gastos normales cuando llega su día de cobro.
class RecurringSection extends StatelessWidget {
  const RecurringSection({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final List<RecurringExpense> items = finance.recurringExpenses;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionLabel(
                  locale.t('gastos_recurrentes'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => showAddRecurringDialog(context),
                icon: Icon(Icons.add_circle_outline_rounded, color: theme.colorScheme.primary),
                tooltip: locale.t('agregar_recurrente'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (items.isEmpty)
            Text(locale.t('sin_recurrentes'), style: TextStyle(color: theme.hintColor))
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: categoryColor(item.category).withValues(alpha: 0.18),
                      child: Icon(categoryIcon(item.category),
                          size: 18, color: categoryColor(item.category)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${locale.t('cada_mes_el_dia')} ${item.dayOfMonth}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          formatCurrency(item.amount, item.currency),
                          maxLines: 1,
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _confirmDelete(context, item, locale),
                      icon: Icon(Icons.close, size: 18, color: theme.hintColor),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, RecurringExpense item, LocaleProvider locale) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(locale.t('eliminar_recurrente_titulo')),
        content: Text(locale.t('eliminar_recurrente_mensaje')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(locale.t('cancelar')),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<FinanceProvider>().deleteRecurringExpense(item.id);
              Navigator.of(dialogContext).pop();
            },
            child: Text(locale.t('eliminar')),
          ),
        ],
      ),
    );
  }
}

Future<void> showAddRecurringDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const _AddRecurringDialog(),
  );
}

class _AddRecurringDialog extends StatefulWidget {
  const _AddRecurringDialog();

  @override
  State<_AddRecurringDialog> createState() => _AddRecurringDialogState();
}

class _AddRecurringDialogState extends State<_AddRecurringDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String _category = ExpenseCategory.servicios;
  late String _currency;
  int _day = DateTime.now().day;

  @override
  void initState() {
    super.initState();
    _currency = context.read<FinanceProvider>().localCurrency;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    final locale = context.read<LocaleProvider>();
    final String name = _nameController.text.trim();
    final double? amount =
        double.tryParse(_amountController.text.trim().replaceAll(',', '.'));
    if (name.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(locale.t('campos_gasto_invalidos'))),
      );
      return;
    }
    context.read<FinanceProvider>().addRecurringExpense(
          name: name,
          amount: amount,
          currency: _currency,
          category: _category,
          dayOfMonth: _day,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(locale.t('agregar_recurrente')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategorySelectorRow(
              selected: _category,
              locale: locale,
              onChanged: (cat) => setState(() => _category = cat),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: locale.t('nombre')),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: locale.t('monto')),
                  ),
                ),
                const SizedBox(width: 10),
                CurrencyDropdown(
                  value: _currency,
                  dense: true,
                  onChanged: (value) => setState(() => _currency = value),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: Text(locale.t('cada_mes_el_dia'))),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _day,
                    dropdownColor: theme.colorScheme.surface,
                    items: [
                      for (int d = 1; d <= 31; d++)
                        DropdownMenuItem<int>(value: d, child: Text('$d')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _day = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(locale.t('recurrente_ayuda'), style: theme.textTheme.bodySmall),
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
