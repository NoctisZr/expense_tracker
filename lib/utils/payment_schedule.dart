import '../models/credit_purchase.dart';
import '../models/recurring_expense.dart';
import '../models/recurring_income.dart';

/// Pagos e ingresos PROGRAMADOS (lo que viene), para el calendario de pagos.
/// Lógica pura: sin Flutter ni Hive.

enum ScheduledKind { expense, income, installment, fixed }

class ScheduledItem {
  final DateTime date;
  final String title;
  final String? subtitle;
  final double amount;
  final String currency;
  final ScheduledKind kind;

  const ScheduledItem({
    required this.date,
    required this.title,
    required this.amount,
    required this.currency,
    required this.kind,
    this.subtitle,
  });

  bool get isIncome => kind == ScheduledKind.income;
}

/// Primer y último instante de un mes.
({DateTime from, DateTime to}) monthRange(DateTime month) =>
    (from: DateTime(month.year, month.month, 1), to: DateTime(month.year, month.month + 1, 0, 23, 59, 59));

/// Fechas de un recurrente entre [from] y [to], a partir de su próximo
/// vencimiento ([nextDue]). Las ya generadas quedaron atrás de [nextDue].
List<DateTime> occurrencesBetween({
  required DateTime nextDue,
  required String frequency,
  required int dayOfMonth,
  required DateTime from,
  required DateTime to,
  int cap = 400,
}) {
  final List<DateTime> out = [];
  DateTime d = nextDue;
  for (int i = 0; i < cap; i++) {
    if (d.isAfter(to)) break;
    if (!d.isBefore(from)) out.add(d);
    d = RecurringExpense.advance(d, frequency, dayOfMonth);
  }
  return out;
}

/// Todo lo programado entre [from] y [to], ordenado por fecha.
/// [fixed] son los gastos fijos compartidos de pareja (mapas `couple_fixed`).
List<ScheduledItem> scheduledForRange({
  required DateTime from,
  required DateTime to,
  List<RecurringExpense> expenses = const [],
  List<RecurringIncome> incomes = const [],
  List<CreditPurchase> credits = const [],
  List<Map<String, dynamic>> fixed = const [],
}) {
  final List<ScheduledItem> out = [];

  for (final r in expenses) {
    if (r.paused) continue;
    for (final d in occurrencesBetween(
        nextDue: r.nextDue, frequency: r.frequency, dayOfMonth: r.dayOfMonth, from: from, to: to)) {
      out.add(ScheduledItem(
        date: d,
        title: r.name,
        subtitle: r.category,
        amount: r.amount,
        currency: r.currency,
        kind: ScheduledKind.expense,
      ));
    }
  }

  for (final r in incomes) {
    if (r.paused) continue;
    for (final d in occurrencesBetween(
        nextDue: r.nextDue, frequency: r.frequency, dayOfMonth: r.dayOfMonth, from: from, to: to)) {
      out.add(ScheduledItem(
        date: d,
        title: r.label,
        amount: r.amount,
        currency: r.currency,
        kind: ScheduledKind.income,
      ));
    }
  }

  for (final c in credits) {
    final schedule = c.schedule;
    for (int n = c.registeredCount + 1; n <= schedule.length; n++) {
      final DateTime d = schedule[n - 1].dueDate;
      if (d.isAfter(to)) break;
      if (d.isBefore(from)) continue;
      out.add(ScheduledItem(
        date: d,
        title: '${c.name} ($n/${schedule.length})',
        amount: c.amountFor(n),
        currency: c.currency,
        kind: ScheduledKind.installment,
      ));
    }
  }

  for (final f in fixed) {
    final DateTime? start = DateTime.tryParse((f['start'] ?? '').toString());
    if (start == null) continue;
    final int day = ((f['day'] as num?)?.toInt() ?? 1).clamp(1, 28).toInt();
    final double total = (f['t'] as num?)?.toDouble() ?? 0;
    final double share = (f['sh'] as num?)?.toDouble() ?? 100;
    DateTime cursor = DateTime(from.year, from.month, 1);
    while (!cursor.isAfter(to)) {
      final DateTime d = DateTime(cursor.year, cursor.month, day, 9);
      if (d.isAfter(start) && !d.isBefore(from) && !d.isAfter(to)) {
        out.add(ScheduledItem(
          date: d,
          title: (f['n'] ?? '').toString(),
          amount: double.parse((total * share / 100).toStringAsFixed(2)),
          currency: (f['c'] ?? '').toString(),
          kind: ScheduledKind.fixed,
        ));
      }
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
  }

  out.sort((a, b) {
    final int byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.kind.index.compareTo(b.kind.index);
  });
  return out;
}
