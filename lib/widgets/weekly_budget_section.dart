import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/formatters.dart';
import '../utils/weekly_budget.dart';
import 'section_card.dart';

/// Presupuesto semanal (lunes a domingo): cuánto llevas, cuánto te queda y
/// cuánto puedes gastar por día lo que resta de la semana.
class WeeklyBudgetSection extends StatelessWidget {
  const WeeklyBudgetSection({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final currency = context.watch<CurrencyProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    final double budget = finance.weeklyBudget;
    final DateTime now = DateTime.now();
    final DateTime start = weekStartOf(now);
    final DateTime end = weekEndOf(start);
    final double spent = finance.expensesInRangeLocal(currency, start, end);
    final WeekStatus status = weekStatus(now: now, budget: budget, spent: spent);
    final String local = finance.localCurrency;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SectionLabel(locale.t('presupuesto_semanal'))),
              IconButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => _WeeklyBudgetDialog(current: budget),
                ),
                icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                tooltip: locale.t('editar'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (budget <= 0)
            Text(locale.t('semanal_ayuda'), style: TextStyle(color: theme.hintColor))
          else ...[
            LinearProgressIndicator(
              value: status.progress,
              minHeight: 8,
              semanticsLabel: '${locale.t('presupuesto_semanal')} ${(status.progress * 100).round()} %',
              color: status.over ? theme.colorScheme.error : null,
            ),
            const SizedBox(height: 8),
            Text(
              '${formatCurrency(spent, local)} / ${formatCurrency(budget, local)}',
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (status.over)
              Text(
                '${locale.t('semanal_te_pasaste')} ${formatCurrency(-status.remaining, local)}',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.w600),
              )
            else ...[
              Text('${locale.t('semanal_te_quedan')} ${formatCurrency(status.remaining, local)}',
                  style: theme.textTheme.bodyMedium),
              Text(
                '${locale.t('semanal_por_dia')} ${formatCurrency(status.perDayLeft, local)} · ${status.daysLeft} ${locale.t('semanal_dias')}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (status.overPace) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.speed_rounded, size: 16, color: theme.colorScheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(locale.t('semanal_ritmo'),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _WeeklyBudgetDialog extends StatefulWidget {
  final double current;
  const _WeeklyBudgetDialog({required this.current});

  @override
  State<_WeeklyBudgetDialog> createState() => _WeeklyBudgetDialogState();
}

class _WeeklyBudgetDialogState extends State<_WeeklyBudgetDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.current > 0 ? widget.current.toStringAsFixed(2) : '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final finance = context.read<FinanceProvider>();
    return AlertDialog(
      title: Text(locale.t('presupuesto_semanal')),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: '${locale.t('monto')} (${finance.localCurrency})',
          helperText: locale.t('semanal_quitar_ayuda'),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(locale.t('cancelar'))),
        ElevatedButton(
          onPressed: () {
            final double value = double.tryParse(_controller.text.trim().replaceAll(',', '.')) ?? 0;
            finance.setWeeklyBudget(value);
            Navigator.of(context).pop();
          },
          child: Text(locale.t('guardar')),
        ),
      ],
    );
  }
}
