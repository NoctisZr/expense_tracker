import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/formatters.dart';
import 'category_selector_row.dart';
import 'currency_dropdown.dart';
import 'receipt_flow.dart';

/// Diálogo para editar un gasto ya registrado (nombre, monto, divisa,
/// categoría y fecha).
Future<void> showEditExpenseDialog(BuildContext context, Expense expense) {
  return showDialog(
    context: context,
    builder: (_) => _EditExpenseDialog(expense: expense),
  );
}

class _EditExpenseDialog extends StatefulWidget {
  final Expense expense;
  const _EditExpenseDialog({required this.expense});

  @override
  State<_EditExpenseDialog> createState() => _EditExpenseDialogState();
}

class _EditExpenseDialogState extends State<_EditExpenseDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late String _currency;
  late String _category;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.expense.name);
    _amountController =
        TextEditingController(text: widget.expense.amount.toStringAsFixed(2));
    _noteController = TextEditingController(text: widget.expense.note ?? '');
    _currency = widget.expense.currency;
    _category = widget.expense.category;
    _date = widget.expense.date;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute);
    });
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
    final currencyProvider = context.read<CurrencyProvider>();

    // La foto en moneda local se conserva si monto y divisa no cambiaron;
    // si cambiaron, se recalcula con la tasa de hoy.
    double? localAmount = widget.expense.localAmount;
    String? localCurrencyAtCreation = widget.expense.localCurrencyAtCreation;
    final bool changed =
        amount != widget.expense.amount || _currency != widget.expense.currency;
    if (changed) {
      if (_currency != finance.localCurrency &&
          currencyProvider.canConvert(_currency, finance.localCurrency)) {
        localAmount = currencyProvider.convert(amount, _currency, finance.localCurrency);
        localCurrencyAtCreation = finance.localCurrency;
      } else {
        localAmount = null;
        localCurrencyAtCreation = null;
      }
    }

    finance.updateExpense(
      id: widget.expense.id,
      name: name,
      amount: amount,
      currency: _currency,
      category: _category,
      date: _date,
      note: _noteController.text,
      localAmount: localAmount,
      localCurrencyAtCreation: localCurrencyAtCreation,
      receiptPath: widget.expense.receiptPath,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();

    return AlertDialog(
      title: Text(locale.t('editar_gasto')),
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
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: locale.t('nota_opcional')),
            ),
            const SizedBox(height: 12),
            if (widget.expense.receiptPath != null) ...[
              TextButton.icon(
                onPressed: () => showReceiptViewer(context, widget.expense.receiptPath!),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: Text(locale.t('ver_recibo')),
              ),
              const SizedBox(height: 4),
            ],
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: Text(formatDateShort(_date)),
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
