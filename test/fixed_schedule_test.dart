import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/utils/fixed_schedule.dart';

void main() {
  test('agregado el 15 con día 1: empieza el mes siguiente', () {
    final dues = fixedDueDates(start: DateTime(2026, 10, 15), day: 1, now: DateTime(2026, 12, 20));
    expect(dues, [DateTime(2026, 11, 1, 9), DateTime(2026, 12, 1, 9)]);
  });

  test('agregado el 15 con día 20: este mismo mes cuenta', () {
    final dues = fixedDueDates(start: DateTime(2026, 10, 15), day: 20, now: DateTime(2026, 11, 21));
    expect(dues, [DateTime(2026, 10, 20, 9), DateTime(2026, 11, 20, 9)]);
  });

  test('todavía no vence nada', () {
    expect(fixedDueDates(start: DateTime(2026, 10, 15), day: 1, now: DateTime(2026, 10, 30)), isEmpty);
  });

  test('cruza de año y limita el día a 28', () {
    final dues = fixedDueDates(start: DateTime(2026, 12, 1), day: 31, now: DateTime(2027, 2, 28, 12));
    expect(dues.map((d) => d.day).toSet(), {28});
    expect(dues.first, DateTime(2026, 12, 28, 9));
    expect(dues.last, DateTime(2027, 2, 28, 9));
  });

  test('límite de meses atrasados', () {
    final dues = fixedDueDates(start: DateTime(2020, 1, 1), day: 5, now: DateTime(2026, 11, 1), maxMonths: 6);
    expect(dues.length, 6);
    expect(dues.first, DateTime(2026, 5, 5, 9));
    expect(dues.last, DateTime(2026, 10, 5, 9));
  });
}
