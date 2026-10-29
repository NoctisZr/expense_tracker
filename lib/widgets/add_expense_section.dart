import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/budget_utils.dart';
import '../utils/formatters.dart';
import '../utils/tag_utils.dart';
import 'account_widgets.dart';
import 'category_selector_row.dart';
import 'currency_dropdown.dart';
import 'receipt_flow.dart';
import 'sms_flow.dart';
import '../screens/interest_calculator_screen.dart';
import 'section_card.dart';

class AddExpenseSection extends StatefulWidget {
  const AddExpenseSection({super.key});

  @override
  State<AddExpenseSection> createState() => _AddExpenseSectionState();
}

class _AddExpenseSectionState extends State<AddExpenseSection> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  String? _accountId;
  String _category = ExpenseCategory.compras;
  late String _currency;
  DateTime _date = DateTime.now();
  int _splitCount = 1;
  bool _splitCreateDebt = true;
  bool _coupleShared = false;
  bool _paidByMe = true;
  double _myShare = 50;

  @override
  void initState() {
    super.initState();
    final finance = context.read<FinanceProvider>();
    _currency = finance.localCurrency;
    _accountId = finance.lastAccountId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _tagsController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  bool get _isToday {
    final DateTime now = DateTime.now();
    return _date.year == now.year && _date.month == now.month && _date.day == now.day;
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 366)),
    );
    if (picked == null) return;
    setState(() {
      // Se conserva la hora actual para que el orden dentro del día sea natural.
      _date = DateTime(picked.year, picked.month, picked.day, now.hour, now.minute);
    });
  }

  void _submit() {
    final locale = context.read<LocaleProvider>();
    final String name = _nameController.text.trim();
    final double? total =
        double.tryParse(_amountController.text.trim().replaceAll(',', '.'));

    if (name.isEmpty || total == null || total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(locale.t('campos_gasto_invalidos'))),
      );
      return;
    }

    final finance = context.read<FinanceProvider>();
    final currencyProvider = context.read<CurrencyProvider>();
    final String addedCategory = _category;

    // Gasto compartido: se registra solo TU parte y, si se desea, lo que
    // los demás te deben queda como deuda.
    double amount = total;
    String note = _noteController.text.trim();
    final int split = _coupleShared ? 1 : _splitCount;
    if (split > 1) {
      amount = double.parse((total / split).toStringAsFixed(2));
      final String splitNote = '${locale.t('total_cuenta')} ${formatAmount(total)} ÷ $split';
      note = note.isEmpty ? splitNote : '$note · $splitNote';
    }

    // Gasto en pareja: se guarda el total de la cuenta y solo TU parte como importe.
    double? sharedTotal;
    if (_coupleShared) {
      sharedTotal = total;
      amount = double.parse((total * _myShare / 100).toStringAsFixed(2));
    }

    // Foto del equivalente en moneda local con la tasa de hoy (solo si la
    // divisa del gasto es distinta de la local y hay tasas para ambas).
    double? localAmount;
    if (_currency != finance.localCurrency &&
        currencyProvider.canConvert(_currency, finance.localCurrency)) {
      localAmount = currencyProvider.convert(amount, _currency, finance.localCurrency);
    }

    finance.addExpense(
      name: name,
      amount: amount,
      currency: _currency,
      category: addedCategory,
      date: _date,
      note: note,
      localAmount: localAmount,
      accountId: _accountId,
      tags: parseTags(_tagsController.text),
      sharedTotal: sharedTotal,
      paidByMe: _paidByMe,
    );
    finance.setLastAccountId(_accountId);

    if (split > 1 && _splitCreateDebt && total - amount > 0.009) {
      finance.addDebt(
        person: '${locale.t('compartido')}: $name',
        amount: double.parse((total - amount).toStringAsFixed(2)),
        currency: _currency,
        owedToMe: true,
      );
    }

    _nameController.clear();
    _amountController.clear();
    _noteController.clear();
    _tagsController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _date = DateTime.now();
      _splitCount = 1;
    });

    // Aviso si este gasto lleva la categoría al 80 % o más de su presupuesto.
    final double? baseLimit = finance.budgets[addedCategory];
    if (baseLimit != null && baseLimit > 0) {
      final double limit =
          baseLimit + budgetCarryOver(finance, currencyProvider, addedCategory, baseLimit);
      final double spent = periodSpentLocal(finance, currencyProvider, addedCategory);
      final double fraction = spent / limit;
      if (fraction >= 0.8) {
        final String key = fraction >= 1 ? 'alerta_presupuesto_excedido' : 'alerta_presupuesto_cerca';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${locale.t(key)} (${formatCurrency(spent, finance.localCurrency)} / '
              '${formatCurrency(limit, finance.localCurrency)})',
            ),
          ),
        );
      }
    }
  }

  /// Abre el formulario de compra a crédito con el monto ya escrito.
  void _openCredit() {
    final double? amount = double.tryParse(_amountController.text.trim().replaceAll(',', '.'));
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => InterestCalculatorScreen(creditMode: true, initialAmount: amount, initialCurrency: _currency),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SectionLabel(locale.t('anadir_gasto'))),
              TextButton.icon(
                onPressed: () => startReceiptScan(context),
                icon: const Icon(Icons.document_scanner_outlined, size: 18),
                label: Text(locale.t('escanear_factura')),
              ),
              IconButton(
                onPressed: _openCredit,
                icon: const Icon(Icons.credit_score_outlined, size: 20),
                tooltip: locale.t('pagar_a_credito'),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: () => startSmsImport(context),
                icon: const Icon(Icons.sms_outlined, size: 20),
                tooltip: locale.t('sms_boton'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 10),
          CategorySelectorRow(
            selected: _category,
            locale: locale,
            onChanged: (cat) => setState(() => _category = cat),
          ),
          const SizedBox(height: 16),
          RawAutocomplete<String>(
            textEditingController: _nameController,
            focusNode: _nameFocus,
            optionsBuilder: (TextEditingValue value) =>
                context.read<FinanceProvider>().suggestExpenseNames(value.text),
            onSelected: (String name) {
              final Expense? last = context.read<FinanceProvider>().lastExpenseNamed(name);
              if (last == null) return;
              setState(() {
                _category = last.category;
                _currency = last.currency;
                if (_amountController.text.trim().isEmpty) {
                  _amountController.text = last.amount.toStringAsFixed(2);
                }
              });
            },
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: locale.t('nombre')),
              onSubmitted: (_) => onFieldSubmitted(),
            ),
            optionsViewBuilder: (context, onSelected, options) => Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200, maxWidth: 320),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [
                      for (final option in options)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.history_rounded, size: 18),
                          title: Text(option),
                          onTap: () => onSelected(option),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
              const SizedBox(width: 10),
              Material(
                color: theme.colorScheme.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _submit,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(Icons.add, color: theme.colorScheme.onPrimary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: locale.t('nota_opcional')),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tagsController,
            autocorrect: false,
            decoration: InputDecoration(labelText: locale.t('etiquetas_opcional')),
          ),
          const SizedBox(height: 8),
          AccountDropdown(value: _accountId, onChanged: (id) => setState(() => _accountId = id)),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: Text(_isToday ? locale.t('hoy') : formatDateShort(_date)),
              ),
              const Spacer(),
              if (!_coupleShared) ...[
              Text(locale.t('dividir_entre'), style: theme.textTheme.bodyMedium),
              const SizedBox(width: 6),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _splitCount,
                  dropdownColor: theme.colorScheme.surface,
                  items: [
                    for (int n = 1; n <= 10; n++)
                      DropdownMenuItem<int>(
                        value: n,
                        child: Text(n == 1 ? locale.t('no_dividir') : '$n'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _splitCount = value);
                  },
                ),
              ),
              ],
            ],
          ),
          const Divider(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(locale.t('gasto_en_pareja')),
            subtitle: Text(locale.t('gasto_en_pareja_ayuda'), style: theme.textTheme.bodySmall),
            value: _coupleShared,
            onChanged: (value) => setState(() => _coupleShared = value),
          ),
          if (_coupleShared) ...[
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: true, label: Text(locale.t('pague_yo'), style: const TextStyle(fontSize: 12.5))),
                  ButtonSegment(value: false, label: Text(locale.t('pago_pareja'), style: const TextStyle(fontSize: 12.5))),
                ],
                selected: {_paidByMe},
                onSelectionChanged: (sel) => setState(() => _paidByMe = sel.first),
              ),
            ),
            const SizedBox(height: 6),
            Text('${locale.t('mi_parte')}: ${_myShare.round()} %', style: theme.textTheme.bodyMedium),
            Slider(
              value: _myShare,
              min: 0,
              max: 100,
              divisions: 20,
              label: '${_myShare.round()} %',
              onChanged: (value) => setState(() => _myShare = value),
            ),
          ],
          if (_splitCount > 1 && !_coupleShared)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: _splitCreateDebt,
              onChanged: (value) => setState(() => _splitCreateDebt = value ?? true),
              title: Text(locale.t('registrar_lo_que_me_deben'), style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}
