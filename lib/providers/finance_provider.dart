import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../models/recurring_expense.dart';
import '../models/vault.dart';
import '../models/vault_transaction.dart';
import '../models/workspace.dart';
import '../utils/currency_list.dart';
import '../utils/id_generator.dart';

/// Las cuatro cajas de Hive que componen un espacio de trabajo.
class _WorkspaceBoxes {
  final Box<Expense> expenses;
  final Box<Income> incomes;
  final Box<Vault> vaults;
  final Box<VaultTransaction> vaultTransactions;

  _WorkspaceBoxes(this.expenses, this.incomes, this.vaults, this.vaultTransactions);
}

/// Provider central de datos financieros del usuario: moneda local,
/// gastos, ingresos, bóvedas, presupuestos, gastos recurrentes y el
/// historial de aportes de cada bóveda. Soporta varios espacios de
/// trabajo (Personal, Negocio...) cambiando de cajas de Hive en caliente.
class FinanceProvider extends ChangeNotifier {
  static const String personalWorkspaceId = 'personal';

  static const String _localCurrencyKey = 'localCurrency';
  static const String _workspacesKey = 'workspaces';
  static const String _activeWorkspaceKey = 'activeWorkspace';
  static const String _budgetsKeyPrefix = 'budgets_';
  static const String _recurringKeyPrefix = 'recurring_';

  static const String _expensesBase = 'expenses_box';
  static const String _incomesBase = 'incomes_box';
  static const String _vaultsBase = 'vaults_box';
  static const String _vaultTxBase = 'vault_transactions_box';

  final Box settingsBox;

  Box<Expense> expensesBox;
  Box<Income> incomesBox;
  Box<Vault> vaultsBox;
  Box<VaultTransaction> vaultTransactionsBox;

  late String _workspaceId;
  late List<Workspace> _workspaces;
  late String _localCurrency;

  FinanceProvider._({
    required this.settingsBox,
    required this.expensesBox,
    required this.incomesBox,
    required this.vaultsBox,
    required this.vaultTransactionsBox,
    required String workspaceId,
  }) {
    _workspaceId = workspaceId;
    _workspaces = _readWorkspaces(settingsBox);

    final dynamic storedCurrency = settingsBox.get(_localCurrencyKey);
    if (storedCurrency is String) {
      _localCurrency = storedCurrency;
    } else {
      // Primer arranque: se deduce la moneda del idioma/región del teléfono.
      _localCurrency = detectCurrencyFromLocale();
      settingsBox.put(_localCurrencyKey, _localCurrency);
    }

    applyRecurringExpenses();
  }

  /// Abre las cajas del espacio activo y crea el provider.
  static Future<FinanceProvider> create(Box settingsBox) async {
    final List<Workspace> workspaces = _readWorkspaces(settingsBox);
    String activeId =
        (settingsBox.get(_activeWorkspaceKey) as String?) ?? personalWorkspaceId;
    if (!workspaces.any((w) => w.id == activeId)) {
      activeId = personalWorkspaceId;
    }
    final _WorkspaceBoxes boxes = await _openBoxes(activeId);
    return FinanceProvider._(
      settingsBox: settingsBox,
      expensesBox: boxes.expenses,
      incomesBox: boxes.incomes,
      vaultsBox: boxes.vaults,
      vaultTransactionsBox: boxes.vaultTransactions,
      workspaceId: activeId,
    );
  }

  /// El espacio 'personal' conserva los nombres de caja originales para no
  /// perder datos; el resto usa un sufijo con su id.
  static String boxName(String base, String workspaceId) =>
      workspaceId == personalWorkspaceId ? base : '${base}__$workspaceId';

  static Future<_WorkspaceBoxes> _openBoxes(String workspaceId) async {
    final Box<Expense> expenses =
        await Hive.openBox<Expense>(boxName(_expensesBase, workspaceId));
    final Box<Income> incomes =
        await Hive.openBox<Income>(boxName(_incomesBase, workspaceId));
    final Box<Vault> vaults =
        await Hive.openBox<Vault>(boxName(_vaultsBase, workspaceId));
    final Box<VaultTransaction> txs =
        await Hive.openBox<VaultTransaction>(boxName(_vaultTxBase, workspaceId));
    return _WorkspaceBoxes(expenses, incomes, vaults, txs);
  }

  static List<Workspace> _readWorkspaces(Box box) {
    final List<Workspace> result = [];
    final dynamic raw = box.get(_workspacesKey);
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          try {
            result.add(Workspace.fromMap(item));
          } catch (_) {}
        }
      }
    }
    if (!result.any((w) => w.id == personalWorkspaceId)) {
      result.insert(0, const Workspace(id: personalWorkspaceId, name: 'Personal'));
    }
    return result;
  }

  Future<void> _saveWorkspaces() async {
    await settingsBox.put(_workspacesKey, _workspaces.map((w) => w.toMap()).toList());
  }

  // ---------------------------------------------------------------------
  // Espacios de trabajo
  // ---------------------------------------------------------------------

  List<Workspace> get workspaces => List.unmodifiable(_workspaces);
  String get activeWorkspaceId => _workspaceId;

  Workspace get activeWorkspace =>
      _workspaces.firstWhere((w) => w.id == _workspaceId, orElse: () => _workspaces.first);

  bool get isPersonalWorkspace => _workspaceId == personalWorkspaceId;

  Future<void> switchWorkspace(String id) async {
    if (id == _workspaceId || !_workspaces.any((w) => w.id == id)) return;
    final _WorkspaceBoxes boxes = await _openBoxes(id);
    expensesBox = boxes.expenses;
    incomesBox = boxes.incomes;
    vaultsBox = boxes.vaults;
    vaultTransactionsBox = boxes.vaultTransactions;
    _workspaceId = id;
    await settingsBox.put(_activeWorkspaceKey, id);
    applyRecurringExpenses();
    notifyListeners();
  }

  Future<void> createWorkspace(String name) async {
    final String cleanName = name.trim();
    if (cleanName.isEmpty) return;
    final String id = 'ws${DateTime.now().millisecondsSinceEpoch}';
    _workspaces = [..._workspaces, Workspace(id: id, name: cleanName)];
    await _saveWorkspaces();
    await switchWorkspace(id);
  }

  Future<void> renameWorkspace(String id, String name) async {
    final String cleanName = name.trim();
    if (cleanName.isEmpty) return;
    _workspaces = _workspaces
        .map((w) => w.id == id ? w.copyWith(name: cleanName) : w)
        .toList();
    await _saveWorkspaces();
    notifyListeners();
  }

  Future<void> deleteWorkspace(String id) async {
    if (id == personalWorkspaceId || !_workspaces.any((w) => w.id == id)) return;
    if (id == _workspaceId) {
      await switchWorkspace(personalWorkspaceId);
    }
    for (final base in [_expensesBase, _incomesBase, _vaultsBase, _vaultTxBase]) {
      await Hive.deleteBoxFromDisk(boxName(base, id));
    }
    await settingsBox.delete('$_budgetsKeyPrefix$id');
    await settingsBox.delete('$_recurringKeyPrefix$id');
    _workspaces = _workspaces.where((w) => w.id != id).toList();
    await _saveWorkspaces();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Moneda local
  // ---------------------------------------------------------------------

  String get localCurrency => _localCurrency;

  void setLocalCurrency(String currency) {
    _localCurrency = currency;
    settingsBox.put(_localCurrencyKey, currency);
    notifyListeners();
  }

  /// Deduce una moneda soportada a partir de la región/idioma del teléfono.
  static String detectCurrencyFromLocale() {
    final Locale locale = PlatformDispatcher.instance.locale;
    final String? country = locale.countryCode?.toUpperCase();
    if (country != null) {
      final String? code = kCountryToCurrency[country];
      if (code != null && kSupportedCurrencies.contains(code)) return code;
    }
    switch (locale.languageCode.toLowerCase()) {
      case 'pt':
        return 'BRL';
      case 'ja':
        return 'JPY';
      default:
        return 'USD';
    }
  }

  // ---------------------------------------------------------------------
  // Gastos
  // ---------------------------------------------------------------------

  List<Expense> get expenses {
    final list = expensesBox.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  void addExpense({
    required String name,
    required double amount,
    required String currency,
    required String category,
    DateTime? date,
  }) {
    final expense = Expense(
      id: generateId(),
      name: name,
      amount: amount,
      currency: currency,
      category: category,
      date: date ?? DateTime.now(),
    );
    expensesBox.put(expense.id, expense);
    notifyListeners();
  }

  void updateExpense({
    required String id,
    required String name,
    required double amount,
    required String currency,
    required String category,
    required DateTime date,
  }) {
    if (!expensesBox.containsKey(id)) return;
    expensesBox.put(
      id,
      Expense(
        id: id,
        name: name,
        amount: amount,
        currency: currency,
        category: category,
        date: date,
      ),
    );
    notifyListeners();
  }

  void deleteExpense(String id) {
    expensesBox.delete(id);
    notifyListeners();
  }

  Map<String, double> totalExpensesByCurrency() {
    final Map<String, double> totals = {};
    for (final expense in expensesBox.values) {
      totals[expense.currency] = (totals[expense.currency] ?? 0) + expense.amount;
    }
    return totals;
  }

  /// Suma de gastos agrupados por categoría y luego por divisa (sin
  /// convertir). Se usa en el resumen por categoría.
  Map<String, Map<String, double>> totalExpensesByCategoryAndCurrency() {
    final Map<String, Map<String, double>> result = {};
    for (final expense in expensesBox.values) {
      final Map<String, double> byCurrency = result.putIfAbsent(expense.category, () => {});
      byCurrency[expense.currency] = (byCurrency[expense.currency] ?? 0) + expense.amount;
    }
    return result;
  }

  List<Expense> expensesOnDay(DateTime day) {
    return expenses
        .where((e) =>
            e.date.year == day.year &&
            e.date.month == day.month &&
            e.date.day == day.day)
        .toList();
  }

  Set<DateTime> expenseDaysInMonth(DateTime month) {
    return expensesBox.values
        .where((e) => e.date.year == month.year && e.date.month == month.month)
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet();
  }

  /// Gastos registrados entre [start] (inclusive) y [end] (exclusive).
  List<Expense> expensesInPeriod(DateTime start, DateTime? end) {
    return expensesBox.values.where((e) {
      final bool afterStart = !e.date.isBefore(start);
      final bool beforeEnd = end == null || e.date.isBefore(end);
      return afterStart && beforeEnd;
    }).toList();
  }

  /// Movimientos de TODAS las bóvedas entre [start] (inclusive) y [end]
  /// (exclusive).
  List<VaultTransaction> vaultTransactionsInPeriod(DateTime start, DateTime? end) {
    return vaultTransactionsBox.values.where((t) {
      final bool afterStart = !t.date.isBefore(start);
      final bool beforeEnd = end == null || t.date.isBefore(end);
      return afterStart && beforeEnd;
    }).toList();
  }

  // ---------------------------------------------------------------------
  // Presupuestos mensuales por categoría (en moneda local)
  // ---------------------------------------------------------------------

  String get _budgetsKey => '$_budgetsKeyPrefix$_workspaceId';

  Map<String, double> get budgets {
    final dynamic raw = settingsBox.get(_budgetsKey);
    final Map<String, double> result = {};
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is num && value > 0) {
          result[key.toString()] = value.toDouble();
        }
      });
    }
    return result;
  }

  void setBudgets(Map<String, double> newBudgets) {
    final Map<String, double> clean = {
      for (final entry in newBudgets.entries)
        if (entry.value > 0) entry.key: entry.value,
    };
    settingsBox.put(_budgetsKey, clean);
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Gastos recurrentes
  // ---------------------------------------------------------------------

  String get _recurringKey => '$_recurringKeyPrefix$_workspaceId';

  List<RecurringExpense> get recurringExpenses {
    final dynamic raw = settingsBox.get(_recurringKey);
    final List<RecurringExpense> result = [];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          try {
            result.add(RecurringExpense.fromMap(item));
          } catch (_) {}
        }
      }
    }
    return result;
  }

  Future<void> _saveRecurring(List<RecurringExpense> list) async {
    await settingsBox.put(_recurringKey, list.map((r) => r.toMap()).toList());
  }

  /// El primer cargo se registra en la PRÓXIMA fecha de cobro: si el día
  /// elegido ya pasó (o es hoy), empieza el mes siguiente.
  void addRecurringExpense({
    required String name,
    required double amount,
    required String currency,
    required String category,
    required int dayOfMonth,
  }) {
    final DateTime now = DateTime.now();
    final int currentMonth = RecurringExpense.monthIndex(now);
    final int lastGenerated = dayOfMonth <= now.day ? currentMonth : currentMonth - 1;
    final List<RecurringExpense> list = recurringExpenses
      ..add(RecurringExpense(
        id: generateId(),
        name: name,
        amount: amount,
        currency: currency,
        category: category,
        dayOfMonth: dayOfMonth.clamp(1, 31).toInt(),
        lastGeneratedMonth: lastGenerated,
      ));
    _saveRecurring(list);
    notifyListeners();
  }

  void deleteRecurringExpense(String id) {
    final List<RecurringExpense> list =
        recurringExpenses.where((r) => r.id != id).toList();
    _saveRecurring(list);
    notifyListeners();
  }

  /// Permite a la UI pedir un refresco tras `applyRecurringExpenses()`.
  void notifyChanged() => notifyListeners();

  /// Crea los gastos de los meses que ya llegaron para cada recurrente.
  /// Devuelve cuántos gastos se generaron. No notifica: lo hace el que llama.
  int applyRecurringExpenses() {
    final List<RecurringExpense> list = recurringExpenses;
    if (list.isEmpty) return 0;

    final DateTime now = DateTime.now();
    final int currentMonth = RecurringExpense.monthIndex(now);
    int created = 0;
    bool changed = false;
    final List<RecurringExpense> updated = [];

    for (final r in list) {
      int last = r.lastGeneratedMonth;
      if (currentMonth - last > 24) last = currentMonth - 24;
      int month = last + 1;
      while (month <= currentMonth) {
        final int year = month ~/ 12;
        final int monthNumber = month % 12 + 1;
        final int daysInMonth = DateTime(year, monthNumber + 1, 0).day;
        final int day = r.dayOfMonth > daysInMonth ? daysInMonth : r.dayOfMonth;
        final DateTime date = DateTime(year, monthNumber, day, 9);
        if (date.isAfter(now)) break;
        final Expense expense = Expense(
          id: generateId(),
          name: r.name,
          amount: r.amount,
          currency: r.currency,
          category: r.category,
          date: date,
        );
        expensesBox.put(expense.id, expense);
        created++;
        last = month;
        month++;
      }
      if (last != r.lastGeneratedMonth) {
        changed = true;
        updated.add(r.copyWith(lastGeneratedMonth: last));
      } else {
        updated.add(r);
      }
    }

    if (changed) _saveRecurring(updated);
    return created;
  }

  // ---------------------------------------------------------------------
  // Ingresos (pagos recibidos)
  // ---------------------------------------------------------------------

  List<Income> get incomes {
    final list = incomesBox.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  void addIncome({
    required String label,
    required double amount,
    required String currency,
    DateTime? date,
  }) {
    final income = Income(
      id: generateId(),
      label: label,
      amount: amount,
      currency: currency,
      date: date ?? DateTime.now(),
    );
    incomesBox.put(income.id, income);
    notifyListeners();
  }

  void deleteIncome(String id) {
    incomesBox.delete(id);
    notifyListeners();
  }

  Income? nextIncomeAfter(Income income) {
    final List<Income> sorted = incomesBox.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final int index = sorted.indexWhere((i) => i.id == income.id);
    if (index == -1 || index == sorted.length - 1) return null;
    return sorted[index + 1];
  }

  // ---------------------------------------------------------------------
  // Bóvedas
  // ---------------------------------------------------------------------

  List<Vault> get vaults => vaultsBox.values.toList();

  void addVault({
    required String name,
    required double targetAmount,
    required String currency,
  }) {
    final vault = Vault(
      id: generateId(),
      name: name,
      targetAmount: targetAmount,
      currentAmount: 0,
      currency: currency,
    );
    vaultsBox.put(vault.id, vault);
    notifyListeners();
  }

  void deleteVault(String id) {
    vaultsBox.delete(id);
    final List<String> relatedTxIds = vaultTransactionsBox.values
        .where((t) => t.vaultId == id)
        .map((t) => t.id)
        .toList();
    for (final txId in relatedTxIds) {
      vaultTransactionsBox.delete(txId);
    }
    notifyListeners();
  }

  void addFundsToVault(
    String vaultId, {
    required double amount,
    required String currency,
    required double convertedAmount,
    required double rateUsed,
  }) {
    final vault = vaultsBox.get(vaultId);
    if (vault == null || amount <= 0 || convertedAmount <= 0) return;
    vault.currentAmount += convertedAmount;
    vault.save();
    _logVaultTransaction(
      vaultId: vaultId,
      amount: amount,
      currency: currency,
      convertedAmount: convertedAmount,
      rateUsed: rateUsed,
      isWithdrawal: false,
    );
    notifyListeners();
  }

  void withdrawFundsFromVault(
    String vaultId, {
    required double amount,
    required String currency,
    required double convertedAmount,
    required double rateUsed,
  }) {
    final vault = vaultsBox.get(vaultId);
    if (vault == null || amount <= 0 || convertedAmount <= 0) return;
    vault.currentAmount =
        (vault.currentAmount - convertedAmount).clamp(0, double.infinity).toDouble();
    vault.save();
    _logVaultTransaction(
      vaultId: vaultId,
      amount: amount,
      currency: currency,
      convertedAmount: convertedAmount,
      rateUsed: rateUsed,
      isWithdrawal: true,
    );
    notifyListeners();
  }

  void _logVaultTransaction({
    required String vaultId,
    required double amount,
    required String currency,
    required double convertedAmount,
    required double rateUsed,
    required bool isWithdrawal,
  }) {
    final tx = VaultTransaction(
      id: generateId(),
      vaultId: vaultId,
      amount: amount,
      currency: currency,
      convertedAmount: convertedAmount,
      rateUsed: rateUsed,
      date: DateTime.now(),
      isWithdrawal: isWithdrawal,
    );
    vaultTransactionsBox.put(tx.id, tx);
  }

  List<VaultTransaction> transactionsForVault(String vaultId) {
    final list = vaultTransactionsBox.values
        .where((t) => t.vaultId == vaultId)
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Map<String, double> totalVaultSavingsByCurrency() {
    final Map<String, double> totals = {};
    for (final vault in vaultsBox.values) {
      totals[vault.currency] = (totals[vault.currency] ?? 0) + vault.currentAmount;
    }
    return totals;
  }

  // ---------------------------------------------------------------------
  // Exportar / Importar
  // ---------------------------------------------------------------------

  /// Respaldo JSON del espacio de trabajo activo.
  Map<String, dynamic> exportData() {
    return {
      'exportedAt': DateTime.now().toIso8601String(),
      'formatVersion': 2,
      'workspaceName': activeWorkspace.name,
      'localCurrency': _localCurrency,
      'expenses': expensesBox.values.map((e) => e.toJson()).toList(),
      'incomes': incomesBox.values.map((i) => i.toJson()).toList(),
      'vaults': vaultsBox.values.map((v) => v.toJson()).toList(),
      'vaultTransactions': vaultTransactionsBox.values.map((t) => t.toJson()).toList(),
      'budgets': budgets,
      'recurring': recurringExpenses.map((r) => r.toMap()).toList(),
    };
  }

  /// Los gastos del espacio activo en CSV (con BOM UTF-8 para que Excel
  /// respete los acentos).
  String exportExpensesCsv() {
    String esc(String s) {
      if (s.contains(',') || s.contains('"') || s.contains('\n')) {
        return '"${s.replaceAll('"', '""')}"';
      }
      return s;
    }

    final StringBuffer buffer = StringBuffer('\uFEFF');
    buffer.writeln('date,name,category,amount,currency');
    for (final e in expenses) {
      buffer.writeln([
        e.date.toIso8601String(),
        esc(e.name),
        esc(e.category),
        e.amount.toStringAsFixed(2),
        e.currency,
      ].join(','));
    }
    return buffer.toString();
  }

  Future<void> importData(Map<String, dynamic> data) async {
    await expensesBox.clear();
    await incomesBox.clear();
    await vaultsBox.clear();
    await vaultTransactionsBox.clear();

    final String importedCurrency = (data['localCurrency'] as String?) ?? 'USD';
    setLocalCurrency(importedCurrency);

    final List<dynamic> expensesJson = (data['expenses'] as List?) ?? [];
    for (final item in expensesJson) {
      final expense = Expense.fromJson(item as Map<String, dynamic>);
      await expensesBox.put(expense.id, expense);
    }

    final List<dynamic> incomesJson = (data['incomes'] as List?) ?? [];
    for (final item in incomesJson) {
      final income = Income.fromJson(item as Map<String, dynamic>);
      await incomesBox.put(income.id, income);
    }

    final List<dynamic> vaultsJson = (data['vaults'] as List?) ?? [];
    for (final item in vaultsJson) {
      final vault = Vault.fromJson(item as Map<String, dynamic>);
      await vaultsBox.put(vault.id, vault);
    }

    final List<dynamic> txJson = (data['vaultTransactions'] as List?) ?? [];
    for (final item in txJson) {
      final tx = VaultTransaction.fromJson(item as Map<String, dynamic>);
      await vaultTransactionsBox.put(tx.id, tx);
    }

    // Presupuestos y recurrentes existen solo en respaldos formatVersion 2.
    final dynamic budgetsJson = data['budgets'];
    if (budgetsJson is Map) {
      final Map<String, double> imported = {};
      budgetsJson.forEach((key, value) {
        if (value is num) imported[key.toString()] = value.toDouble();
      });
      await settingsBox.put(_budgetsKey, imported);
    }

    final dynamic recurringJson = data['recurring'];
    if (recurringJson is List) {
      final List<Map<String, dynamic>> imported = [];
      for (final item in recurringJson) {
        if (item is Map) {
          try {
            imported.add(RecurringExpense.fromMap(item).toMap());
          } catch (_) {}
        }
      }
      await settingsBox.put(_recurringKey, imported);
    }

    notifyListeners();
  }
}
