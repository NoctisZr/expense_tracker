import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/currency_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/app_colors.dart';
import '../utils/app_navigation.dart';
import '../utils/category_style.dart';
import '../utils/formatters.dart';
import '../widgets/add_expense_section.dart';
import '../widgets/account_widgets.dart';
import '../widgets/analysis_section.dart';
import '../widgets/annual_section.dart';
import '../widgets/backup_nudge_card.dart';
import '../widgets/debts_section.dart';
import '../widgets/next_payment_card.dart';
import '../widgets/recurring_income_section.dart';
import '../widgets/balance_donut_chart.dart';
import '../widgets/budget_section.dart';
import '../widgets/category_selector_row.dart';
import '../widgets/category_summary.dart';
import '../widgets/couple_section.dart';
import '../widgets/credits_section.dart';
import '../widgets/envelopes_section.dart';
import '../widgets/getting_started_card.dart';
import '../widgets/weekly_budget_section.dart';
import '../widgets/savings_rule_section.dart';
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
import '../widgets/subscription_suggestions.dart';
import '../widgets/update_banner.dart';
import '../widgets/upcoming_charges.dart';
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
  @override
  void initState() {
    super.initState();
    AppNavigation.dashboardView.addListener(_onViewRequest);
  }

  @override
  void dispose() {
    AppNavigation.dashboardView.removeListener(_onViewRequest);
    super.dispose();
  }

  /// Un atajo de pantalla pidió abrir una vista concreta.
  void _onViewRequest() {
    final int? view = AppNavigation.dashboardView.value;
    if (view == null) return;
    AppNavigation.dashboardView.value = null;
    if (mounted) setState(() => _view = view);
  }

  int _view = 0; // 0 Resumen, 1 Movimientos, 2 Planificación
  bool _showCalendar = false;
  DateTimeRange? _range;
  String? _filterTag;

  /// Cuántos gastos se dibujan en la lista (se amplía con "Mostrar más"). Con
  /// miles de gastos, dibujarlos todos a la vez hacía lenta la pantalla.
  int _visibleCount = 40;
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
    final bool simple = context.watch<ThemeProvider>().simpleMode;
    if (simple && _view == 2) _view = 0;

    final expenses = finance.expenses;
    final vaults = finance.vaults;
    final incomes = finance.incomes;

    final String query = _query.trim().toLowerCase();
    final List<Expense> filtered = expenses
        .where((e) =>
            (_filterCategory == null || e.category == _filterCategory) &&
            (_filterTag == null || (e.tags ?? const <String>[]).contains(_filterTag)) &&
            (query.isEmpty || e.name.toLowerCase().contains(query)) &&
            (_range == null ||
                (!e.date.isBefore(_range!.start) &&
                    e.date.isBefore(_range!.end.add(const Duration(days: 1))))))
        .toList();
    final int shownCount = filtered.length < _visibleCount ? filtered.length : _visibleCount;
    final bool filtersActive =
        query.isNotEmpty || _filterCategory != null || _filterTag != null || _range != null;
    double filteredTotal = 0;
    if (filtersActive) {
      for (final e in filtered) {
        filteredTotal += finance.expenseLocalValue(e, currency);
      }
    }

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
        periodExpensesLocal += finance.expenseLocalValue(e, currency);
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
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.asset(
                    'assets/nuvio_icon.png',
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nuvio',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Tus finanzas, en equilibrio',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ),
                ),
                const WorkspaceSelector(),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 0, label: Text(locale.t('vista_resumen'), style: const TextStyle(fontSize: 12.5))),
                  ButtonSegment(value: 1, label: Text(locale.t('vista_movimientos'), style: const TextStyle(fontSize: 12.5))),
                  if (!simple)
                    ButtonSegment(value: 2, label: Text(locale.t('vista_planificacion'), style: const TextStyle(fontSize: 12.5))),
                ],
                selected: {_view},
                onSelectionChanged: (selection) => setState(() => _view = selection.first),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: theme.colorScheme.primary,
                  selectedForegroundColor: AppColors.onColorFor(theme.colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_view == 0) ...[
            const UpdateBanner(),
            const BackupNudgeCard(),
            const NextPaymentCard(),
            const GettingStartedCard(),
            const AccountsSection(),
            const SizedBox(height: 18),
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
            if (!simple) ...[
              const SizedBox(height: 18),
              const AnalysisSection(),
              const SizedBox(height: 18),
              const AnnualSection(),
            ],
            const SizedBox(height: 18),
            const CategorySummary(),
            ],
            if (_view == 1) ...[
            const AddExpenseSection(),
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
                onChanged: (value) => setState(() {
                  _query = value;
                  _visibleCount = 40;
                }),
                decoration: InputDecoration(
                  hintText: locale.t('buscar_gastos'),
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final DateTime now = DateTime.now();
                        final DateTimeRange? picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: now.add(const Duration(days: 366)),
                          initialDateRange: _range,
                        );
                        if (picked != null) {
                          setState(() {
                            _range = picked;
                            _visibleCount = 40;
                          });
                        }
                      },
                      icon: const Icon(Icons.date_range_rounded, size: 18),
                      label: Text(
                        _range == null
                            ? locale.t('rango_fechas')
                            : '${formatDateShort(_range!.start)} – ${formatDateShort(_range!.end)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (_range != null)
                    IconButton(
                      onPressed: () => setState(() {
                        _range = null;
                        _visibleCount = 40;
                      }),
                      icon: const Icon(Icons.close, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
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
                    onTap: () => setState(() {
                      _filterCategory = null;
                      _visibleCount = 40;
                    }),
                  ),
                  for (final cat in ExpenseCategory.all)
                    CategoryChip(
                      icon: categoryIcon(cat),
                      label: locale.t(categoryLabelKey(cat)),
                      selected: _filterCategory == cat,
                      color: categoryColor(cat),
                      onTap: () => setState(() {
                        _filterCategory = _filterCategory == cat ? null : cat;
                        _visibleCount = 40;
                      }),
                    ),
                ],
              ),
              if (finance.topTags().isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final tag in finance.topTags())
                      FilterChip(
                        label: Text('#$tag', style: const TextStyle(fontSize: 12)),
                        selected: _filterTag == tag,
                        onSelected: (selected) => setState(() {
                          _filterTag = selected ? tag : null;
                          _visibleCount = 40;
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              if (filtersActive)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '${filtered.length} · ${locale.t('total_filtrado')}: ${formatCurrency(filteredTotal, finance.localCurrency)}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
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
                    for (int i = 0; i < shownCount; i++) ...[
                      ExpenseListItem(
                        expense: filtered[i],
                        locale: locale,
                        onDelete: () => confirmDeleteExpense(context, filtered[i].id),
                      ),
                      if (i != shownCount - 1)
                        Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                    ],
                    if (filtered.length > shownCount)
                      TextButton(
                        onPressed: () => setState(() => _visibleCount += 40),
                        child: Text('${locale.t('mostrar_mas')} (${filtered.length - shownCount})'),
                      ),
                  ],
                ),
              ),
            ],
            if (_view == 2) ...[
              const UpcomingCharges(),
              const SubscriptionSuggestions(),
              const BudgetSection(),
              const SizedBox(height: 18),
              const RecurringIncomeSection(),
              const SizedBox(height: 18),
              const RecurringSection(),
              const SizedBox(height: 18),
              const CreditsSection(),
              const SizedBox(height: 18),
              const CoupleSection(),
              const SizedBox(height: 18),
              const SavingsRuleSection(),
              const SizedBox(height: 18),
              const WeeklyBudgetSection(),
              const SizedBox(height: 18),
              const EnvelopesSection(),
              const SizedBox(height: 18),
              const DebtsSection(),
            ],
          ],
        ),
      ),
    );
  }
}
