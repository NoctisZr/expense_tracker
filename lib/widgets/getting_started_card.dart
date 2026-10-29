import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import 'section_card.dart';

/// Lista de "primeros pasos" para quien empieza: se completa sola según lo
/// que ya hiciste y desaparece al terminar (o al tocar «Ocultar»).
class GettingStartedCard extends StatelessWidget {
  const GettingStartedCard({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    if (finance.gettingStartedDismissed || finance.expenses.length >= 20) return const SizedBox.shrink();

    final List<(String, bool)> steps = [
      (locale.t('paso_cuenta'), finance.accounts.isNotEmpty),
      (locale.t('paso_gasto'), finance.expenses.isNotEmpty),
      (locale.t('paso_ingreso'), finance.incomes.isNotEmpty),
      (
        locale.t('paso_presupuesto'),
        finance.budgets.isNotEmpty || finance.weeklyBudget > 0 || finance.envelopes.isNotEmpty,
      ),
    ];
    final int done = steps.where((s) => s.$2).length;
    if (done == steps.length) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SectionLabel(locale.t('primeros_pasos'))),
                Text('$done/${steps.length}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: done / steps.length,
              minHeight: 6,
              semanticsLabel: '${locale.t('primeros_pasos')} $done/${steps.length}',
            ),
            const SizedBox(height: 8),
            for (final step in steps)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      step.$2 ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: step.$2 ? theme.colorScheme.primary : theme.hintColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        step.$1,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          decoration: step.$2 ? TextDecoration.lineThrough : null,
                          color: step.$2 ? theme.hintColor : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.read<FinanceProvider>().dismissGettingStarted(),
                child: Text(locale.t('ocultar')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
