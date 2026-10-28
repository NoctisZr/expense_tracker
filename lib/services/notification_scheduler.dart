import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/notification_planner.dart';
import 'notification_service.dart';

/// Vuelve a agendar todos los avisos según los datos actuales. Cancela los
/// anteriores y agenda los de los próximos días. Nunca lanza errores: un
/// fallo en los avisos no debe afectar al resto de la app.
Future<void> rescheduleNotifications({
  required FinanceProvider finance,
  required LocaleProvider locale,
}) async {
  if (!NotificationService.isAvailable) return;
  try {
    final NotificationService service = NotificationService();
    final NotificationPrefs prefs = NotificationPrefs.load(finance.settingsBox);
    await service.cancelAll();
    if (!prefs.enabled) return;

    final DateTime? lastExport =
        DateTime.tryParse((finance.settingsBox.get(FinanceProvider.lastExportKey) as String?) ?? '');
    final List<PlannedNotification> plans = planNotifications(
      now: DateTime.now(),
      prefs: prefs,
      recurring: finance.recurringExpenses,
      incomes: finance.recurringIncomes,
      credits: finance.credits,
      lastExport: lastExport,
      t: locale.t,
    );
    for (final p in plans) {
      await service.schedule(id: p.id, title: p.title, body: p.body, when: p.when);
    }
  } catch (_) {
    // Sin avisos, pero la app sigue funcionando.
  }
}
