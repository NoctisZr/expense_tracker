import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/formatters.dart';
import 'section_card.dart';

/// Cuenta regresiva al próximo pago (del ingreso recurrente más cercano o
/// estimado con el intervalo típico entre tus últimos pagos). No se muestra
/// si no hay forma de saberlo.
class NextPaymentCard extends StatelessWidget {
  const NextPaymentCard({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final NextPayment? next = finance.nextExpectedPayment();
    if (next == null) return const SizedBox.shrink();

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime day = DateTime(next.date.year, next.date.month, next.date.day);
    final int days = day.difference(today).inDays;

    final String headline;
    if (days <= 0) {
      headline = locale.t('pago_hoy');
    } else if (days == 1) {
      headline = locale.t('pago_manana');
    } else {
      headline = '${locale.t('pago_en')} $days ${locale.t('dias')}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: SectionCard(
        child: Row(
          children: [
            Icon(Icons.event_available_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(headline, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text(
                    '${locale.t('proximo_pago')}: ${formatDateShort(next.date)}'
                    '${next.estimated ? ' · ${locale.t('estimado')}' : ''}',
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
