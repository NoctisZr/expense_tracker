import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/credit_purchase.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../screens/credit_detail_screen.dart';
import '../screens/interest_calculator_screen.dart';
import '../utils/amortization.dart';
import '../utils/formatters.dart';
import 'section_card.dart';

/// Compras a crédito en cuotas: deuda pendiente, cuotas del próximo mes y
/// acceso a la calculadora de intereses.
class CreditsSection extends StatelessWidget {
  const CreditsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final currency = context.watch<CurrencyProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final List<CreditPurchase> credits = finance.credits;

    final DateTime now = DateTime.now();
    final double outstanding = finance.creditOutstandingLocal(currency);
    final double dueSoon = finance.creditInstallmentsDueLocal(currency, now, now.add(const Duration(days: 30)));

    // Activos primero, luego los ya terminados.
    final List<CreditPurchase> ordered = [
      ...credits.where((c) => !c.isFinished),
      ...credits.where((c) => c.isFinished),
    ];

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SectionLabel(locale.t('credito_cuotas'), overflow: TextOverflow.ellipsis)),
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InterestCalculatorScreen()),
                ),
                icon: Icon(Icons.calculate_outlined, color: theme.colorScheme.primary),
                tooltip: locale.t('calculadora_intereses'),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InterestCalculatorScreen(creditMode: true)),
                ),
                icon: Icon(Icons.add_circle_outline_rounded, color: theme.colorScheme.primary),
                tooltip: locale.t('nueva_compra_credito'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (credits.isEmpty)
            Text(locale.t('sin_creditos'), style: TextStyle(color: theme.hintColor))
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '${locale.t('deuda_en_cuotas')}: ${formatCurrency(outstanding, finance.localCurrency)}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${locale.t('cuotas_30_dias')}: ${formatCurrency(dueSoon, finance.localCurrency)}',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final c in ordered) _CreditTile(credit: c, locale: locale),
          ],
        ],
      ),
    );
  }
}

class _CreditTile extends StatelessWidget {
  final CreditPurchase credit;
  final LocaleProvider locale;
  const _CreditTile({required this.credit, required this.locale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final int total = credit.totalInstallments;
    final double progress = total == 0 ? 0 : credit.registeredCount / total;
    final Installment? next = credit.nextInstallment;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CreditDetailScreen(creditId: credit.id)),
      ),
      child: Opacity(
        opacity: credit.isFinished ? 0.5 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      credit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatCurrency(credit.outstanding, credit.currency),
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: progress.clamp(0.0, 1.0).toDouble(), minHeight: 6),
              const SizedBox(height: 4),
              Text(
                next == null
                    ? '${credit.registeredCount}/$total · ${locale.t('credito_terminado')}'
                    : '${credit.registeredCount}/$total · ${locale.t('proxima_cuota')}: '
                        '${formatDateShort(next.dueDate)} · ${formatCurrency(credit.amountFor(next.number), credit.currency)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
