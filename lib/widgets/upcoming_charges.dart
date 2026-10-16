import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recurring_expense.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/category_style.dart';
import '../utils/formatters.dart';
import 'section_card.dart';

/// Cobros recurrentes que vencen en los próximos 7 días (no se muestra si
/// no hay ninguno).
class UpcomingCharges extends StatelessWidget {
  const UpcomingCharges({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final List<RecurringExpense> due = finance.recurringDueWithin(7);
    if (due.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(locale.t('proximos_cobros')),
            const SizedBox(height: 8),
            for (final r in due)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(categoryIcon(r.category), size: 18, color: categoryColor(r.category)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(
                      '${formatDateShort(r.nextDue)} · ${formatCurrency(r.amount, r.currency)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
