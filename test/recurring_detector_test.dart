import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/recurring_expense.dart';
import 'package:expense_tracker/utils/recurring_detector.dart';

Expense _e(String name, DateTime date, double amount, {String currency = 'USD'}) => Expense(
      id: '${name}_${date.toIso8601String()}',
      name: name,
      amount: amount,
      currency: currency,
      category: 'servicios',
      date: date,
    );

void main() {
  final DateTime now = DateTime(2026, 10, 18, 12);

  test('detecta una suscripción mensual', () {
    final list = [
      _e('Netflix', DateTime(2026, 7, 5, 9), 15.99),
      _e('Netflix', DateTime(2026, 8, 5, 9), 15.99),
      _e('Netflix', DateTime(2026, 9, 5, 9), 15.99),
      _e('Netflix', DateTime(2026, 10, 5, 9), 15.99),
    ];
    final r = detectRecurringPatterns(list, existingNames: {}, ignoredNames: {}, now: now);
    expect(r.length, 1);
    expect(r.first.frequency, RecurringExpense.monthly);
    expect(r.first.occurrences, 4);
    expect(r.first.amount, 15.99);
    expect(r.first.nextDue.isAfter(now), isTrue);
    expect([r.first.nextDue.month, r.first.nextDue.day], [11, 5]);
  });

  test('detecta una semanal', () {
    final list = [
      for (int i = 0; i < 5; i++) _e('Gimnasio', DateTime(2026, 9, 20 + i * 7, 18), 10),
    ];
    final r = detectRecurringPatterns(list, existingNames: {}, ignoredNames: {}, now: now);
    expect(r.single.frequency, RecurringExpense.weekly);
  });

  test('ignora gastos irregulares, con importes muy distintos o pocos repetidos', () {
    final irregular = [
      _e('Café', DateTime(2026, 9, 1), 3),
      _e('Café', DateTime(2026, 9, 4), 3),
      _e('Café', DateTime(2026, 10, 2), 3),
      _e('Café', DateTime(2026, 10, 3), 3),
    ];
    final varied = [
      _e('Luz', DateTime(2026, 7, 5), 30),
      _e('Luz', DateTime(2026, 8, 5), 90),
      _e('Luz', DateTime(2026, 9, 5), 45),
    ];
    final few = [
      _e('Seguro', DateTime(2026, 9, 5), 50),
      _e('Seguro', DateTime(2026, 10, 5), 50),
    ];
    final r = detectRecurringPatterns([...irregular, ...varied, ...few],
        existingNames: {}, ignoredNames: {}, now: now);
    expect(r, isEmpty);
  });

  test('respeta los ya recurrentes y los descartados', () {
    final list = [
      _e('Netflix', DateTime(2026, 8, 5, 9), 15),
      _e('Netflix', DateTime(2026, 9, 5, 9), 15),
      _e('Netflix', DateTime(2026, 10, 5, 9), 15),
    ];
    expect(detectRecurringPatterns(list, existingNames: {'netflix'}, ignoredNames: {}, now: now), isEmpty);
    expect(detectRecurringPatterns(list, existingNames: {}, ignoredNames: {'netflix'}, now: now), isEmpty);
  });

  test('ignora suscripciones que dejaron de repetirse hace mucho', () {
    final list = [
      _e('Revista', DateTime(2026, 1, 5, 9), 8),
      _e('Revista', DateTime(2026, 2, 5, 9), 8),
      _e('Revista', DateTime(2026, 3, 5, 9), 8),
    ];
    expect(detectRecurringPatterns(list, existingNames: {}, ignoredNames: {}, now: now), isEmpty);
  });
}
