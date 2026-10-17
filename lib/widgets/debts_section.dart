import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/debt.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/formatters.dart';
import 'currency_dropdown.dart';
import 'section_card.dart';

/// Deudas y préstamos: lo que te deben y lo que debes. Los totales se
/// muestran en tu moneda local (solo cuentan los pendientes).
class DebtsSection extends StatelessWidget {
  const DebtsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final currency = context.watch<CurrencyProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final List<Debt> debts = finance.debts;

    double owedToMe = 0;
    double iOwe = 0;
    for (final d in debts) {
      if (d.paid) continue;
      final double value = currency.convert(d.amount, d.currency, finance.localCurrency);
      if (d.owedToMe) {
        owedToMe += value;
      } else {
        iOwe += value;
      }
    }

    // Pendientes primero, luego las saldadas.
    final List<Debt> ordered = [
      ...debts.where((d) => !d.paid),
      ...debts.where((d) => d.paid),
    ];

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionLabel(locale.t('deudas_y_prestamos'), overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                onPressed: () => showAddDebtDialog(context),
                icon: Icon(Icons.add_circle_outline_rounded, color: theme.colorScheme.primary),
                tooltip: locale.t('agregar_deuda'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (debts.isEmpty)
            Text(locale.t('sin_deudas'), style: TextStyle(color: theme.hintColor))
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '${locale.t('te_deben')}: ${formatCurrency(owedToMe, finance.localCurrency)}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${locale.t('debes')}: ${formatCurrency(iOwe, finance.localCurrency)}',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final d in ordered)
              Opacity(
                opacity: d.paid ? 0.5 : 1,
                child: Row(
                  children: [
                    Checkbox(
                      value: d.paid,
                      visualDensity: VisualDensity.compact,
                      onChanged: (_) => context.read<FinanceProvider>().toggleDebtPaid(d.id),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.person,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: d.paid ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          Text(
                            '${d.owedToMe ? locale.t('te_debe') : locale.t('le_debes')} · ${formatDateShort(d.date)}'
                            '${d.note != null ? ' · ${d.note}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatCurrency(d.amount, d.currency),
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => context.read<FinanceProvider>().deleteDebt(d.id),
                      icon: Icon(Icons.close, size: 18, color: theme.hintColor),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

Future<void> showAddDebtDialog(BuildContext context) {
  return showDialog(context: context, builder: (_) => const _AddDebtDialog());
}

class _AddDebtDialog extends StatefulWidget {
  const _AddDebtDialog();

  @override
  State<_AddDebtDialog> createState() => _AddDebtDialogState();
}

class _AddDebtDialogState extends State<_AddDebtDialog> {
  final TextEditingController _personController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  late String _currency;
  bool _owedToMe = true;

  @override
  void initState() {
    super.initState();
    _currency = context.read<FinanceProvider>().localCurrency;
  }

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final locale = context.read<LocaleProvider>();
    final String person = _personController.text.trim();
    final double? amount = double.tryParse(_amountController.text.trim().replaceAll(',', '.'));
    if (person.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(locale.t('campos_gasto_invalidos'))),
      );
      return;
    }
    context.read<FinanceProvider>().addDebt(
          person: person,
          amount: amount,
          currency: _currency,
          owedToMe: _owedToMe,
          note: _noteController.text,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();

    return AlertDialog(
      title: Text(locale.t('agregar_deuda')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: true, label: Text(locale.t('me_deben'), style: const TextStyle(fontSize: 12))),
                  ButtonSegment(value: false, label: Text(locale.t('yo_debo'), style: const TextStyle(fontSize: 12))),
                ],
                selected: {_owedToMe},
                onSelectionChanged: (selection) => setState(() => _owedToMe = selection.first),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _personController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: locale.t('persona')),
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
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: locale.t('nota_opcional')),
            ),
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
