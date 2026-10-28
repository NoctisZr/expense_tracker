import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/formatters.dart';
import 'currency_dropdown.dart';
import 'section_card.dart';

IconData accountIcon(String type) {
  switch (type) {
    case Account.card:
      return Icons.credit_card_rounded;
    case Account.credit:
      return Icons.credit_score_rounded;
    case Account.bank:
      return Icons.account_balance_rounded;
    case Account.savings:
      return Icons.savings_rounded;
    case Account.cash:
    default:
      return Icons.payments_outlined;
  }
}

String accountTypeLabel(LocaleProvider locale, String type) {
  switch (type) {
    case Account.card:
      return locale.t('cuenta_tarjeta');
    case Account.credit:
      return locale.t('cuenta_credito');
    case Account.bank:
      return locale.t('cuenta_banco');
    case Account.savings:
      return locale.t('cuenta_ahorros');
    case Account.cash:
    default:
      return locale.t('cuenta_efectivo');
  }
}

/// Selector de cuenta para los formularios. No se dibuja si no hay cuentas.
class AccountDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const AccountDropdown({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final List<Account> accounts = finance.accounts;
    if (accounts.isEmpty) return const SizedBox.shrink();

    final String? safeValue = accounts.any((a) => a.id == value) ? value : null;

    return Row(
      children: [
        Icon(Icons.account_balance_wallet_outlined, size: 18, color: theme.hintColor),
        const SizedBox(width: 8),
        Text(locale.t('cuenta'), style: theme.textTheme.bodyMedium),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: safeValue,
              isExpanded: true,
              dropdownColor: theme.colorScheme.surface,
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(locale.t('sin_cuenta'))),
                for (final a in accounts)
                  DropdownMenuItem<String?>(
                    value: a.id,
                    child: Text('${a.name} (${a.currency})', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// Resumen de cuentas con su saldo actual.
class AccountsSection extends StatelessWidget {
  const AccountsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final currency = context.watch<CurrencyProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final List<Account> accounts = finance.accounts;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SectionLabel(locale.t('mis_cuentas'), overflow: TextOverflow.ellipsis)),
              if (accounts.length >= 2)
                IconButton(
                  onPressed: () => showTransferDialog(context),
                  icon: Icon(Icons.swap_horiz_rounded, color: theme.colorScheme.primary),
                  tooltip: locale.t('transferir'),
                  visualDensity: VisualDensity.compact,
                ),
              IconButton(
                onPressed: () => showAccountDialog(context),
                icon: Icon(Icons.add_circle_outline_rounded, color: theme.colorScheme.primary),
                tooltip: locale.t('agregar_cuenta'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (accounts.isEmpty)
            Text(locale.t('sin_cuentas'), style: TextStyle(color: theme.hintColor))
          else
            for (final a in accounts)
              InkWell(
                onTap: () => showAccountDialog(context, existing: a),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                        child: Icon(accountIcon(a.type), size: 18, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                            Text(
                              a.type == Account.credit && a.creditLimit != null
                                  ? '${accountTypeLabel(locale, a.type)} · ${locale.t('disponible_credito')}: '
                                      '${formatCurrency(a.creditLimit! + finance.accountBalance(a, currency), a.currency)}'
                                  : accountTypeLabel(locale, a.type),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Builder(builder: (context) {
                        final double balance = finance.accountBalance(a, currency);
                        return Text(
                          formatCurrency(balance, a.currency),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: balance < 0 ? theme.colorScheme.error : null,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Crea una cuenta o, si se pasa [existing], la edita (la divisa no cambia).
Future<void> showAccountDialog(BuildContext context, {Account? existing}) {
  return showDialog(context: context, builder: (_) => _AccountDialog(existing: existing));
}

class _AccountDialog extends StatefulWidget {
  final Account? existing;
  const _AccountDialog({this.existing});

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late final TextEditingController _limitController;
  late String _type;
  late String _currency;

  @override
  void initState() {
    super.initState();
    final Account? a = widget.existing;
    _nameController = TextEditingController(text: a?.name ?? '');
    _balanceController = TextEditingController(text: a == null ? '' : a.initialBalance.toStringAsFixed(2));
    _limitController = TextEditingController(
        text: a?.creditLimit == null ? '' : a!.creditLimit!.toStringAsFixed(2));
    _type = a?.type ?? Account.cash;
    _currency = a?.currency ?? context.read<FinanceProvider>().localCurrency;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  void _save() {
    final locale = context.read<LocaleProvider>();
    final String name = _nameController.text.trim();
    final double balance = double.tryParse(_balanceController.text.trim().replaceAll(',', '.')) ?? 0;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(locale.t('campos_gasto_invalidos'))));
      return;
    }
    final double? limit = double.tryParse(_limitController.text.trim().replaceAll(',', '.'));
    final finance = context.read<FinanceProvider>();
    if (widget.existing == null) {
      finance.addAccount(
          name: name, type: _type, currency: _currency, initialBalance: balance, creditLimit: limit);
    } else {
      finance.updateAccount(
          id: widget.existing!.id, name: name, type: _type, initialBalance: balance, creditLimit: limit);
    }
    Navigator.of(context).pop();
  }

  void _confirmDelete() {
    final locale = context.read<LocaleProvider>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(locale.t('eliminar_cuenta_titulo')),
        content: Text(locale.t('eliminar_cuenta_mensaje')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(locale.t('cancelar'))),
          ElevatedButton(
            onPressed: () {
              context.read<FinanceProvider>().deleteAccount(widget.existing!.id);
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: Text(locale.t('eliminar')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();

    return AlertDialog(
      title: Text(widget.existing == null ? locale.t('agregar_cuenta') : locale.t('editar_cuenta')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: locale.t('nombre')),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final type in Account.types)
                  ChoiceChip(
                    avatar: Icon(accountIcon(type), size: 16),
                    label: Text(accountTypeLabel(locale, type), style: const TextStyle(fontSize: 12)),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _balanceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: InputDecoration(labelText: locale.t('saldo_inicial')),
                  ),
                ),
                const SizedBox(width: 10),
                if (widget.existing == null)
                  CurrencyDropdown(
                    value: _currency,
                    dense: true,
                    onChanged: (value) => setState(() => _currency = value),
                  )
                else
                  Text(_currency, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            if (_type == Account.credit) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _limitController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: locale.t('limite_credito'),
                  helperText: locale.t('limite_credito_ayuda'),
                  helperMaxLines: 2,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: _confirmDelete,
            child: Text(locale.t('eliminar'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(locale.t('cancelar'))),
        ElevatedButton(onPressed: _save, child: Text(locale.t('guardar'))),
      ],
    );
  }
}

/// Mueve dinero de una cuenta a otra (con conversión si las divisas difieren).
Future<void> showTransferDialog(BuildContext context) {
  return showDialog(context: context, builder: (_) => const _TransferDialog());
}

class _TransferDialog extends StatefulWidget {
  const _TransferDialog();

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  final TextEditingController _fromAmountController = TextEditingController();
  final TextEditingController _toAmountController = TextEditingController();
  String? _fromId;
  String? _toId;
  bool _toEdited = false;

  @override
  void initState() {
    super.initState();
    final List<Account> accounts = context.read<FinanceProvider>().accounts;
    _fromId = accounts.isNotEmpty ? accounts.first.id : null;
    _toId = accounts.length > 1 ? accounts[1].id : null;
  }

  @override
  void dispose() {
    _fromAmountController.dispose();
    _toAmountController.dispose();
    super.dispose();
  }

  Account? _find(List<Account> list, String? id) {
    for (final a in list) {
      if (a.id == id) return a;
    }
    return null;
  }

  double? _parse(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  /// Recalcula lo que recibe la cuenta destino (mientras no se edite a mano).
  void _recompute() {
    if (_toEdited) return;
    final finance = context.read<FinanceProvider>();
    final currency = context.read<CurrencyProvider>();
    final Account? from = _find(finance.accounts, _fromId);
    final Account? to = _find(finance.accounts, _toId);
    final double? amount = _parse(_fromAmountController);
    if (from == null || to == null || amount == null) {
      _toAmountController.text = '';
      return;
    }
    final double converted = from.currency == to.currency
        ? amount
        : currency.convert(amount, from.currency, to.currency);
    _toAmountController.text = converted.toStringAsFixed(2);
  }

  void _save() {
    final locale = context.read<LocaleProvider>();
    final double? fromAmount = _parse(_fromAmountController);
    final double? toAmount = _parse(_toAmountController);
    if (_fromId == null ||
        _toId == null ||
        _fromId == _toId ||
        fromAmount == null ||
        toAmount == null ||
        fromAmount <= 0 ||
        toAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(locale.t('transferencia_invalida'))));
      return;
    }
    context.read<FinanceProvider>().addTransfer(
          fromId: _fromId!,
          toId: _toId!,
          fromAmount: fromAmount,
          toAmount: toAmount,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final finance = context.watch<FinanceProvider>();
    final theme = Theme.of(context);
    final List<Account> accounts = finance.accounts;
    final Account? from = _find(accounts, _fromId);
    final Account? to = _find(accounts, _toId);

    Widget picker(String label, String? value, ValueChanged<String?> onChanged) {
      return Row(
        children: [
          SizedBox(width: 62, child: Text(label, style: theme.textTheme.bodyMedium)),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: theme.colorScheme.surface,
                items: [
                  for (final a in accounts)
                    DropdownMenuItem<String>(
                      value: a.id,
                      child: Text('${a.name} (${a.currency})', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text(locale.t('transferir')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            picker(locale.t('desde_cuenta'), _fromId, (v) => setState(() {
                  _fromId = v;
                  _recompute();
                })),
            picker(locale.t('hacia_cuenta'), _toId, (v) => setState(() {
                  _toId = v;
                  _recompute();
                })),
            const SizedBox(height: 8),
            TextField(
              controller: _fromAmountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '${locale.t('sale')}${from == null ? '' : ' (${from.currency})'}',
              ),
              onChanged: (_) => setState(_recompute),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _toAmountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '${locale.t('entra')}${to == null ? '' : ' (${to.currency})'}',
              ),
              onChanged: (_) => _toEdited = true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(locale.t('cancelar'))),
        ElevatedButton(onPressed: _save, child: Text(locale.t('guardar'))),
      ],
    );
  }
}
