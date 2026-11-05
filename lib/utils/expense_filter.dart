import '../models/expense.dart';

/// Búsqueda y filtros de Movimientos (lógica PURA, sin Flutter).

enum ExpenseSort { newest, oldest, amountDesc, amountAsc }

enum ExpenseKindFilter { any, personal, couple, credit }

DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

class ExpenseFilter {
  final String query;
  final Set<String> categories;
  final Set<String> tags;

  /// Fechas inclusivas (de [from] a [to], ambas incluidas).
  final DateTime? from;
  final DateTime? to;
  final String? accountId;
  final String? currency;

  /// Rango de monto en la moneda local.
  final double? minAmount;
  final double? maxAmount;
  final ExpenseKindFilter kind;
  final ExpenseSort sort;

  const ExpenseFilter({
    this.query = '',
    this.categories = const {},
    this.tags = const {},
    this.from,
    this.to,
    this.accountId,
    this.currency,
    this.minAmount,
    this.maxAmount,
    this.kind = ExpenseKindFilter.any,
    this.sort = ExpenseSort.newest,
  });

  ExpenseFilter copyWith({
    String? query,
    Set<String>? categories,
    Set<String>? tags,
    DateTime? from,
    DateTime? to,
    bool clearRange = false,
    String? accountId,
    bool clearAccount = false,
    String? currency,
    bool clearCurrency = false,
    double? minAmount,
    bool clearMin = false,
    double? maxAmount,
    bool clearMax = false,
    ExpenseKindFilter? kind,
    ExpenseSort? sort,
  }) =>
      ExpenseFilter(
        query: query ?? this.query,
        categories: categories ?? this.categories,
        tags: tags ?? this.tags,
        from: clearRange ? null : (from ?? this.from),
        to: clearRange ? null : (to ?? this.to),
        accountId: clearAccount ? null : (accountId ?? this.accountId),
        currency: clearCurrency ? null : (currency ?? this.currency),
        minAmount: clearMin ? null : (minAmount ?? this.minAmount),
        maxAmount: clearMax ? null : (maxAmount ?? this.maxAmount),
        kind: kind ?? this.kind,
        sort: sort ?? this.sort,
      );

  /// Cuántos filtros (sin contar el texto ni el orden) están puestos.
  int get activeCount =>
      (categories.isNotEmpty ? 1 : 0) +
      (tags.isNotEmpty ? 1 : 0) +
      (from != null || to != null ? 1 : 0) +
      (accountId != null ? 1 : 0) +
      (currency != null ? 1 : 0) +
      (minAmount != null || maxAmount != null ? 1 : 0) +
      (kind != ExpenseKindFilter.any ? 1 : 0);

  bool get isActive => query.trim().isNotEmpty || activeCount > 0;

  /// Palabras de la búsqueda: sin '#' en las etiquetas y con punto decimal.
  List<String> get _tokens => query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .map((t) {
        String s = t.startsWith('#') ? t.substring(1) : t;
        if (RegExp(r'^\d+,\d+$').hasMatch(s)) s = s.replaceAll(',', '.');
        return s;
      })
      .where((t) => t.isNotEmpty)
      .toList();

  bool matches(
    Expense e, {
    required double Function(Expense) valueOf,
    required String Function(String category) categoryLabel,
    String Function(String? accountId)? accountName,
  }) {
    if (categories.isNotEmpty && !categories.contains(e.category)) return false;
    if (tags.isNotEmpty && !(e.tags ?? const <String>[]).any(tags.contains)) return false;
    if (from != null && e.date.isBefore(_dayStart(from!))) return false;
    if (to != null) {
      final DateTime end = _dayStart(to!);
      if (!e.date.isBefore(DateTime(end.year, end.month, end.day + 1))) return false;
    }
    if (accountId != null && e.accountId != accountId) return false;
    if (currency != null && e.currency != currency) return false;
    if (minAmount != null || maxAmount != null) {
      final double v = valueOf(e);
      if (minAmount != null && v < minAmount! - 0.0001) return false;
      if (maxAmount != null && v > maxAmount! + 0.0001) return false;
    }
    switch (kind) {
      case ExpenseKindFilter.personal:
        if (e.sharedTotal != null || e.creditId != null) return false;
        break;
      case ExpenseKindFilter.couple:
        if (e.sharedTotal == null) return false;
        break;
      case ExpenseKindFilter.credit:
        if (e.creditId == null) return false;
        break;
      case ExpenseKindFilter.any:
        break;
    }
    final List<String> tokens = _tokens;
    if (tokens.isNotEmpty) {
      final String haystack = [
        e.name,
        e.note ?? '',
        (e.tags ?? const <String>[]).join(' '),
        categoryLabel(e.category),
        e.category,
        e.amount.toStringAsFixed(2),
        e.currency,
        accountName?.call(e.accountId) ?? '',
      ].join(' ').toLowerCase();
      for (final t in tokens) {
        if (!haystack.contains(t)) return false;
      }
    }
    return true;
  }

  /// Aplica el filtro y ordena el resultado.
  List<Expense> apply(
    Iterable<Expense> all, {
    required double Function(Expense) valueOf,
    required String Function(String category) categoryLabel,
    String Function(String? accountId)? accountName,
  }) {
    final List<Expense> out = all
        .where((e) => matches(e, valueOf: valueOf, categoryLabel: categoryLabel, accountName: accountName))
        .toList();
    switch (sort) {
      case ExpenseSort.newest:
        out.sort((a, b) => b.date.compareTo(a.date));
        break;
      case ExpenseSort.oldest:
        out.sort((a, b) => a.date.compareTo(b.date));
        break;
      case ExpenseSort.amountDesc:
        out.sort((a, b) => valueOf(b).compareTo(valueOf(a)));
        break;
      case ExpenseSort.amountAsc:
        out.sort((a, b) => valueOf(a).compareTo(valueOf(b)));
        break;
    }
    return out;
  }
}

/// Rango de fechas de un periodo rápido ('today', 'week', 'month',
/// 'lastMonth', 'year'). La semana va de lunes a domingo.
({DateTime from, DateTime to}) periodRange(String key, DateTime now) {
  final DateTime today = _dayStart(now);
  switch (key) {
    case 'today':
      return (from: today, to: today);
    case 'week':
      final DateTime monday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
      return (from: monday, to: DateTime(monday.year, monday.month, monday.day + 6));
    case 'lastMonth':
      return (from: DateTime(today.year, today.month - 1, 1), to: DateTime(today.year, today.month, 0));
    case 'year':
      return (from: DateTime(today.year, 1, 1), to: DateTime(today.year, 12, 31));
    case 'month':
    default:
      return (from: DateTime(today.year, today.month, 1), to: DateTime(today.year, today.month + 1, 0));
  }
}

/// Qué periodo rápido corresponde a [from]–[to] (o null si es personalizado).
String? matchingPeriod(DateTime? from, DateTime? to, DateTime now) {
  if (from == null || to == null) return null;
  for (final String key in const ['today', 'week', 'month', 'lastMonth', 'year']) {
    final r = periodRange(key, now);
    if (_dayStart(from) == r.from && _dayStart(to) == r.to) return key;
  }
  return null;
}
