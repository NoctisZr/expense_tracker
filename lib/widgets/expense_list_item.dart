import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/category_style.dart';
import '../utils/formatters.dart';
import '../utils/tag_utils.dart';
import 'expense_dialogs.dart';

/// Muestra el diálogo de confirmación para eliminar un gasto y, si se
/// confirma, lo borra de FinanceProvider.
Future<void> confirmDeleteExpense(BuildContext context, String expenseId) {
  final locale = context.read<LocaleProvider>();
  return showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(locale.t('eliminar_gasto_titulo')),
      content: Text(locale.t('eliminar_gasto_mensaje')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(locale.t('cancelar')),
        ),
        ElevatedButton(
          onPressed: () {
            context.read<FinanceProvider>().deleteExpense(expenseId);
            Navigator.of(dialogContext).pop();
          },
          child: Text(locale.t('eliminar')),
        ),
      ],
    ),
  );
}

class ExpenseListItem extends StatelessWidget {
  final Expense expense;
  final LocaleProvider locale;
  final VoidCallback onDelete;

  /// Si es null, tocar el gasto abre el diálogo de edición.
  final VoidCallback? onTap;

  const ExpenseListItem({
    super.key,
    required this.expense,
    required this.locale,
    required this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color color = categoryColor(expense.category);
    final String localCurrency = context.watch<FinanceProvider>().localCurrency;
    final bool showHistoricalLocal = expense.localAmount != null &&
        expense.localCurrencyAtCreation == localCurrency &&
        expense.currency != localCurrency;

    return InkWell(
      onTap: onTap ?? () => showEditExpenseDialog(context, expense),
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: 0.18),
            child: Icon(categoryIcon(expense.category), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.receiptPath != null ? '🧾 ${expense.name}' : expense.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${locale.t(categoryLabelKey(expense.category))} · ${formatDateShort(expense.date)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                if (expense.tags != null && expense.tags!.isNotEmpty)
                  Text(
                    tagsToText(expense.tags),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                  ),
                if (expense.note != null && expense.note!.isNotEmpty)
                  Text(
                    expense.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatCurrency(expense.amount, expense.currency),
                    maxLines: 1,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (showHistoricalLocal)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '≈ ${formatCurrency(expense.localAmount!, localCurrency)}',
                      maxLines: 1,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.close, size: 18, color: theme.hintColor),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      ),
    );
  }
}
