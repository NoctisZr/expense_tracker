import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../models/recurring_expense.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/category_style.dart';
import '../utils/formatters.dart';
import 'category_selector_row.dart';
import 'currency_dropdown.dart';
import 'section_card.dart';

/// Texto de una frecuencia (compartido con la sección de ingresos recurrentes).
String frequencyLabel(LocaleProvider locale, String frequency) => _frequencyLabel(locale, frequency);

String _frequencyLabel(LocaleProvider locale, String frequency) {
  switch (frequency) {
    case RecurringExpense.weekly:
      return locale.t('frecuencia_semanal');
    case RecurringExpense.biweekly:
      return locale.t('frecuencia_catorcenal');
    case RecurringExpense.semimonthly:
      return locale.t('frecuencia_quincenal');
    case RecurringExpense.yearly:
      return locale.t('frecuencia_anual');
    case RecurringExpense.monthly:
    default:
      return locale.t('frecuencia_mensual');
  }
}

/// Gastos que se repiten (suscripciones, alquiler...). Se registran solos
/// como gastos normales cuando llega su fecha de cobro.
class RecurringSection extends StatelessWidget {
  const RecurringSection({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final List<RecurringExpense> items = finance.recurringExpenses;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionLabel(
                  locale.t('gastos_recurrentes'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => showRecurringDialog(context),
                icon: Icon(Icons.add_circle_outline_rounded, color: theme.colorScheme.primary),
                tooltip: locale.t('agregar_recurrente'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (items.isEmpty)
            Text(locale.t('sin_recurrentes'), style: TextStyle(color: theme.hintColor))
          else
            for (final item in items)
              _RecurringRow(item: item, locale: locale),
        ],
      ),
    );
  }
}

class _RecurringRow extends StatelessWidget {
  final RecurringExpense item;
  final LocaleProvider locale;

  const _RecurringRow({required this.item, required this.locale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color color = categoryColor(item.category);

    final String subtitle = item.paused
        ? '${_frequencyLabel(locale, item.frequency)} · ${locale.t('pausado')}'
        : '${_frequencyLabel(locale, item.frequency)} · ${locale.t('proximo_cobro')} ${formatDateShort(item.nextDue)}';

    return InkWell(
      onTap: () => showRecurringDialog(context, existing: item),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Opacity(
          opacity: item.paused ? 0.55 : 1,
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.18),
                child: Icon(categoryIcon(item.category), size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
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
                onPressed: () => context.read<FinanceProvider>().toggleRecurringPaused(item.id),
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
        title: Text(locale.t('eliminar_recurrente_titulo')),
        content: Text(locale.t('eliminar_recurrente_mensaje')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(locale.t('cancelar')),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<FinanceProvider>().deleteRecurringExpense(item.id);
              Navigator.of(dialogContext).pop();
            },
            child: Text(locale.t('eliminar')),
          ),
        ],
      ),
    );
  }
}

/// Crea un gasto recurrente o, si se pasa [existing], lo edita.
Future<void> showRecurringDialog(BuildContext context, {RecurringExpense? existing}) {
  return showDialog(
    context: context,
    builder: (_) => _RecurringDialog(existing: existing),
  );
}

class _RecurringDialog extends StatefulWidget {
  final RecurringExpense? existing;
  const _RecurringDialog({this.existing});

  @override
  State<_RecurringDialog> createState() => _RecurringDialogState();
}

class _RecurringDialogState extends State<_RecurringDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late String _category;
  late String _currency;
  late String _frequency;
  late DateTime _firstDue;

  @override
  void initState() {
    super.initState();
    final RecurringExpense? e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _amountController = TextEditingController(text: e == null ? '' : e.amount.toStringAsFixed(2));
    _category = e?.category ?? ExpenseCategory.servicios;
    _currency = e?.currency ?? context.read<FinanceProvider>().localCurrency;
    _frequency = e?.frequency ?? RecurringExpense.monthly;
    final DateTime now = DateTime.now();
    _firstDue = e?.nextDue ?? DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _nameController.dispose();
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
    final String name = _nameController.text.trim();
    final double? amount =
        double.tryParse(_amountController.text.trim().replaceAll(',', '.'));
    if (name.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(locale.t('campos_gasto_invalidos'))),
      );
      return;
    }
    final finance = context.read<FinanceProvider>();
    if (widget.existing == null) {
      finance.addRecurringExpense(
        name: name,
        amount: amount,
        currency: _currency,
        category: _category,
        frequency: _frequency,
        firstDue: _firstDue,
      );
    } else {
      finance.updateRecurringExpense(
        id: widget.existing!.id,
        name: name,
        amount: amount,
        currency: _currency,
        category: _category,
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
          ? locale.t('agregar_recurrente')
          : locale.t('editar_recurrente')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategorySelectorRow(
              selected: _category,
              locale: locale,
              onChanged: (cat) => setState(() => _category = cat),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: locale.t('nombre')),
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
                    label: Text(_frequencyLabel(locale, f), style: const TextStyle(fontSize: 12)),
                    selected: _frequency == f,
                    onSelected: (_) => setState(() => _frequency = f),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text('${locale.t('primer_cobro')}: ${formatDateShort(_firstDue)}'),
            ),
            const SizedBox(height: 8),
            Text(locale.t('recurrente_ayuda'), style: theme.textTheme.bodySmall),
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
