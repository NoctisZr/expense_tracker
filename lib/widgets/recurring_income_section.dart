import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recurring_expense.dart';
import '../models/recurring_income.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/formatters.dart';
import 'currency_dropdown.dart';
import 'recurring_section.dart' show frequencyLabel;
import 'section_card.dart';

/// Ingresos que se repiten (sueldo semanal, quincenal, mensual...). Se
/// registran solos como ingresos cuando llega la fecha de pago.
class RecurringIncomeSection extends StatelessWidget {
  const RecurringIncomeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final List<RecurringIncome> items = finance.recurringIncomes;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionLabel(
                  locale.t('ingresos_recurrentes'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => showRecurringIncomeDialog(context),
                icon: Icon(Icons.add_circle_outline_rounded, color: theme.colorScheme.primary),
                tooltip: locale.t('agregar_ingreso_recurrente'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (items.isEmpty)
            Text(locale.t('sin_ingresos_recurrentes'), style: TextStyle(color: theme.hintColor))
          else
            for (final item in items) _IncomeRow(item: item, locale: locale),
        ],
      ),
    );
  }
}

class _IncomeRow extends StatelessWidget {
  final RecurringIncome item;
  final LocaleProvider locale;

  const _IncomeRow({required this.item, required this.locale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String subtitle = item.paused
        ? '${frequencyLabel(locale, item.frequency)} · ${locale.t('pausado')}'
        : '${frequencyLabel(locale, item.frequency)} · ${locale.t('proximo_cobro')} ${formatDateShort(item.nextDue)}';

    return InkWell(
      onTap: () => showRecurringIncomeDialog(context, existing: item),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Opacity(
          opacity: item.paused ? 0.55 : 1,
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                child: Icon(Icons.payments_outlined, size: 18, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatCurrency(item.amount, item.currency),
                    maxLines: 1,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => context.read<FinanceProvider>().toggleRecurringIncomePaused(item.id),
                icon: Icon(
                  item.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  size: 20,
                  color: theme.hintColor,
                ),
                tooltip: item.paused ? locale.t('reanudar') : locale.t('pausar'),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: () => _confirmDelete(context),
                icon: Icon(Icons.close, size: 18, color: theme.hintColor),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(locale.t('eliminar_ingreso_recurrente_titulo')),
        content: Text(locale.t('eliminar_ingreso_recurrente_mensaje')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(locale.t('cancelar')),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<FinanceProvider>().deleteRecurringIncome(item.id);
              Navigator.of(dialogContext).pop();
            },
            child: Text(locale.t('eliminar')),
          ),
        ],
      ),
    );
  }
}

/// Crea un ingreso recurrente o, si se pasa [existing], lo edita.
Future<void> showRecurringIncomeDialog(BuildContext context, {RecurringIncome? existing}) {
  return showDialog(
    context: context,
    builder: (_) => _RecurringIncomeDialog(existing: existing),
  );
}

class _RecurringIncomeDialog extends StatefulWidget {
  final RecurringIncome? existing;
  const _RecurringIncomeDialog({this.existing});

  @override
  State<_RecurringIncomeDialog> createState() => _RecurringIncomeDialogState();
}

class _RecurringIncomeDialogState extends State<_RecurringIncomeDialog> {
  late final TextEditingController _labelController;
  late final TextEditingController _amountController;
  late String _currency;
  late String _frequency;
  late DateTime _firstDue;

  @override
  void initState() {
    super.initState();
    final RecurringIncome? e = widget.existing;
    _labelController = TextEditingController(text: e?.label ?? '');
    _amountController = TextEditingController(text: e == null ? '' : e.amount.toStringAsFixed(2));
    _currency = e?.currency ?? context.read<FinanceProvider>().localCurrency;
    _frequency = e?.frequency ?? RecurringExpense.monthly;
    final DateTime now = DateTime.now();
    _firstDue = e?.nextDue ?? DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _firstDue,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _firstDue = picked);
  }

  void _save() {
    final locale = context.read<LocaleProvider>();
    final String label = _labelController.text.trim();
    final double? amount = double.tryParse(_amountController.text.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(locale.t('campos_gasto_invalidos'))),
      );
      return;
    }
    final finance = context.read<FinanceProvider>();
    final String finalLabel = label.isEmpty ? locale.t('sueldo_label_defecto') : label;
    if (widget.existing == null) {
      finance.addRecurringIncome(
        label: finalLabel,
        amount: amount,
        currency: _currency,
        frequency: _frequency,
        firstDue: _firstDue,
      );
    } else {
      finance.updateRecurringIncome(
        id: widget.existing!.id,
        label: finalLabel,
        amount: amount,
        currency: _currency,
        frequency: _frequency,
        nextDue: _firstDue,
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.existing == null
          ? locale.t('agregar_ingreso_recurrente')
          : locale.t('editar_ingreso_recurrente')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _labelController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: locale.t('concepto_ingreso')),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: locale.t('monto')),
                  ),
                ),
                const SizedBox(width: 10),
                CurrencyDropdown(
                  value: _currency,
                  dense: true,
                  onChanged: (value) => setState(() => _currency = value),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final f in RecurringExpense.frequencies)
                  ChoiceChip(
                    label: Text(frequencyLabel(locale, f), style: const TextStyle(fontSize: 12)),
                    selected: _frequency == f,
                    onSelected: (_) => setState(() => _frequency = f),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text('${locale.t('primer_pago')}: ${formatDateShort(_firstDue)}'),
            ),
            const SizedBox(height: 8),
            Text(locale.t('ingreso_recurrente_ayuda'), style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(locale.t('cancelar')),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(locale.t('guardar')),
        ),
      ],
    );
  }
}
