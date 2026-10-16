import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/recurring_expense.dart';

void main() {
  group('RecurringExpense.advance', () {
    test('mensual conserva el día ancla y se ajusta en meses cortos', () {
      final jan31 = DateTime(2026, 1, 31, 9);
      final feb = RecurringExpense.advance(jan31, RecurringExpense.monthly, 31);
      expect([feb.month, feb.day], [2, 28]);
      final mar = RecurringExpense.advance(feb, RecurringExpense.monthly, 31);
      expect([mar.month, mar.day], [3, 31]);
    });

    test('mensual pasa de diciembre a enero del año siguiente', () {
      final next = RecurringExpense.advance(DateTime(2026, 12, 15, 9), RecurringExpense.monthly, 15);
      expect([next.year, next.month, next.day], [2027, 1, 15]);
    });

    test('semanal suma 7 días', () {
      final next = RecurringExpense.advance(DateTime(2026, 12, 28, 9), RecurringExpense.weekly, 28);
      expect([next.year, next.month, next.day], [2027, 1, 4]);
    });

    test('anual respeta el 29 de febrero', () {
      final next = RecurringExpense.advance(DateTime(2028, 2, 29, 9), RecurringExpense.yearly, 29);
      expect([next.year, next.month, next.day], [2029, 2, 28]);
    });
  });

  group('RecurringExpense.fromMap', () {
    test('convierte el formato antiguo (lastGeneratedMonth)', () {
      final r = RecurringExpense.fromMap({
        'id': 'a',
        'name': 'Internet',
        'amount': 30,
        'currency': 'USD',
        'category': 'servicios',
        'dayOfMonth': 5,
        'lastGeneratedMonth': 2026 * 12 + 8, // septiembre de 2026
      });
      expect(r.frequency, RecurringExpense.monthly);
      expect(r.paused, isFalse);
      expect([r.nextDue.year, r.nextDue.month, r.nextDue.day], [2026, 10, 5]);
    });

    test('ida y vuelta toMap/fromMap', () {
      final original = RecurringExpense(
        id: 'b',
        name: 'Gym',
        amount: 20.5,
        currency: 'EUR',
        category: 'otros',
        frequency: RecurringExpense.weekly,
        dayOfMonth: 3,
        paused: true,
        nextDue: DateTime(2026, 11, 3, 9),
      );
      final copy = RecurringExpense.fromMap(original.toMap());
      expect(copy.frequency, RecurringExpense.weekly);
      expect(copy.paused, isTrue);
      expect(copy.nextDue, original.nextDue);
    });
  });
}
