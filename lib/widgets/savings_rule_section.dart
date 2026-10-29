import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/formatters.dart';
import 'section_card.dart';

/// Regla de ahorro: reserva un % de los ingresos del mes y muestra cuánto
/// puedes gastar todavía sin romper esa meta.
class SavingsRuleSection extends StatelessWidget {
  const SavingsRuleSection({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final currency = context.watch<CurrencyProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    final double pct = finance.savingsRulePct;
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month, 1);
    final DateTime end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final double income = finance.incomeInRangeLocal(currency, start, end);
    final double spent = finance.expensesInRangeLocal(currency, start, end);
    final String local = finance.localCurrency;

    final double target = income * pct / 100;
    final double saved = income - spent;
    final double spendable = income - target - spent;
    final double progress = target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0).toDouble();

    Widget row(String label, String value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(label, style: theme.textTheme.bodyMedium)),
              const SizedBox(width: 8),
              Text(value,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
            ],
          ),
        );

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(locale.t('regla_ahorro')),
          const SizedBox(height: 4),
          Text(
            pct <= 0 ? locale.t('regla_ahorro_ayuda') : '${locale.t('regla_ahorro_activa')} ${pct.round()} %',
            style: theme.textTheme.bodySmall,
          ),
          Slider(
            value: pct.clamp(0.0, 50.0).toDouble(),
            min: 0,
            max: 50,
            divisions: 10,
            label: pct <= 0 ? locale.t('regla_desactivada') : '${pct.round()} %',
            onChanged: (value) => context.read<FinanceProvider>().setSavingsRulePct(value),
          ),
          if (pct > 0) ...[
            if (income <= 0)
              Text(locale.t('regla_sin_ingresos'), style: TextStyle(color: theme.hintColor))
            else ...[
              row(locale.t('ingresos_del_mes'), formatCurrency(income, local)),
              row(locale.t('meta_ahorro'), formatCurrency(target, local)),
              row(locale.t('ahorrado_hasta_ahora'), formatCurrency(saved < 0 ? 0 : saved, local)),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: progress, minHeight: 8),
              const SizedBox(height: 8),
              Text(
                spendable >= 0
                    ? '${locale.t('puedes_gastar')} ${formatCurrency(spendable, local)}'
                    : '${locale.t('te_pasaste')} ${formatCurrency(-spendable, local)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: spendable >= 0 ? null : theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
