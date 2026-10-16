import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/category_style.dart';
import '../utils/formatters.dart';

/// Gastos eliminados de los últimos 30 días: se pueden restaurar.
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final List<TrashedExpense> items = finance.trashedExpenses;

    return Scaffold(
      appBar: AppBar(
        title: Text(locale.t('papelera')),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () async {
                final bool? ok = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(locale.t('vaciar_papelera')),
                    content: Text(locale.t('vaciar_papelera_mensaje')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text(locale.t('cancelar')),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: Text(locale.t('eliminar')),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  context.read<FinanceProvider>().emptyTrash();
                }
              },
              child: Text(locale.t('vaciar_papelera')),
            ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  locale.t('papelera_vacia'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.hintColor),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(locale.t('papelera_descripcion'), style: theme.textTheme.bodySmall),
                  );
                }
                final TrashedExpense item = items[index - 1];
                final e = item.expense;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: categoryColor(e.category).withValues(alpha: 0.18),
                    child: Icon(categoryIcon(e.category), color: categoryColor(e.category), size: 20),
                  ),
                  title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${formatCurrency(e.amount, e.currency)} · ${item.daysLeft} ${locale.t('dias_restantes')}',
                  ),
                  trailing: TextButton.icon(
                    onPressed: () {
                      context.read<FinanceProvider>().restoreFromTrash(e.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(locale.t('gasto_restaurado'))),
                      );
                    },
                    icon: const Icon(Icons.restore_rounded, size: 18),
                    label: Text(locale.t('restaurar')),
                  ),
                );
              },
            ),
    );
  }
}
