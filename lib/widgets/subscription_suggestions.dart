import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/formatters.dart';
import '../utils/recurring_detector.dart';
import 'recurring_section.dart' show frequencyLabel;
import 'section_card.dart';

/// Sugiere convertir en recurrentes los gastos que se repiten solos. No se
/// dibuja si no hay sugerencias.
class SubscriptionSuggestions extends StatelessWidget {
  const SubscriptionSuggestions({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    final Set<String> existing =
        finance.recurringExpenses.map((r) => r.name.trim().toLowerCase()).toSet();
    final List<RecurringSuggestion> suggestions = detectRecurringPatterns(
      finance.expenses,
      existingNames: existing,
      ignoredNames: finance.ignoredSubscriptionNames,
    ).take(3).toList();
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(locale.t('suscripciones_detectadas')),
            const SizedBox(height: 4),
            Text(locale.t('suscripciones_ayuda'), style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            for (final s in suggestions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.autorenew_rounded, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                          Text(
                            '${formatCurrency(s.amount, s.currency)} · ${frequencyLabel(locale, s.frequency)} · ${s.occurrences}×',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.read<FinanceProvider>().addRecurringExpense(
                            name: s.name,
                            amount: s.amount,
                            currency: s.currency,
                            category: s.category,
                            frequency: s.frequency,
                            firstDue: s.nextDue,
                          ),
                      child: Text(locale.t('crear')),
                    ),
                    IconButton(
                      onPressed: () => context.read<FinanceProvider>().ignoreSubscription(s.name),
                      icon: Icon(Icons.close, size: 18, color: theme.hintColor),
                      tooltip: locale.t('ignorar'),
                      visualDensity: VisualDensity.compact,
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
