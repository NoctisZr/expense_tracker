import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/utils/envelopes.dart';
import 'package:expense_tracker/utils/report_stats.dart';
import 'package:expense_tracker/utils/weekly_budget.dart';

void main() {
  group('semana', () {
    test('el lunes de una fecha a mitad de semana', () {
      // 28 oct 2026 es miércoles
      expect(weekStartOf(DateTime(2026, 10, 28, 15)), DateTime(2026, 10, 26));
    });
    test('un domingo pertenece a la semana que empezó el lunes anterior', () {
      expect(weekStartOf(DateTime(2026, 11, 1)), DateTime(2026, 10, 26));
    });
    test('cruza de mes y de año', () {
      expect(weekStartOf(DateTime(2027, 1, 1)), DateTime(2026, 12, 28)); // viernes
      expect(weekEndOf(DateTime(2026, 12, 28)).day, 3);
      expect(weekEndOf(DateTime(2026, 12, 28)).month, 1);
    });
  });

  group('presupuesto semanal', () {
    test('miércoles con 70 de 140 gastados', () {
      final s = weekStatus(now: DateTime(2026, 10, 28), budget: 140, spent: 70);
      expect(s.dayOfWeek, 3);
      expect(s.daysLeft, 5);
      expect(s.remaining, 70);
      expect(s.perDayLeft, 14);
      expect(s.expectedByNow, closeTo(60, 0.001));
      expect(s.overPace, isTrue);
      expect(s.over, isFalse);
    });
    test('pasado del presupuesto', () {
      final s = weekStatus(now: DateTime(2026, 10, 30), budget: 100, spent: 120);
      expect(s.over, isTrue);
      expect(s.overPace, isFalse);
      expect(s.perDayLeft, 0);
      expect(s.progress, 1);
    });
    test('dentro del ritmo', () {
      final s = weekStatus(now: DateTime(2026, 10, 28), budget: 140, spent: 40);
      expect(s.overPace, isFalse);
    });
  });

  group('sobres', () {
    test('50/30/20 con ingresos de 1000', () {
      final st = envelopeStatuses(
        defaultEnvelopes(),
        1000,
        {'comida': 200, 'servicios': 150, 'compras': 400, 'otros': 10},
      );
      expect(st[0].allocated, 500);
      expect(st[0].spent, 350);
      expect(st[0].remaining, 150);
      expect(st[1].allocated, 300);
      expect(st[1].spent, 410);
      expect(st[1].over, isTrue);
      expect(st[2].allocated, 200);
      expect(st[2].isReserve, isTrue);
      expect(st[2].over, isFalse);
    });
    test('categorías sin sobre se suman aparte', () {
      expect(unassignedSpend(defaultEnvelopes(), {'comida': 10, 'mascotas': 25}), 25);
    });
    test('porcentajes y guardado en mapa', () {
      expect(totalPercent(defaultEnvelopes()), 100);
      final e = Envelope.fromMap(Map<dynamic, dynamic>.from(defaultEnvelopes().first.toMap()));
      expect(e.name, 'Necesidades');
      expect(e.categories, ['servicios', 'comida']);
    });
  });

  group('variación', () {
    test('sube, baja y sin base', () {
      expect(deltaLabel(120, 100), '+20%');
      expect(deltaLabel(80, 100), '-20%');
      expect(deltaLabel(50, 0), isNull);
    });
  });
}
