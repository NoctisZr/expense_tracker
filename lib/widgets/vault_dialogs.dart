import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../models/vault.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/formatters.dart';
import 'category_selector_row.dart';
import 'currency_dropdown.dart';

Future<void> showCreateVaultDialog(BuildContext context) {
  return showDialog(context: context, builder: (_) => const _CreateVaultDialog());
}

Future<void> showVaultFundDialog(
  BuildContext context, {
  required Vault vault,
  required bool isAdding,
}) {
  return showDialog(
    context: context,
    builder: (_) => _VaultFundDialog(vault: vault, isAdding: isAdding),
  );
}

class _CreateVaultDialog extends StatefulWidget {
  const _CreateVaultDialog();

  @override
  State<_CreateVaultDialog> createState() => _CreateVaultDialogState();
}

class _CreateVaultDialogState extends State<_CreateVaultDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  late String _currency;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currency = context.read<FinanceProvider>().localCurrency;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final locale = context.read<LocaleProvider>();
    final String name = _nameController.text.trim();
    final double? amount =
        double.tryParse(_amountController.text.trim().replaceAll(',', '.'));

    if (name.isEmpty || amount == null || amount <= 0) {
      setState(() => _error = locale.t('campos_boveda_invalidos'));
      return;
    }

    context.read<FinanceProvider>().addVault(
          name: name,
          targetAmount: amount,
          currency: _currency,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();

    return AlertDialog(
      title: Text(locale.t('crear_boveda')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: locale.t('nombre')),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  InputDecoration(labelText: '${locale.t('monto_objetivo')} ($_currency)'),
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
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12.5),
              ),
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

class _VaultFundDialog extends StatefulWidget {
  final Vault vault;
  final bool isAdding;

  const _VaultFundDialog({required this.vault, required this.isAdding});

  @override
  State<_VaultFundDialog> createState() => _VaultFundDialogState();
}

class _VaultFundDialogState extends State<_VaultFundDialog> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _expenseNameController = TextEditingController();
  late String _currency;
  String? _error;

  bool _wasSpent = false;
  String _expenseCategory = ExpenseCategory.compras;

  @override
  void initState() {
    super.initState();
    _currency = widget.vault.currency;
  }

  @override
  void dispose() {
    _controller.dispose();
    _expenseNameController.dispose();
    super.dispose();
  }

  void _submit() {
    final locale = context.read<LocaleProvider>();
    final double? amount =
        double.tryParse(_controller.text.trim().replaceAll(',', '.'));

    if (amount == null || amount <= 0) {
      setState(() => _error = locale.t('campos_boveda_invalidos'));
      return;
    }

    final bool registerAsExpense = !widget.isAdding && _wasSpent;
    final String expenseName = _expenseNameController.text.trim();
    if (registerAsExpense && expenseName.isEmpty) {
      setState(() => _error = locale.t('campos_gasto_invalidos'));
      return;
    }

    final currencyProvider = context.read<CurrencyProvider>();
    final double rateUsed = currencyProvider.rateBetween(_currency, widget.vault.currency);
    final double convertedAmount = currencyProvider.convert(amount, _currency, widget.vault.currency);

    final finance = context.read<FinanceProvider>();
    if (widget.isAdding) {
      finance.addFundsToVault(
        widget.vault.id,
        amount: amount,
        currency: _currency,
        convertedAmount: convertedAmount,
        rateUsed: rateUsed,
      );
    } else {
      finance.withdrawFundsFromVault(
        widget.vault.id,
        amount: amount,
        currency: _currency,
        convertedAmount: convertedAmount,
        rateUsed: rateUsed,
      );
      if (registerAsExpense) {
        finance.addExpense(
          name: expenseName,
          amount: amount,
          currency: _currency,
          category: _expenseCategory,
        );
      }
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final currencyProvider = context.watch<CurrencyProvider>();
    final theme = Theme.of(context);

    final String title =
        widget.isAdding ? locale.t('agregar_fondos') : locale.t('retirar_fondos');
    final String label =
        widget.isAdding ? locale.t('monto_a_agregar') : locale.t('monto_a_retirar');

    final double? amount =
        double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    final bool showConversion =
        _currency != widget.vault.currency && amount != null && amount > 0;
    final double rate = currencyProvider.rateBetween(_currency, widget.vault.currency);
    final double converted = (amount ?? 0) * rate;

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '$label ($_currency)',
                errorText: _error,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    locale.t('divisa_del_aporte'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                CurrencyDropdown(
                  value: _currency,
                  dense: true,
                  onChanged: (value) => setState(() => _currency = value),
                ),
              ],
            ),
            if (showConversion) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${formatCurrency(amount!, _currency)} ${locale.t('equivale_a')} '
                      '${formatCurrency(converted, widget.vault.currency)}',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${locale.t('tasa_aplicada')}: 1 $_currency ≈ ${formatAmount(rate)} ${widget.vault.currency}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
            if (!widget.isAdding) ...[
              const SizedBox(height: 18),
              Text(locale.t('destino_del_retiro'), style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(locale.t('disponible')),
                      icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text(locale.t('fue_un_gasto')),
                      icon: const Icon(Icons.receipt_long_rounded, size: 16),
                    ),
                  ],
                  selected: {_wasSpent},
                  onSelectionChanged: (s) => setState(() => _wasSpent = s.first),
                  style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ),
              if (_wasSpent) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: _expenseNameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: locale.t('nombre')),
                ),
                const SizedBox(height: 12),
                CategorySelectorRow(
                  selected: _expenseCategory,
                  locale: locale,
                  onChanged: (cat) => setState(() => _expenseCategory = cat),
                ),
              ],
            ],
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
