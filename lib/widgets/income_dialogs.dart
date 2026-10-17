import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/income.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/formatters.dart';
import 'currency_dropdown.dart';

/// Registra un ingreso o, si se pasa [existing], lo edita.
Future<void> showAddIncomeDialog(BuildContext context, {Income? existing}) {
  return showDialog(context: context, builder: (_) => _AddIncomeDialog(existing: existing));
}

class _AddIncomeDialog extends StatefulWidget {
  final Income? existing;
  const _AddIncomeDialog({this.existing});

  @override
  State<_AddIncomeDialog> createState() => _AddIncomeDialogState();
}

class _AddIncomeDialogState extends State<_AddIncomeDialog> {
  late final TextEditingController _labelController;
  late final TextEditingController _amountController;
  late String _currency;
  late DateTime _date;
  String? _error;

  @override
  void initState() {
    super.initState();
    final Income? i = widget.existing;
    _labelController = TextEditingController(text: i?.label ?? '');
    _amountController =
        TextEditingController(text: i == null ? '' : i.amount.toStringAsFixed(2));
    _currency = i?.currency ?? context.read<FinanceProvider>().localCurrency;
    _date = i?.date ?? DateTime.now();
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
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    final locale = context.read<LocaleProvider>();
    final String label = _labelController.text.trim();
    final double? amount =
        double.tryParse(_amountController.text.trim().replaceAll(',', '.'));

    if (amount == null || amount <= 0) {
      setState(() => _error = locale.t('campos_ingreso_invalidos'));
      return;
    }

    final finance = context.read<FinanceProvider>();
    final String finalLabel = label.isEmpty ? locale.t('sueldo_label_defecto') : label;
    if (widget.existing == null) {
      finance.addIncome(
        label: finalLabel,
        amount: amount,
        currency: _currency,
        date: _date,
      );
    } else {
      finance.updateIncome(
        id: widget.existing!.id,
        label: finalLabel,
        amount: amount,
        currency: _currency,
        date: _date,
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();

    return AlertDialog(
      title: Text(widget.existing == null ? locale.t('registrar_ingreso') : locale.t('editar_ingreso')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _labelController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: locale.t('etiqueta_ingreso'),
                hintText: locale.t('sueldo_label_defecto'),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: '${locale.t('monto')} ($_currency)'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(locale.t('divisa_objetivo')),
                CurrencyDropdown(
                  value: _currency,
                  onChanged: (value) => setState(() => _currency = value),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(locale.t('fecha_del_pago')),
                    Text(
                      formatDateShort(_date),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(locale.t('cancelar')),
        ),
        ElevatedButton(onPressed: _submit, child: Text(locale.t('confirmar'))),
      ],
    );
  }
}
