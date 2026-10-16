import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/app_colors.dart';
import '../utils/category_style.dart';
import '../widgets/add_expense_section.dart';
import '../widgets/balance_donut_chart.dart';
import '../widgets/budget_section.dart';
import '../widgets/category_selector_row.dart';
import '../widgets/category_summary.dart';
import '../widgets/currency_dropdown.dart';
import '../widgets/expense_calendar.dart';
import '../widgets/expense_list_item.dart';
import '../widgets/income_card.dart';
import '../widgets/income_dialogs.dart';
import '../widgets/income_details_sheet.dart';
import '../widgets/recurring_section.dart';
import '../widgets/section_card.dart';
import '../widgets/vault_card.dart';
import '../widgets/vault_details_sheet.dart';
import '../widgets/vault_dialogs.dart';
import '../widgets/workspace_selector.dart';

/// Pestaña 1: Presupuesto (Dashboard). El balance libre se calcula
/// desde el ingreso más reciente registrado, no de un sueldo fijo.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _showCalendar = false;
  String _query = '';
  String? _filterCategory;

  void _confirmDeleteVault(String id, LocaleProvider locale) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(locale.t('eliminar_boveda_titulo')),
        content: Text(locale.t('eliminar_boveda_mensaje')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(locale.t('cancelar')),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<FinanceProvider>().deleteVault(id);
              Navigator.of(dialogContext).pop();
            },
            child: Text(locale.t('eliminar')),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteIncome(String id, LocaleProvider locale) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(locale.t('eliminar_ingreso_titulo')),
        content: Text(locale.t('eliminar_ingreso_mensaje')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(locale.t('cancelar')),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<FinanceProvider>().deleteIncome(id);
              Navigator.of(dialogContext).pop();
            },
            child: Text(locale.t('eliminar')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final currency = context.watch<CurrencyProvider>();
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    final expenses = finance.expenses;
    final vaults = finance.vaults;
    final incomes = finance.incomes;

    final String query = _query.trim().toLowerCase();
    final List<Expense> filtered = expenses
        .where((e) =>
            (_filterCategory == null || e.category == _filterCategory) &&
            (query.isEmpty || e.name.toLowerCase().contains(query)))
        .toList();

    final mostRecentIncome = incomes.isEmpty ? null : incomes.first;

    double incomeAmountLocal = 0;
    double periodExpensesLocal = 0;
    double periodVaultNetLocal = 0;

    if (mostRecentIncome != null) {
      incomeAmountLocal = currency.convert(
        mostRecentIncome.amount,
        mostRecentIncome.currency,
        finance.localCurrency,
      );

      for (final e in finance.expensesInPeriod(mostRecentIncome.date, null)) {
        periodExpensesLocal += currency.convert(e.amount, e.currency, finance.localCurrency);
      }

      for (final t in finance.vaultTransactionsInPeriod(mostRecentIncome.date, null)) {
        final double convertedToLocal = currency.convert(t.amount, t.currency, finance.localCurrency);
        periodVaultNetLocal += t.isWithdrawal ? -convertedToLocal : convertedToLocal;
      }
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: WorkspaceSelector(),
            ),
            const SizedBox(height: 12),
            SectionCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${locale.t('moneda_local')}:',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  CurrencyDropdown(
                    value: finance.localCurrency,
                    onChanged: (value) => finance.setLocalCurrency(value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            BalanceDonutChart(
              incomeAmount: incomeAmountLocal,
              incomeDate: mostRecentIncome?.date,
              periodExpenses: periodExpensesLocal,
              periodVaultNet: periodVaultNetLocal,
              currency: finance.localCurrency,
              balanceLibreLabel: locale.t('balance_libre'),
              disponibleLabel: locale.t('disponible'),
              gastosLabel: locale.t('gastos'),
              bovedasLabel: locale.t('bovedas'),
              desdeLabel: locale.t('desde'),
              sinIngresosPrompt: locale.t('sin_ingresos_prompt'),
              balanceNegativoTitulo: locale.t('balance_negativo_titulo'),
              balanceNegativoMensaje: locale.t('balance_negativo_mensaje'),
            ),
            const SizedBox(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SectionLabel(locale.t('mis_ingresos'), overflow: TextOverflow.ellipsis),
                ),
                Material(
                  color: theme.colorScheme.primary,
                  elevation: 3,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => showAddIncomeDialog(context),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.add, color: theme.colorScheme.onPrimary, size: 20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (incomes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(locale.t('sin_ingresos'), style: TextStyle(color: theme.hintColor)),
              )
            else
              ...incomes.map(
                (income) => IncomeCard(
                  income: income,
                  onDelete: () => _confirmDeleteIncome(income.id, locale),
                  onViewDetails: () => showIncomeDetailsSheet(context, income: income),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SectionLabel(locale.t('mis_bovedas'), overflow: TextOverflow.ellipsis),
                ),
                Material(
                  color: theme.colorScheme.primary,
                  elevation: 3,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => showCreateVaultDialog(context),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.add, color: theme.colorScheme.onPrimary, size: 20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (vaults.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(locale.t('sin_bovedas'), style: TextStyle(color: theme.hintColor)),
              )
            else
              ...vaults.map(
                (vault) => VaultCard(
                  vault: vault,
                  deLabel: locale.t('de'),
                  verDetallesLabel: locale.t('ver_detalles'),
                  onDelete: () => _confirmDeleteVault(vault.id, locale),
                  onAddFunds: () =>
                      showVaultFundDialog(context, vault: vault, isAdding: true),
                  onWithdrawFunds: () =>
                      showVaultFundDialog(context, vault: vault, isAdding: false),
                  onViewDetails: () => showVaultDetailsSheet(context, vault: vault),
                ),
              ),
            const SizedBox(height: 10),
            const BudgetSection(),
            const SizedBox(height: 18),
            const AddExpenseSection(),
            const SizedBox(height: 18),
            const RecurringSection(),
            const SizedBox(height: 18),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(locale.t('vista_lista')),
                  icon: const Icon(Icons.list_rounded, size: 18),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(locale.t('vista_calendario')),
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                ),
              ],
              selected: {_showCalendar},
              onSelectionChanged: (selection) => setState(() => _showCalendar = selection.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: theme.colorScheme.primary,
                selectedForegroundColor: AppColors.onColorFor(theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 14),
            if (!_showCalendar && expenses.isNotEmpty) ...[
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: locale.t('buscar_gastos'),
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CategoryChip(
                    icon: Icons.apps_rounded,
                    label: locale.t('todas'),
                    selected: _filterCategory == null,
                    color: theme.colorScheme.primary,
                    onTap: () => setState(() => _filterCategory = null),
                  ),
                  for (final cat in ExpenseCategory.all)
                    CategoryChip(
                      icon: categoryIcon(cat),
                      label: locale.t(categoryLabelKey(cat)),
                      selected: _filterCategory == cat,
                      color: categoryColor(cat),
                      onTap: () => setState(
                        () => _filterCategory = _filterCategory == cat ? null : cat,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (_showCalendar)
              SectionCard(child: const ExpenseCalendar())
            else if (expenses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(locale.t('sin_gastos'), style: TextStyle(color: theme.hintColor)),
              )
            else if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(locale.t('sin_resultados'), style: TextStyle(color: theme.hintColor)),
              )
            else
              SectionCard(
                child: Column(
                  children: [
                    for (int i = 0; i < filtered.length; i++) ...[
                      ExpenseListItem(
                        expense: filtered[i],
                        locale: locale,
                        onDelete: () => confirmDeleteExpense(context, filtered[i].id),
                      ),
                      if (i != filtered.length - 1)
                        Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 18),
            const CategorySummary(),
          ],
        ),
      ),
    );
  }
}
