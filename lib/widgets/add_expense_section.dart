import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../utils/budget_utils.dart';
import '../utils/formatters.dart';
import '../providers/locale_provider.dart';
import 'category_selector_row.dart';
import 'currency_dropdown.dart';
import 'section_card.dart';

class AddExpenseSection extends StatefulWidget {
  const AddExpenseSection({super.key});

  @override
  State<AddExpenseSection> createState() => _AddExpenseSectionState();
}

class _AddExpenseSectionState extends State<AddExpenseSection> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String _category = ExpenseCategory.compras;
  late String _currency;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(locale.t('campos_gasto_invalidos'))),
      );
      return;
    }

    final finance = context.read<FinanceProvider>();
    final currencyProvider = context.read<CurrencyProvider>();
    final String addedCategory = _category;

    finance.addExpense(
      name: name,
      amount: amount,
      currency: _currency,
      category: addedCategory,
    );

    _nameController.clear();
    _amountController.clear();
    FocusScope.of(context).unfocus();

    // Aviso si este gasto lleva la categoría al 80 % o más de su presupuesto.
    final double? limit = finance.budgets[addedCategory];
    if (limit != null && limit > 0) {
      final double spent = monthSpentLocal(finance, currencyProvider, addedCategory);
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

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(locale.t('anadir_gasto')),
          const SizedBox(height: 14),
          CategorySelectorRow(
            selected: _category,
            locale: locale,
            onChanged: (cat) => setState(() => _category = cat),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: locale.t('nombre')),
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
        ],
      ),
    );
  }
}
