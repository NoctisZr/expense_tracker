import 'dart:io' show File;
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/expense.dart';
import '../models/account.dart';
import '../models/debt.dart';
import '../models/income.dart';
import '../models/recurring_expense.dart';
import '../models/recurring_income.dart';
import '../models/vault.dart';
import '../models/vault_transaction.dart';
import '../providers/currency_provider.dart';
import '../utils/category_registry.dart';
import '../models/workspace.dart';
import '../utils/currency_list.dart';
import '../utils/id_generator.dart';

/// Un gasto en la papelera junto con la fecha en que se eliminó.
class TrashedExpense {
  final Expense expense;
  final DateTime deletedAt;

  const TrashedExpense({required this.expense, required this.deletedAt});

  /// Días que faltan para que se borre definitivamente.
  int get daysLeft {
    final int elapsed = DateTime.now().difference(deletedAt).inDays;
    final int left = FinanceProvider.trashRetentionDays - elapsed;
    return left < 0 ? 0 : left;
  }
}

/// Próximo pago esperado: [estimated] es `true` cuando no viene de un
/// ingreso recurrente sino del intervalo típico entre tus últimos pagos.
class NextPayment {
  final DateTime date;
  final bool estimated;

  const NextPayment({required this.date, required this.estimated});
}

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
  static const String _trashKeyPrefix = 'trash_';
  static const String _recurringIncomeKeyPrefix = 'recurringIncome_';
  static const String _debtsKeyPrefix = 'debts_';
  static const String _accountsKeyPrefix = 'accounts_';
  static const String _transfersKeyPrefix = 'transfers_';
  static const String _lastAccountKeyPrefix = 'lastAccount_';
  static const String _budgetModeKey = 'budgetMode';
  static const String _budgetRolloverKey = 'budgetRollover';
  static const String lastExportKey = 'lastExportAt';
  static const String backupNudgeSnoozeKey = 'backupNudgeSnoozedUntil';
  static const String _customCategoriesKey = 'customCategories';
  static const String _historicalRatesKey = 'useHistoricalRates';
  static const String schemaVersionKey = 'schemaVersion';
  static const int currentSchemaVersion = 2;

  /// Días que un gasto eliminado permanece en la papelera.
  static const int trashRetentionDays = 30;

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
  late bool _useHistoricalRates;

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

    _localCurrency = _readLocalCurrency(workspaceId);
    _useHistoricalRates = settingsBox.get(_historicalRatesKey, defaultValue: false) as bool;
    _loadCustomCategories();
    settingsBox.put(schemaVersionKey, currentSchemaVersion);

    // purgeOldTrash() y applyRecurringExpenses() ya NO corren aquí (bloqueaban
    // el primer fotograma): se llaman desde runStartupTasks() tras dibujar.
  }

  /// Tareas de arranque que no hace falta hacer antes del primer fotograma:
  /// vaciar la papelera vencida y registrar los recurrentes que ya vencieron.
  /// Notifica solo si se creó algo.
  void runStartupTasks() {
    purgeOldTrash();
    if (applyRecurringExpenses() > 0) notifyListeners();
  }

  /// Moneda local del espacio: la propia del espacio, o (para espacios
  /// antiguos) la global; en el primer arranque, la deducida del teléfono.
  String _readLocalCurrency(String workspaceId) {
    final dynamic perWorkspace = settingsBox.get('${_localCurrencyKey}_$workspaceId');
    if (perWorkspace is String) return perWorkspace;
    final dynamic global = settingsBox.get(_localCurrencyKey);
    if (global is String) return global;
    final String detected = detectCurrencyFromLocale();
    settingsBox.put(_localCurrencyKey, detected);
    return detected;
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
    // Las cuatro cajas se abren en paralelo (antes eran una tras otra).
    final results = await Future.wait<Object>([
      Hive.openBox<Expense>(boxName(_expensesBase, workspaceId)),
      Hive.openBox<Income>(boxName(_incomesBase, workspaceId)),
      Hive.openBox<Vault>(boxName(_vaultsBase, workspaceId)),
      Hive.openBox<VaultTransaction>(boxName(_vaultTxBase, workspaceId)),
    ]);
    return _WorkspaceBoxes(
      results[0] as Box<Expense>,
      results[1] as Box<Income>,
      results[2] as Box<Vault>,
      results[3] as Box<VaultTransaction>,
    );
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
    _localCurrency = _readLocalCurrency(id);
    await settingsBox.put(_activeWorkspaceKey, id);
    purgeOldTrash();
    applyRecurringExpenses();
    notifyListeners();
  }

  Future<void> createWorkspace(String name) async {
    final String cleanName = name.trim();
    if (cleanName.isEmpty) return;
    final String id = 'ws${DateTime.now().millisecondsSinceEpoch}';
    _workspaces = [..._workspaces, Workspace(id: id, name: cleanName)];
    await _saveWorkspaces();
    // El espacio nuevo hereda la moneda local actual (luego se puede cambiar).
    await settingsBox.put('${_localCurrencyKey}_$id', _localCurrency);
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
    await settingsBox.delete('$_trashKeyPrefix$id');
    await settingsBox.delete('$_recurringIncomeKeyPrefix$id');
    await settingsBox.delete('$_debtsKeyPrefix$id');
    await settingsBox.delete('$_accountsKeyPrefix$id');
    await settingsBox.delete('$_transfersKeyPrefix$id');
    await settingsBox.delete('$_lastAccountKeyPrefix$id');
    await settingsBox.delete('${_localCurrencyKey}_$id');
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
    settingsBox.put('${_localCurrencyKey}_$_workspaceId', currency);
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
  // Tarifas de envío guardadas (globales, comunes a todos los espacios)
  // ---------------------------------------------------------------------

  static const String _shippingPresetsKey = 'shippingPresets';

  List<Map<String, dynamic>> get shippingPresets {
    final dynamic raw = settingsBox.get(_shippingPresetsKey);
    final List<Map<String, dynamic>> result = [];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map && item['name'] is String && item['rate'] is num) {
          result.add(Map<String, dynamic>.from(item));
        }
      }
    }
    return result;
  }

  void saveShippingPresets(List<Map<String, dynamic>> presets) {
    settingsBox.put(_shippingPresetsKey, presets);
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Tasas históricas
  // ---------------------------------------------------------------------

  /// Si es `true`, los totales usan el equivalente guardado el día en que
  /// se registró cada gasto (cuando existe) en vez de la tasa de hoy.
  bool get useHistoricalRates => _useHistoricalRates;

  void setUseHistoricalRates(bool value) {
    _useHistoricalRates = value;
    settingsBox.put(_historicalRatesKey, value);
    notifyListeners();
  }

  /// Valor de un gasto en moneda local, respetando la opción de tasa
  /// histórica.
  double expenseLocalValue(Expense e, CurrencyProvider currency) {
    if (_useHistoricalRates &&
        e.localAmount != null &&
        e.localCurrencyAtCreation == _localCurrency &&
        e.currency != _localCurrency) {
      return e.localAmount!;
    }
    return currency.convert(e.amount, e.currency, _localCurrency);
  }

  // ---------------------------------------------------------------------
  // Categorías personalizadas
  // ---------------------------------------------------------------------

  void _loadCustomCategories() {
    final dynamic raw = settingsBox.get(_customCategoriesKey);
    final List<CustomCategory> list = [];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          try {
            list.add(CustomCategory.fromMap(item));
          } catch (_) {}
        }
      }
    }
    CategoryRegistry.load(list);
  }

  Future<void> _saveCustomCategories(List<CustomCategory> list) async {
    CategoryRegistry.load(list);
    await settingsBox.put(_customCategoriesKey, list.map((c) => c.toMap()).toList());
  }

  /// Devuelve `false` si el nombre es inválido o ya existe.
  bool addCustomCategory(String name, int iconIndex, int colorIndex) {
    final String clean = name.trim();
    if (clean.isEmpty || clean.length > 24) return false;
    final String lower = clean.toLowerCase();
    final bool taken = ExpenseCategory.all.any((c) => c.toLowerCase() == lower);
    if (taken) return false;
    final List<CustomCategory> list = [
      ...CategoryRegistry.custom,
      CustomCategory(name: clean, iconIndex: iconIndex, colorIndex: colorIndex),
    ];
    _saveCustomCategories(list);
    notifyListeners();
    return true;
  }

  /// Borra la categoría personalizada. Sus gastos del espacio activo pasan
  /// a "Otros" para no quedar huérfanos.
  void deleteCustomCategory(String name) {
    final List<Expense> affected =
        expensesBox.values.where((e) => e.category == name).toList();
    for (final e in affected) {
      e.category = ExpenseCategory.otros;
      expensesBox.put(e.id, e);
    }
    final Map<String, double> currentBudgets = budgets..remove(name);
    settingsBox.put(_budgetsKey, currentBudgets);
    _saveCustomCategories(
      CategoryRegistry.custom.where((c) => c.name != name).toList(),
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Gastos
  // ---------------------------------------------------------------------

  List<Expense>? _expensesCache;

  /// Gastos del espacio activo, del más reciente al más antiguo. El resultado
  /// se guarda en caché y se invalida en cada cambio (ver [notifyListeners]):
  /// antes se reordenaba toda la lista en cada llamada, varias veces por
  /// fotograma.
  List<Expense> get expenses {
    final List<Expense>? cached = _expensesCache;
    if (cached != null) return cached;
    final list = expensesBox.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return _expensesCache = list;
  }

  @override
  void notifyListeners() {
    _expensesCache = null;
    super.notifyListeners();
  }

  void addExpense({
    required String name,
    required double amount,
    required String currency,
    required String category,
    DateTime? date,
    String? note,
    double? localAmount,
    String? receiptPath,
    String? accountId,
    List<String>? tags,
  }) {
    final expense = Expense(
      id: generateId(),
      name: name,
      amount: amount,
      currency: currency,
      category: category,
      date: date ?? DateTime.now(),
      note: (note == null || note.trim().isEmpty) ? null : note.trim(),
      localAmount: localAmount,
      localCurrencyAtCreation: localAmount == null ? null : _localCurrency,
      receiptPath: receiptPath,
      accountId: accountId,
      tags: (tags == null || tags.isEmpty) ? null : tags,
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
    String? note,
    double? localAmount,
    String? localCurrencyAtCreation,
    String? receiptPath,
    String? accountId,
    List<String>? tags,
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
        note: (note == null || note.trim().isEmpty) ? null : note.trim(),
        localAmount: localAmount,
        localCurrencyAtCreation: localCurrencyAtCreation,
        receiptPath: receiptPath,
        accountId: accountId,
        tags: (tags == null || tags.isEmpty) ? null : tags,
      ),
    );
    notifyListeners();
  }

  /// Las etiquetas más usadas (para los filtros y las sugerencias).
  List<String> topTags({int limit = 8}) {
    final Map<String, int> counts = {};
    for (final e in expensesBox.values) {
      for (final tag in e.tags ?? const <String>[]) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final List<String> sorted = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return sorted.take(limit).toList();
  }

  /// Sugerencias de nombre a partir de tus gastos anteriores (los más
  /// frecuentes primero).
  List<String> suggestExpenseNames(String query, {int limit = 5}) {
    final String q = query.trim().toLowerCase();
    if (q.length < 2) return const [];
    final Map<String, int> counts = {};
    final Map<String, String> original = {};
    for (final e in expensesBox.values) {
      final String key = e.name.trim().toLowerCase();
      if (key.isEmpty || !key.contains(q)) continue;
      counts[key] = (counts[key] ?? 0) + 1;
      original.putIfAbsent(key, () => e.name.trim());
    }
    final List<String> keys = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return keys.take(limit).map((k) => original[k]!).toList();
  }

  /// Último gasto con exactamente ese nombre (sin distinguir mayúsculas).
  Expense? lastExpenseNamed(String name) {
    final String key = name.trim().toLowerCase();
    Expense? latest;
    for (final e in expensesBox.values) {
      if (e.name.trim().toLowerCase() != key) continue;
      if (latest == null || e.date.isAfter(latest.date)) latest = e;
    }
    return latest;
  }

  /// Mueve el gasto a la papelera (se conserva 30 días).
  void deleteExpense(String id) {
    final Expense? expense = expensesBox.get(id);
    if (expense != null) {
      final List<Map<String, dynamic>> raw = _readTrashRaw();
      raw.add({
        'expense': expense.toJson(),
        'deletedAt': DateTime.now().toIso8601String(),
      });
      settingsBox.put(_trashKey, raw);
    }
    expensesBox.delete(id);
    notifyListeners();
  }

  /// Registra de una vez muchos gastos (importación de CSV).
  int addImportedExpenses(List<Expense> imported) {
    for (final e in imported) {
      expensesBox.put(e.id, e);
    }
    notifyListeners();
    return imported.length;
  }

  // ---------------------------------------------------------------------
  // Papelera
  // ---------------------------------------------------------------------

  String get _trashKey => '$_trashKeyPrefix$_workspaceId';

  List<Map<String, dynamic>> _readTrashRaw() {
    final dynamic raw = settingsBox.get(_trashKey);
    final List<Map<String, dynamic>> result = [];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map && item['expense'] is Map && item['deletedAt'] is String) {
          result.add({
            'expense': Map<String, dynamic>.from(item['expense'] as Map),
            'deletedAt': item['deletedAt'] as String,
          });
        }
      }
    }
    return result;
  }

  List<TrashedExpense> get trashedExpenses {
    final List<TrashedExpense> result = [];
    for (final item in _readTrashRaw()) {
      try {
        result.add(TrashedExpense(
          expense: Expense.fromJson(item['expense'] as Map<String, dynamic>),
          deletedAt: DateTime.parse(item['deletedAt'] as String),
        ));
      } catch (_) {}
    }
    result.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return result;
  }

  void restoreFromTrash(String expenseId) {
    final List<Map<String, dynamic>> raw = _readTrashRaw();
    Map<String, dynamic>? found;
    for (final item in raw) {
      if ((item['expense'] as Map<String, dynamic>)['id'] == expenseId) {
        found = item;
        break;
      }
    }
    if (found == null) return;
    final Expense expense = Expense.fromJson(found['expense'] as Map<String, dynamic>);
    expensesBox.put(expense.id, expense);
    raw.remove(found);
    settingsBox.put(_trashKey, raw);
    notifyListeners();
  }

  void emptyTrash() {
    for (final item in _readTrashRaw()) {
      _deleteReceiptFile((item['expense'] as Map<String, dynamic>)['receiptPath'] as String?);
    }
    settingsBox.delete(_trashKey);
    notifyListeners();
  }

  /// Borra (si existe) la foto de una factura. Nunca lanza error.
  void _deleteReceiptFile(String? path) {
    if (path == null || path.isEmpty) return;
    try {
      final File file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  /// Borra definitivamente lo que lleva más de 30 días en la papelera.
  void purgeOldTrash() {
    final List<Map<String, dynamic>> raw = _readTrashRaw();
    if (raw.isEmpty) return;
    final DateTime limit = DateTime.now().subtract(const Duration(days: trashRetentionDays));
    final List<Map<String, dynamic>> kept = raw.where((item) {
      final DateTime? when = DateTime.tryParse(item['deletedAt'] as String);
      return when != null && when.isAfter(limit);
    }).toList();
    if (kept.length != raw.length) {
      for (final item in raw) {
        if (!kept.contains(item)) {
          _deleteReceiptFile((item['expense'] as Map<String, dynamic>)['receiptPath'] as String?);
        }
      }
      settingsBox.put(_trashKey, kept);
    }
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

  /// Registra un gasto recurrente. El primer cobro cae en [firstDue]; si esa
  /// fecha ya pasó, se crean enseguida los cobros atrasados hasta hoy.
  void addRecurringExpense({
    required String name,
    required double amount,
    required String currency,
    required String category,
    required String frequency,
    required DateTime firstDue,
  }) {
    final DateTime due = frequency == RecurringExpense.semimonthly
        ? RecurringExpense.snapSemimonthly(firstDue)
        : DateTime(firstDue.year, firstDue.month, firstDue.day, 9);
    final List<RecurringExpense> list = recurringExpenses
      ..add(RecurringExpense(
        id: generateId(),
        name: name,
        amount: amount,
        currency: currency,
        category: category,
        frequency: frequency,
        dayOfMonth: due.day,
        paused: false,
        nextDue: due,
      ));
    _saveRecurring(list);
    applyRecurringExpenses();
    notifyListeners();
  }

  void updateRecurringExpense({
    required String id,
    required String name,
    required double amount,
    required String currency,
    required String category,
    required String frequency,
    required DateTime nextDue,
  }) {
    final DateTime due = frequency == RecurringExpense.semimonthly
        ? RecurringExpense.snapSemimonthly(nextDue)
        : DateTime(nextDue.year, nextDue.month, nextDue.day, 9);
    final List<RecurringExpense> list = recurringExpenses
        .map((r) => r.id == id
            ? r.copyWith(
                name: name,
                amount: amount,
                currency: currency,
                category: category,
                frequency: frequency,
                dayOfMonth: due.day,
                nextDue: due,
              )
            : r)
        .toList();
    _saveRecurring(list);
    applyRecurringExpenses();
    notifyListeners();
  }

  /// Pausa o reanuda. Al reanudar no se crean cobros del periodo pausado:
  /// se salta directamente a la próxima fecha futura.
  void toggleRecurringPaused(String id) {
    final DateTime now = DateTime.now();
    final List<RecurringExpense> list = recurringExpenses.map((r) {
      if (r.id != id) return r;
      if (!r.paused) return r.copyWith(paused: true);
      DateTime due = r.nextDue;
      int guard = 0;
      while (!due.isAfter(now) && guard < 400) {
        due = RecurringExpense.advance(due, r.frequency, r.dayOfMonth);
        guard++;
      }
      return r.copyWith(paused: false, nextDue: due);
    }).toList();
    _saveRecurring(list);
    notifyListeners();
  }

  void deleteRecurringExpense(String id) {
    final List<RecurringExpense> list =
        recurringExpenses.where((r) => r.id != id).toList();
    _saveRecurring(list);
    notifyListeners();
  }

  /// Cobros recurrentes (no pausados) que vencen en los próximos [days] días.
  List<RecurringExpense> recurringDueWithin(int days) {
    final DateTime now = DateTime.now();
    final DateTime limit = now.add(Duration(days: days));
    final List<RecurringExpense> result = recurringExpenses
        .where((r) => !r.paused && !r.nextDue.isBefore(now) && !r.nextDue.isAfter(limit))
        .toList()
      ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    return result;
  }

  /// Permite a la UI pedir un refresco tras `applyRecurringExpenses()`.
  void notifyChanged() => notifyListeners();

  /// Crea los gastos de los cobros que ya vencieron para cada recurrente
  /// activo. Devuelve cuántos gastos se generaron. No notifica: lo hace el
  /// que llama.
  int applyRecurringExpenses() {
    return _applyRecurringExpensesOnly() + _applyRecurringIncomes();
  }

  int _applyRecurringExpensesOnly() {
    final List<RecurringExpense> list = recurringExpenses;
    if (list.isEmpty) return 0;

    final DateTime now = DateTime.now();
    int created = 0;
    bool changed = false;
    final List<RecurringExpense> updated = [];

    for (final r in list) {
      if (r.paused) {
        updated.add(r);
        continue;
      }
      DateTime due = r.nextDue;
      int iterations = 0;
      int createdForItem = 0;
      while (!due.isAfter(now) && iterations < 400) {
        // Tope de seguridad: máximo 60 cobros atrasados por recurrente.
        if (createdForItem < 60) {
          final Expense expense = Expense(
            id: generateId(),
            name: r.name,
            amount: r.amount,
            currency: r.currency,
            category: r.category,
            date: due,
          );
          expensesBox.put(expense.id, expense);
          created++;
          createdForItem++;
        }
        due = RecurringExpense.advance(due, r.frequency, r.dayOfMonth);
        iterations++;
      }
      if (due != r.nextDue) {
        changed = true;
        updated.add(r.copyWith(nextDue: due));
      } else {
        updated.add(r);
      }
    }

    if (changed) _saveRecurring(updated);
    return created;
  }

  // ---------------------------------------------------------------------
  // Ingresos recurrentes (sueldo semanal, quincenal, mensual...)
  // ---------------------------------------------------------------------

  String get _recurringIncomeKey => '$_recurringIncomeKeyPrefix$_workspaceId';

  List<RecurringIncome> get recurringIncomes {
    final dynamic raw = settingsBox.get(_recurringIncomeKey);
    final List<RecurringIncome> result = [];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          try {
            result.add(RecurringIncome.fromMap(item));
          } catch (_) {}
        }
      }
    }
    return result;
  }

  Future<void> _saveRecurringIncomes(List<RecurringIncome> list) async {
    await settingsBox.put(_recurringIncomeKey, list.map((r) => r.toMap()).toList());
  }

  DateTime _normalizedDue(String frequency, DateTime date) {
    return frequency == RecurringExpense.semimonthly
        ? RecurringExpense.snapSemimonthly(date)
        : DateTime(date.year, date.month, date.day, 9);
  }

  /// El primer pago cae en [firstDue]; si esa fecha ya pasó, se registran
  /// enseguida los pagos atrasados hasta hoy.
  void addRecurringIncome({
    required String label,
    required double amount,
    required String currency,
    required String frequency,
    required DateTime firstDue,
  }) {
    final DateTime due = _normalizedDue(frequency, firstDue);
    final List<RecurringIncome> list = recurringIncomes
      ..add(RecurringIncome(
        id: generateId(),
        label: label,
        amount: amount,
        currency: currency,
        frequency: frequency,
        dayOfMonth: due.day,
        paused: false,
        nextDue: due,
      ));
    _saveRecurringIncomes(list);
    _applyRecurringIncomes();
    notifyListeners();
  }

  void updateRecurringIncome({
    required String id,
    required String label,
    required double amount,
    required String currency,
    required String frequency,
    required DateTime nextDue,
  }) {
    final DateTime due = _normalizedDue(frequency, nextDue);
    final List<RecurringIncome> list = recurringIncomes
        .map((r) => r.id == id
            ? r.copyWith(
                label: label,
                amount: amount,
                currency: currency,
                frequency: frequency,
                dayOfMonth: due.day,
                nextDue: due,
              )
            : r)
        .toList();
    _saveRecurringIncomes(list);
    _applyRecurringIncomes();
    notifyListeners();
  }

  void toggleRecurringIncomePaused(String id) {
    final DateTime now = DateTime.now();
    final List<RecurringIncome> list = recurringIncomes.map((r) {
      if (r.id != id) return r;
      if (!r.paused) return r.copyWith(paused: true);
      DateTime due = r.nextDue;
      int guard = 0;
      while (!due.isAfter(now) && guard < 400) {
        due = RecurringExpense.advance(due, r.frequency, r.dayOfMonth);
        guard++;
      }
      return r.copyWith(paused: false, nextDue: due);
    }).toList();
    _saveRecurringIncomes(list);
    notifyListeners();
  }

  void deleteRecurringIncome(String id) {
    _saveRecurringIncomes(recurringIncomes.where((r) => r.id != id).toList());
    notifyListeners();
  }

  /// Registra como ingresos los pagos recurrentes que ya vencieron. Devuelve
  /// cuántos creó. No notifica: lo hace el que llama.
  int _applyRecurringIncomes() {
    final List<RecurringIncome> list = recurringIncomes;
    if (list.isEmpty) return 0;

    final DateTime now = DateTime.now();
    int created = 0;
    bool changed = false;
    final List<RecurringIncome> updated = [];

    for (final r in list) {
      if (r.paused) {
        updated.add(r);
        continue;
      }
      DateTime due = r.nextDue;
      int iterations = 0;
      int createdForItem = 0;
      while (!due.isAfter(now) && iterations < 400) {
        if (createdForItem < 60) {
          final Income income = Income(
            id: generateId(),
            label: r.label,
            amount: r.amount,
            currency: r.currency,
            date: due,
          );
          incomesBox.put(income.id, income);
          created++;
          createdForItem++;
        }
        due = RecurringExpense.advance(due, r.frequency, r.dayOfMonth);
        iterations++;
      }
      if (due != r.nextDue) {
        changed = true;
        updated.add(r.copyWith(nextDue: due));
      } else {
        updated.add(r);
      }
    }
    if (changed) _saveRecurringIncomes(updated);
    return created;
  }

  // ---------------------------------------------------------------------
  // Periodo de pago, presupuesto y próximo pago
  // ---------------------------------------------------------------------

  /// 'calendar' (mes calendario) o 'pay' (periodo de pago: desde tu último
  /// ingreso).
  String get budgetMode =>
      (settingsBox.get(_budgetModeKey, defaultValue: 'calendar') as String);

  void setBudgetMode(String mode) {
    settingsBox.put(_budgetModeKey, mode == 'pay' ? 'pay' : 'calendar');
    notifyListeners();
  }

  /// Si es `true` (solo en modo calendario), lo que no gastaste de un
  /// presupuesto el mes pasado se suma al de este mes.
  bool get budgetRollover =>
      (settingsBox.get(_budgetRolloverKey, defaultValue: false) as bool);

  void setBudgetRollover(bool value) {
    settingsBox.put(_budgetRolloverKey, value);
    notifyListeners();
  }

  /// Ingreso más reciente que ya ocurrió (inicio del periodo de pago actual).
  Income? get currentPayIncome {
    final DateTime now = DateTime.now();
    Income? best;
    for (final i in incomesBox.values) {
      if (i.date.isAfter(now)) continue;
      if (best == null || i.date.isAfter(best.date)) best = i;
    }
    return best;
  }

  /// Ingreso inmediatamente anterior a [current] (inicio del periodo previo).
  Income? previousPayIncome(Income current) {
    Income? best;
    for (final i in incomesBox.values) {
      if (!i.date.isBefore(current.date)) continue;
      if (best == null || i.date.isAfter(best.date)) best = i;
    }
    return best;
  }

  /// `true` si los presupuestos se miden por periodo de pago ahora mismo.
  bool get isPayPeriodBudget => budgetMode == 'pay' && currentPayIncome != null;

  /// Rango en el que se miden los presupuestos: el periodo de pago actual o
  /// el mes calendario.
  ({DateTime start, DateTime? end}) budgetPeriod() {
    if (budgetMode == 'pay') {
      final Income? current = currentPayIncome;
      if (current != null) return (start: current.date, end: null);
    }
    final DateTime now = DateTime.now();
    return (start: DateTime(now.year, now.month, 1), end: DateTime(now.year, now.month + 1, 1));
  }

  /// Próximo pago: el del ingreso recurrente más cercano o, si no hay,
  /// una estimación con el intervalo típico entre tus últimos pagos.
  NextPayment? nextExpectedPayment() {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    DateTime? soonest;
    for (final r in recurringIncomes) {
      if (r.paused) continue;
      if (soonest == null || r.nextDue.isBefore(soonest)) soonest = r.nextDue;
    }
    if (soonest != null) return NextPayment(date: soonest, estimated: false);

    final List<Income> recent = incomes.where((i) => !i.date.isAfter(now)).take(4).toList();
    if (recent.length < 2) return null;
    int totalDays = 0;
    for (int i = 0; i < recent.length - 1; i++) {
      totalDays += recent[i].date.difference(recent[i + 1].date).inDays;
    }
    final double average = totalDays / (recent.length - 1);
    if (average < 1 || average > 62) return null;
    final DateTime expected = recent.first.date.add(Duration(days: average.round()));
    if (DateTime(expected.year, expected.month, expected.day).isBefore(today)) return null;
    return NextPayment(date: expected, estimated: true);
  }

  // ---------------------------------------------------------------------
  // Cuentas y transferencias
  // ---------------------------------------------------------------------

  String get _accountsKey => '$_accountsKeyPrefix$_workspaceId';
  String get _transfersKey => '$_transfersKeyPrefix$_workspaceId';
  String get _lastAccountKey => '$_lastAccountKeyPrefix$_workspaceId';

  List<Account> get accounts {
    final dynamic raw = settingsBox.get(_accountsKey);
    final List<Account> result = [];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          try {
            result.add(Account.fromMap(item));
          } catch (_) {}
        }
      }
    }
    return result;
  }

  Future<void> _saveAccounts(List<Account> list) async {
    await settingsBox.put(_accountsKey, list.map((a) => a.toMap()).toList());
  }

  List<Transfer> get transfers {
    final dynamic raw = settingsBox.get(_transfersKey);
    final List<Transfer> result = [];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          try {
            result.add(Transfer.fromMap(item));
          } catch (_) {}
        }
      }
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  Future<void> _saveTransfers(List<Transfer> list) async {
    await settingsBox.put(_transfersKey, list.map((t) => t.toMap()).toList());
  }

  /// Última cuenta usada (se preselecciona al registrar un gasto o ingreso).
  String? get lastAccountId {
    final dynamic id = settingsBox.get(_lastAccountKey);
    if (id is! String) return null;
    return accounts.any((a) => a.id == id) ? id : null;
  }

  void setLastAccountId(String? id) {
    if (id == null) {
      settingsBox.delete(_lastAccountKey);
    } else {
      settingsBox.put(_lastAccountKey, id);
    }
  }

  void addAccount({
    required String name,
    required String type,
    required String currency,
    required double initialBalance,
  }) {
    final List<Account> list = accounts
      ..add(Account(
        id: generateId(),
        name: name.trim(),
        type: type,
        currency: currency,
        initialBalance: initialBalance,
      ));
    _saveAccounts(list);
    notifyListeners();
  }

  void updateAccount({
    required String id,
    required String name,
    required String type,
    required double initialBalance,
  }) {
    _saveAccounts(accounts
        .map((a) => a.id == id ? a.copyWith(name: name.trim(), type: type, initialBalance: initialBalance) : a)
        .toList());
    notifyListeners();
  }

  /// Borra la cuenta. Sus gastos e ingresos no se borran: quedan "sin cuenta".
  void deleteAccount(String id) {
    for (final e in expensesBox.values.where((e) => e.accountId == id).toList()) {
      e.accountId = null;
      expensesBox.put(e.id, e);
    }
    for (final i in incomesBox.values.where((i) => i.accountId == id).toList()) {
      i.accountId = null;
      incomesBox.put(i.id, i);
    }
    _saveTransfers(transfers.where((t) => t.fromId != id && t.toId != id).toList());
    _saveAccounts(accounts.where((a) => a.id != id).toList());
    if (settingsBox.get(_lastAccountKey) == id) settingsBox.delete(_lastAccountKey);
    notifyListeners();
  }

  void addTransfer({
    required String fromId,
    required String toId,
    required double fromAmount,
    required double toAmount,
  }) {
    final List<Transfer> list = transfers
      ..add(Transfer(
        id: generateId(),
        fromId: fromId,
        toId: toId,
        fromAmount: fromAmount,
        toAmount: toAmount,
        date: DateTime.now(),
      ));
    _saveTransfers(list);
    notifyListeners();
  }

  void deleteTransfer(String id) {
    _saveTransfers(transfers.where((t) => t.id != id).toList());
    notifyListeners();
  }

  /// Saldo actual de la cuenta en su propia divisa: saldo inicial + ingresos
  /// asignados - gastos asignados +/- transferencias.
  double accountBalance(Account account, CurrencyProvider currency) {
    double balance = account.initialBalance;
    for (final e in expensesBox.values) {
      if (e.accountId == account.id) {
        balance -= currency.convert(e.amount, e.currency, account.currency);
      }
    }
    for (final i in incomesBox.values) {
      if (i.accountId == account.id) {
        balance += currency.convert(i.amount, i.currency, account.currency);
      }
    }
    for (final t in transfers) {
      if (t.fromId == account.id) balance -= t.fromAmount;
      if (t.toId == account.id) balance += t.toAmount;
    }
    return balance;
  }

  // ---------------------------------------------------------------------
  // Suscripciones detectadas que el usuario descartó
  // ---------------------------------------------------------------------

  static const String _ignoredSubsKey = 'ignoredSubscriptions';

  Set<String> get ignoredSubscriptionNames {
    final dynamic raw = settingsBox.get(_ignoredSubsKey);
    if (raw is List) return raw.map((e) => e.toString().toLowerCase()).toSet();
    return <String>{};
  }

  void ignoreSubscription(String name) {
    final Set<String> set = ignoredSubscriptionNames..add(name.trim().toLowerCase());
    settingsBox.put(_ignoredSubsKey, set.toList());
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Deudas y préstamos
  // ---------------------------------------------------------------------

  String get _debtsKey => '$_debtsKeyPrefix$_workspaceId';

  List<Debt> get debts {
    final dynamic raw = settingsBox.get(_debtsKey);
    final List<Debt> result = [];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          try {
            result.add(Debt.fromMap(item));
          } catch (_) {}
        }
      }
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  Future<void> _saveDebts(List<Debt> list) async {
    await settingsBox.put(_debtsKey, list.map((d) => d.toMap()).toList());
  }

  void addDebt({
    required String person,
    required double amount,
    required String currency,
    required bool owedToMe,
    String? note,
    DateTime? date,
  }) {
    final List<Debt> list = debts
      ..add(Debt(
        id: generateId(),
        person: person,
        amount: amount,
        currency: currency,
        owedToMe: owedToMe,
        date: date ?? DateTime.now(),
        paid: false,
        note: (note == null || note.trim().isEmpty) ? null : note.trim(),
      ));
    _saveDebts(list);
    notifyListeners();
  }

  void toggleDebtPaid(String id) {
    _saveDebts(debts.map((d) => d.id == id ? d.copyWith(paid: !d.paid) : d).toList());
    notifyListeners();
  }

  void deleteDebt(String id) {
    _saveDebts(debts.where((d) => d.id != id).toList());
    notifyListeners();
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
    String? accountId,
  }) {
    final income = Income(
      id: generateId(),
      label: label,
      amount: amount,
      currency: currency,
      date: date ?? DateTime.now(),
      accountId: accountId,
    );
    incomesBox.put(income.id, income);
    notifyListeners();
  }

  void updateIncome({
    required String id,
    required String label,
    required double amount,
    required String currency,
    required DateTime date,
    String? accountId,
  }) {
    final Income? income = incomesBox.get(id);
    if (income == null) return;
    income.accountId = accountId;
    income.label = label;
    income.amount = amount;
    income.currency = currency;
    income.date = date;
    incomesBox.put(id, income);
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
    DateTime? targetDate,
  }) {
    final vault = Vault(
      id: generateId(),
      name: name,
      targetAmount: targetAmount,
      currentAmount: 0,
      currency: currency,
      targetDate: targetDate,
    );
    vaultsBox.put(vault.id, vault);
    notifyListeners();
  }

  /// Edita nombre, meta y fecha límite. La divisa de una bóveda no cambia
  /// nunca (su saldo está expresado en ella). Pasar `targetDate: null`
  /// quita la fecha límite.
  void updateVault({
    required String id,
    required String name,
    required double targetAmount,
    DateTime? targetDate,
  }) {
    final Vault? vault = vaultsBox.get(id);
    if (vault == null) return;
    vault.name = name;
    vault.targetAmount = targetAmount;
    vault.targetDate = targetDate;
    vault.save();
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
      'formatVersion': 5,
      'workspaceName': activeWorkspace.name,
      'localCurrency': _localCurrency,
      'expenses': expensesBox.values.map((e) => e.toJson()).toList(),
      'incomes': incomesBox.values.map((i) => i.toJson()).toList(),
      'vaults': vaultsBox.values.map((v) => v.toJson()).toList(),
      'vaultTransactions': vaultTransactionsBox.values.map((t) => t.toJson()).toList(),
      'budgets': budgets,
      'recurring': recurringExpenses.map((r) => r.toMap()).toList(),
      'customCategories': CategoryRegistry.custom.map((c) => c.toMap()).toList(),
      'recurringIncomes': recurringIncomes.map((r) => r.toMap()).toList(),
      'debts': debts.map((d) => d.toMap()).toList(),
      'accounts': accounts.map((a) => a.toMap()).toList(),
      'transfers': transfers.map((t) => t.toMap()).toList(),
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

  /// Importa un respaldo. Con [merge] = false reemplaza TODO el contenido
  /// del espacio activo; con [merge] = true suma lo del archivo a lo que ya
  /// hay (los registros con el mismo id se actualizan, el resto se conserva).
  Future<void> importData(Map<String, dynamic> data, {bool merge = false}) async {
    if (!merge) {
      await expensesBox.clear();
      await incomesBox.clear();
      await vaultsBox.clear();
      await vaultTransactionsBox.clear();

      final String importedCurrency = (data['localCurrency'] as String?) ?? 'USD';
      setLocalCurrency(importedCurrency);
    }

    // Categorías personalizadas: se agregan las que falten (en ambos modos),
    // antes que los gastos que las usan.
    final dynamic categoriesJson = data['customCategories'];
    if (categoriesJson is List) {
      final List<CustomCategory> merged = List<CustomCategory>.of(CategoryRegistry.custom);
      for (final item in categoriesJson) {
        if (item is Map) {
          try {
            final CustomCategory c = CustomCategory.fromMap(item);
            if (!merged.any((m) => m.name == c.name) &&
                !ExpenseCategory.builtIn.contains(c.name)) {
              merged.add(c);
            }
          } catch (_) {}
        }
      }
      await _saveCustomCategories(merged);
    }

    final List<dynamic> expensesJson = (data['expenses'] as List?) ?? [];
    for (final item in expensesJson) {
      final expense = Expense.fromJson(Map<String, dynamic>.from(item as Map));
      await expensesBox.put(expense.id, expense);
    }

    final List<dynamic> incomesJson = (data['incomes'] as List?) ?? [];
    for (final item in incomesJson) {
      final income = Income.fromJson(Map<String, dynamic>.from(item as Map));
      await incomesBox.put(income.id, income);
    }

    final List<dynamic> vaultsJson = (data['vaults'] as List?) ?? [];
    for (final item in vaultsJson) {
      final vault = Vault.fromJson(Map<String, dynamic>.from(item as Map));
      await vaultsBox.put(vault.id, vault);
    }

    final List<dynamic> txJson = (data['vaultTransactions'] as List?) ?? [];
    for (final item in txJson) {
      final tx = VaultTransaction.fromJson(Map<String, dynamic>.from(item as Map));
      await vaultTransactionsBox.put(tx.id, tx);
    }

    // Presupuestos y recurrentes existen solo en respaldos formatVersion >= 2.
    final dynamic budgetsJson = data['budgets'];
    if (budgetsJson is Map) {
      final Map<String, double> imported = merge ? budgets : {};
      budgetsJson.forEach((key, value) {
        if (value is num && (!merge || !imported.containsKey(key.toString()))) {
          imported[key.toString()] = value.toDouble();
        }
      });
      await settingsBox.put(_budgetsKey, imported);
    }

    final dynamic recurringJson = data['recurring'];
    if (recurringJson is List) {
      final List<RecurringExpense> imported = merge ? recurringExpenses : [];
      for (final item in recurringJson) {
        if (item is Map) {
          try {
            final RecurringExpense r = RecurringExpense.fromMap(item);
            if (!imported.any((x) => x.id == r.id)) imported.add(r);
          } catch (_) {}
        }
      }
      await _saveRecurring(imported);
    }

    final dynamic recurringIncomesJson = data['recurringIncomes'];
    if (recurringIncomesJson is List) {
      final List<RecurringIncome> imported = merge ? recurringIncomes : [];
      for (final item in recurringIncomesJson) {
        if (item is Map) {
          try {
            final RecurringIncome r = RecurringIncome.fromMap(item);
            if (!imported.any((x) => x.id == r.id)) imported.add(r);
          } catch (_) {}
        }
      }
      await _saveRecurringIncomes(imported);
    }

    final dynamic debtsJson = data['debts'];
    if (debtsJson is List) {
      final List<Debt> imported = merge ? debts : [];
      for (final item in debtsJson) {
        if (item is Map) {
          try {
            final Debt d = Debt.fromMap(item);
            if (!imported.any((x) => x.id == d.id)) imported.add(d);
          } catch (_) {}
        }
      }
      await _saveDebts(imported);
    }

    final dynamic accountsJson = data['accounts'];
    if (accountsJson is List) {
      final List<Account> imported = merge ? accounts : [];
      for (final item in accountsJson) {
        if (item is Map) {
          try {
            final Account a = Account.fromMap(item);
            if (!imported.any((x) => x.id == a.id)) imported.add(a);
          } catch (_) {}
        }
      }
      await _saveAccounts(imported);
    }

    final dynamic transfersJson = data['transfers'];
    if (transfersJson is List) {
      final List<Transfer> imported = merge ? transfers : [];
      for (final item in transfersJson) {
        if (item is Map) {
          try {
            final Transfer t = Transfer.fromMap(item);
            if (!imported.any((x) => x.id == t.id)) imported.add(t);
          } catch (_) {}
        }
      }
      await _saveTransfers(imported);
    }

    notifyListeners();
  }
}
