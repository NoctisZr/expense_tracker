import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/formatters.dart';
import 'currency_dropdown.dart';

Future<void> showAddIncomeDialog(BuildContext context) {
  return showDialog(context: context, builder: (_) => const _AddIncomeDialog());
}

class _AddIncomeDialog extends StatefulWidget {
  const _AddIncomeDialog();

  @override
  State<_AddIncomeDialog> createState() => _AddIncomeDialogState();
}

class _AddIncomeDialogState extends State<_AddIncomeDialog> {
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  late String _currency;
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void initState() {
    super.initState();
    _currency = context.read<FinanceProvider>().localCurrency;
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

    context.read<FinanceProvider>().addIncome(
          label: label.isEmpty ? locale.t('sueldo_label_defecto') : label,
          amount: amount,
          currency: _currency,
          date: _date,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();

    return AlertDialog(
      title: Text(locale.t('registrar_ingreso')),
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
