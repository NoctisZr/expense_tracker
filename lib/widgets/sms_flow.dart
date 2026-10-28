import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/currency_list.dart';
import '../utils/formatters.dart';
import '../utils/sms_parser.dart';
import 'category_selector_row.dart';
import 'currency_dropdown.dart';

/// "Gasto desde un SMS": el usuario pega el mensaje del banco, se interpreta
/// (importe, comercio, fecha, moneda, gasto o ingreso) y se muestra un
/// formulario ya rellenado para revisar y guardar con un toque.
Future<void> startSmsImport(BuildContext context) {
  return showDialog(context: context, builder: (_) => const _SmsImportDialog());
}

class _SmsImportDialog extends StatefulWidget {
  const _SmsImportDialog();

  @override
  State<_SmsImportDialog> createState() => _SmsImportDialogState();
}

class _SmsImportDialogState extends State<_SmsImportDialog> {
  final TextEditingController _raw = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _amount = TextEditingController();

  bool _parsed = false;
  bool _noAmount = false;
  bool _isIncome = false;
  late String _currency;
  String _category = ExpenseCategory.compras;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currency = context.read<FinanceProvider>().localCurrency;
  }

  @override
  void dispose() {
    _raw.dispose();
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = data?.text;
    if (text == null || text.trim().isEmpty || !mounted) return;
    setState(() => _raw.text = text);
  }

  void _interpret() {
    final finance = context.read<FinanceProvider>();
    final BankMessageData d = parseBankMessage(
      _raw.text,
      defaultCurrency: finance.localCurrency,
      supportedCurrencies: kSupportedCurrencies.toSet(),
    );
    setState(() {
      _parsed = true;
      _noAmount = d.amount == null;
      _name.text = d.merchant ?? '';
      _amount.text = d.amount == null ? '' : d.amount!.toStringAsFixed(2);
      _currency = d.currency ?? finance.localCurrency;
      _category = d.categoryGuess ?? ExpenseCategory.compras;
      _date = d.date ?? DateTime.now();
      _isIncome = d.isIncome;
    });
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 366)),
    );
    if (picked != null) setState(() => _date = DateTime(picked.year, picked.month, picked.day, 12));
  }

  void _save() {
    final locale = context.read<LocaleProvider>();
    final finance = context.read<FinanceProvider>();
    final currencyProvider = context.read<CurrencyProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final String name = _name.text.trim();
    final double? amount = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0 || (!_isIncome && name.isEmpty)) {
      messenger.showSnackBar(SnackBar(content: Text(locale.t('campos_gasto_invalidos'))));
      return;
    }

    if (_isIncome) {
      finance.addIncome(
        label: name.isEmpty ? locale.t('sms_ingreso_nombre') : name,
        amount: amount,
        currency: _currency,
        date: _date,
      );
    } else {
      double? localAmount;
      if (_currency != finance.localCurrency && currencyProvider.canConvert(_currency, finance.localCurrency)) {
        localAmount = currencyProvider.convert(amount, _currency, finance.localCurrency);
      }
      finance.addExpense(
        name: name,
        amount: amount,
        currency: _currency,
        category: _category,
        date: _date,
        localAmount: localAmount,
      );
    }
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(locale.t('sms_guardado'))));
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(locale.t('sms_titulo')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_parsed) ...[
              Text(locale.t('sms_ayuda'), style: theme.textTheme.bodySmall),
              const SizedBox(height: 10),
              TextField(
                controller: _raw,
                minLines: 3,
                maxLines: 6,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: locale.t('sms_hint')),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _paste,
                  icon: const Icon(Icons.content_paste_rounded, size: 18),
                  label: Text(locale.t('sms_pegar')),
                ),
              ),
            ] else ...[
              Text(
                _noAmount ? locale.t('sms_sin_importe') : locale.t('sms_revisa'),
                style: theme.textTheme.bodySmall?.copyWith(color: _noAmount ? theme.colorScheme.error : null),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(locale.t('sms_es_ingreso')),
                value: _isIncome,
                onChanged: (v) => setState(() => _isIncome = v),
              ),
              if (!_isIncome) ...[
                CategorySelectorRow(
                  selected: _category,
                  locale: locale,
                  onChanged: (cat) => setState(() => _category = cat),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: locale.t('nombre')),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: locale.t('monto')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CurrencyDropdown(value: _currency, dense: true, onChanged: (v) => setState(() => _currency = v)),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: Text(formatDateShort(_date)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(locale.t('cancelar'))),
        if (!_parsed)
          ElevatedButton(
            onPressed: _raw.text.trim().isEmpty ? null : _interpret,
            child: Text(locale.t('sms_interpretar')),
          )
        else
          ElevatedButton(onPressed: _save, child: Text(locale.t('guardar'))),
      ],
    );
  }
}
