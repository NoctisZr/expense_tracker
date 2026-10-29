import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/formatters.dart';
import 'section_card.dart';

/// Gastos en pareja: saldo (quién le debe a quién) y últimos gastos
/// compartidos. En la 2.0 aquí también aparecerán los de tu pareja.
class CoupleSection extends StatelessWidget {
  const CoupleSection({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final currency = context.watch<CurrencyProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    final List<Expense> shared = finance.sharedExpenses;
    final double balance = finance.coupleBalanceLocal(currency);
    final String local = finance.localCurrency;

    String headline;
    Color? color;
    if (balance > 0.004) {
      headline = '${locale.t('pareja_te_debe')} ${formatCurrency(balance, local)}';
      color = theme.colorScheme.primary;
    } else if (balance < -0.004) {
      headline = '${locale.t('pareja_le_debes')} ${formatCurrency(-balance, local)}';
      color = theme.colorScheme.error;
    } else {
      headline = locale.t('pareja_a_mano');
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(locale.t('pareja_titulo')),
          const SizedBox(height: 6),
          if (shared.isEmpty)
            Text(locale.t('pareja_vacio'), style: TextStyle(color: theme.hintColor))
          else ...[
            Text(
              headline,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 8),
            for (final e in shared.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.favorite_rounded, size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                          Text(
                            '${formatDateShort(e.date)} · ${locale.t('total_cuenta')} ${formatAmount(e.sharedTotal ?? e.amount)} · '
                            '${locale.t('mi_parte')} ${formatAmount(e.amount)} · '
                            '${e.paidByCreator ? locale.t('quien_pago_yo') : locale.t('quien_pago_pareja')}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 8),
          Text(locale.t('pareja_sync_pronto'), style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
