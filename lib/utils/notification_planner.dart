import '../models/recurring_expense.dart';
import '../models/recurring_income.dart';
import 'formatters.dart';

/// Preferencias de avisos del usuario (se guardan en la caja de ajustes).
class NotificationPrefs {
  static const String _enabledKey = 'notifEnabled';
  static const String _chargesKey = 'notifCharges';
  static const String _paydayKey = 'notifPayday';
  static const String _dailyKey = 'notifDaily';
  static const String _dailyHourKey = 'notifDailyHour';
  static const String _backupKey = 'notifBackup';

  final bool enabled;
  final bool charges;
  final bool payday;
  final bool daily;
  final int dailyHour;
  final bool backup;

  const NotificationPrefs({
    this.enabled = false,
    this.charges = true,
    this.payday = true,
    this.daily = false,
    this.dailyHour = 21,
    this.backup = true,
  });

  NotificationPrefs copyWith({
    bool? enabled,
    bool? charges,
    bool? payday,
    bool? daily,
    int? dailyHour,
    bool? backup,
  }) =>
      NotificationPrefs(
        enabled: enabled ?? this.enabled,
        charges: charges ?? this.charges,
        payday: payday ?? this.payday,
        daily: daily ?? this.daily,
        dailyHour: dailyHour ?? this.dailyHour,
        backup: backup ?? this.backup,
      );

  /// Lee las preferencias de una caja (cualquier objeto con `get`).
  factory NotificationPrefs.load(dynamic box) {
    bool flag(String key, bool fallback) => (box.get(key, defaultValue: fallback) as bool?) ?? fallback;
    final dynamic hour = box.get(_dailyHourKey, defaultValue: 21);
    return NotificationPrefs(
      enabled: flag(_enabledKey, false),
      charges: flag(_chargesKey, true),
      payday: flag(_paydayKey, true),
      daily: flag(_dailyKey, false),
      dailyHour: hour is int && hour >= 0 && hour <= 23 ? hour : 21,
      backup: flag(_backupKey, true),
    );
  }

  Future<void> save(dynamic box) async {
    await box.put(_enabledKey, enabled);
    await box.put(_chargesKey, charges);
    await box.put(_paydayKey, payday);
    await box.put(_dailyKey, daily);
    await box.put(_dailyHourKey, dailyHour);
    await box.put(_backupKey, backup);
  }
}

class PlannedNotification {
  final int id;
  final DateTime when;
  final String title;
  final String body;

  const PlannedNotification({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
  });
}

/// Calcula qué avisos agendar (función pura, fácil de probar). Mira los
/// próximos [horizonDays] días a partir de [now].
///  - Cobros recurrentes: el día anterior a las 9:00.
///  - Día de pago (ingresos recurrentes): ese día a las 9:00.
///  - Recordatorio diario de registrar gastos: a la hora elegida (14 días).
///  - Respaldo: los domingos a las 10:00 si hace más de 14 días que no exportas.
/// [t] traduce una clave; [lastExport] es la última exportación (o null).
List<PlannedNotification> planNotifications({
  required DateTime now,
  required NotificationPrefs prefs,
  required List<RecurringExpense> recurring,
  required List<RecurringIncome> incomes,
  required DateTime? lastExport,
  required String Function(String key) t,
  int horizonDays = 35,
}) {
  if (!prefs.enabled) return const [];
  final DateTime limit = now.add(Duration(days: horizonDays));
  final List<PlannedNotification> result = [];
  int nextId = 1;

  void add(DateTime when, String title, String body) {
    if (!when.isAfter(now) || when.isAfter(limit)) return;
    result.add(PlannedNotification(id: nextId++, when: when, title: title, body: body));
  }

  if (prefs.charges) {
    for (final r in recurring) {
      if (r.paused) continue;
      DateTime due = r.nextDue;
      int guard = 0;
      while (!due.isAfter(limit) && guard < 60) {
        final DateTime day = DateTime(due.year, due.month, due.day);
        add(
          DateTime(day.year, day.month, day.day - 1, 9),
          '${t('notif_cobro_manana')}: ${r.name}',
          '${formatAmount(r.amount)} ${r.currency}',
        );
        due = RecurringExpense.advance(due, r.frequency, r.dayOfMonth);
        guard++;
      }
    }
  }

  if (prefs.payday) {
    for (final r in incomes) {
      if (r.paused) continue;
      DateTime due = r.nextDue;
      int guard = 0;
      while (!due.isAfter(limit) && guard < 60) {
        add(
          DateTime(due.year, due.month, due.day, 9),
          t('notif_dia_de_pago'),
          '${r.label}: ${formatAmount(r.amount)} ${r.currency}',
        );
        due = RecurringExpense.advance(due, r.frequency, r.dayOfMonth);
        guard++;
      }
    }
  }

  if (prefs.daily) {
    for (int i = 0; i < 14; i++) {
      add(
        DateTime(now.year, now.month, now.day + i, prefs.dailyHour),
        t('notif_diario_titulo'),
        t('notif_diario_texto'),
      );
    }
  }

  if (prefs.backup) {
    final bool dueForBackup = lastExport == null || now.difference(lastExport).inDays >= 14;
    if (dueForBackup) {
      for (int i = 0; i < 28; i++) {
        final DateTime day = DateTime(now.year, now.month, now.day + i);
        if (day.weekday == DateTime.sunday) {
          final DateTime when = DateTime(day.year, day.month, day.day, 10);
          if (!when.isAfter(now)) continue; // este domingo ya pasó la hora
          add(when, t('notif_respaldo_titulo'), t('notif_respaldo_texto'));
          break; // un solo recordatorio: no hace falta insistir cada semana
        }
      }
    }
  }

  result.sort((a, b) => a.when.compareTo(b.when));
  return result;
}
