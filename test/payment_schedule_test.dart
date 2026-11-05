import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/credit_purchase.dart';
import 'package:expense_tracker/models/recurring_expense.dart';
import 'package:expense_tracker/models/recurring_income.dart';
import 'package:expense_tracker/utils/amortization.dart';
import 'package:expense_tracker/utils/payment_schedule.dart';

RecurringExpense _rec(String name, String freq, DateTime due, {int day = 5, bool paused = false}) => RecurringExpense(
      id: name, name: name, amount: 10, currency: 'USD', category: 'servicios',
      frequency: freq, dayOfMonth: day, paused: paused, nextDue: due,
    );

void main() {
  final nov = monthRange(DateTime(2026, 11, 15));

  group('fechas de recurrentes', () {
    List<DateTime> occ(String freq, DateTime due, {int day = 5}) =>
        occurrencesBetween(nextDue: due, frequency: freq, dayOfMonth: day, from: nov.from, to: nov.to);

    test('mensual', () {
      expect(occ('monthly', DateTime(2026, 11, 5, 9)), [DateTime(2026, 11, 5, 9)]);
    });
    test('semanal: 5 lunes en noviembre', () {
      final d = occ('weekly', DateTime(2026, 11, 2, 9));
      expect(d.length, 5);
      expect(d.last, DateTime(2026, 11, 30, 9));
    });
    test('quincenal día 15 y fin de mes', () {
      expect(occ('semimonthly', DateTime(2026, 11, 15, 9)), [DateTime(2026, 11, 15, 9), DateTime(2026, 11, 30, 9)]);
    });
    test('anual solo en su mes', () {
      expect(occ('yearly', DateTime(2027, 3, 10, 9), day: 10), isEmpty);
      final mar = monthRange(DateTime(2027, 3, 1));
      expect(
        occurrencesBetween(nextDue: DateTime(2027, 3, 10, 9), frequency: 'yearly', dayOfMonth: 10, from: mar.from, to: mar.to),
        [DateTime(2027, 3, 10, 9)],
      );
    });
    test('un vencimiento atrasado salta hasta el mes pedido', () {
      expect(occ('monthly', DateTime(2026, 9, 5, 9)), [DateTime(2026, 11, 5, 9)]);
    });
    test('el tope evita bucles', () {
      final far = occurrencesBetween(
          nextDue: DateTime(2026, 1, 1, 9), frequency: 'weekly', dayOfMonth: 1,
          from: DateTime(2026, 1, 1), to: DateTime(2100, 1, 1), cap: 10);
      expect(far.length, 10);
    });
  });

  group('todo lo programado', () {
    test('mezcla gastos, ingresos, cuotas y gastos fijos, ordenado por fecha', () {
      final credit = CreditPurchase(
        id: 'c1', name: 'Laptop', category: 'compras', purchaseDate: DateTime(2026, 10, 1), currency: 'USD',
        financed: 1200, registeredCount: 1,
        terms: LoanTerms(
          principal: 1200, installments: 3, firstDue: DateTime(2026, 10, 20, 9),
          rateType: RateType.none, ratePercent: 0, method: LoanMethod.french,
        ),
      );
      final items = scheduledForRange(
        from: nov.from,
        to: nov.to,
        expenses: [_rec('Netflix', 'monthly', DateTime(2026, 11, 5, 9)), _rec('Pausado', 'monthly', DateTime(2026, 11, 6, 9), paused: true)],
        incomes: [
          RecurringIncome(id: 'i', label: 'Sueldo', amount: 900, currency: 'USD', frequency: 'monthly', dayOfMonth: 28, paused: false, nextDue: DateTime(2026, 11, 28, 9)),
        ],
        credits: [credit],
        fixed: [
          {'id': 'f1', 'n': 'Renta', 't': 800.0, 'c': 'USD', 'day': 1, 'sh': 50.0, 'start': DateTime(2026, 10, 15).toIso8601String()},
        ],
      );
      expect(items.map((e) => e.title), ['Renta', 'Netflix', 'Laptop (2/3)', 'Sueldo']);
      expect(items.first.amount, 400.0); // tu parte del 50 %
      expect(items.first.kind, ScheduledKind.fixed);
      expect(items[2].amount, 400.0);
      expect(items.last.isIncome, isTrue);
    });

    test('el gasto fijo no cuenta antes de su fecha de inicio', () {
      final items = scheduledForRange(
        from: nov.from,
        to: nov.to,
        fixed: [
          {'id': 'f1', 'n': 'Renta', 't': 800.0, 'c': 'USD', 'day': 1, 'sh': 50.0, 'start': DateTime(2026, 11, 10).toIso8601String()},
        ],
      );
      expect(items, isEmpty);
    });

    test('cuotas ya registradas no aparecen', () {
      final credit = CreditPurchase(
        id: 'c1', name: 'TV', category: 'compras', purchaseDate: DateTime(2026, 9, 1), currency: 'USD',
        financed: 300, registeredCount: 3,
        terms: LoanTerms(principal: 300, installments: 3, firstDue: DateTime(2026, 9, 10, 9), rateType: RateType.none, ratePercent: 0),
      );
      expect(scheduledForRange(from: nov.from, to: nov.to, credits: [credit]), isEmpty);
    });
  });
}
