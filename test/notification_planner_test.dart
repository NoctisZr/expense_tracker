import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/recurring_expense.dart';
import 'package:expense_tracker/models/recurring_income.dart';
import 'package:expense_tracker/utils/notification_planner.dart';

String _t(String key) => key;

void main() {
  // 2026-10-18 es domingo.
  final DateTime now = DateTime(2026, 10, 18, 12);

  RecurringExpense charge(DateTime due, {bool paused = false}) => RecurringExpense(
        id: 'c',
        name: 'Netflix',
        amount: 15.5,
        currency: 'USD',
        category: 'servicios',
        frequency: RecurringExpense.monthly,
        dayOfMonth: due.day,
        paused: paused,
        nextDue: due,
      );

  RecurringIncome payday(DateTime due) => RecurringIncome(
        id: 'p',
        label: 'Sueldo',
        amount: 500,
        currency: 'USD',
        frequency: RecurringExpense.weekly,
        dayOfMonth: due.day,
        paused: false,
        nextDue: due,
      );

  test('sin activar no hay avisos', () {
    final plans = planNotifications(
      now: now,
      prefs: const NotificationPrefs(enabled: false),
      recurring: [charge(DateTime(2026, 10, 25, 9))],
      incomes: const [],
      lastExport: now,
      t: _t,
    );
    expect(plans, isEmpty);
  });

  test('cobro recurrente: aviso el día anterior a las 9:00', () {
    final plans = planNotifications(
      now: now,
      prefs: const NotificationPrefs(enabled: true, payday: false, backup: false),
      recurring: [charge(DateTime(2026, 10, 25, 9))],
      incomes: const [],
      lastExport: now,
      t: _t,
    );
    expect(plans.length, 1);
    expect(plans.first.when, DateTime(2026, 10, 24, 9));
    expect(plans.first.title, contains('notif_cobro_manana'));
    expect(plans.first.title, contains('Netflix'));
    expect(plans.first.body, '15.50 USD');
  });

  test('los cobros pausados no avisan', () {
    final plans = planNotifications(
      now: now,
      prefs: const NotificationPrefs(enabled: true, payday: false, backup: false),
      recurring: [charge(DateTime(2026, 10, 25, 9), paused: true)],
      incomes: const [],
      lastExport: now,
      t: _t,
    );
    expect(plans, isEmpty);
  });

  test('día de pago semanal: 5 avisos en 35 días, ordenados', () {
    final plans = planNotifications(
      now: now,
      prefs: const NotificationPrefs(enabled: true, charges: false, backup: false),
      recurring: const [],
      incomes: [payday(DateTime(2026, 10, 20, 9))],
      lastExport: now,
      t: _t,
    );
    expect(plans.length, 5);
    expect(plans.first.when, DateTime(2026, 10, 20, 9));
    for (int i = 1; i < plans.length; i++) {
      expect(plans[i].when.isAfter(plans[i - 1].when), isTrue);
    }
  });

  test('recordatorio diario: 14 días a la hora elegida', () {
    final plans = planNotifications(
      now: now,
      prefs: const NotificationPrefs(enabled: true, charges: false, payday: false, backup: false, daily: true, dailyHour: 21),
      recurring: const [],
      incomes: const [],
      lastExport: now,
      t: _t,
    );
    expect(plans.length, 14);
    expect(plans.first.when, DateTime(2026, 10, 18, 21));
  });

  test('recordatorio de respaldo: un domingo a las 10:00 si hace tiempo que no exportas', () {
    final plans = planNotifications(
      now: now,
      prefs: const NotificationPrefs(enabled: true, charges: false, payday: false),
      recurring: const [],
      incomes: const [],
      lastExport: null,
      t: _t,
    );
    expect(plans.length, 1);
    // El domingo de hoy ya pasó las 10:00: se agenda el siguiente.
    expect(plans.first.when, DateTime(2026, 10, 25, 10));
    expect(plans.first.when.weekday, DateTime.sunday);

    final recent = planNotifications(
      now: now,
      prefs: const NotificationPrefs(enabled: true, charges: false, payday: false),
      recurring: const [],
      incomes: const [],
      lastExport: now.subtract(const Duration(days: 3)),
      t: _t,
    );
    expect(recent, isEmpty);
  });
}
