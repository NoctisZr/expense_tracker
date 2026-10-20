import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/locale_provider.dart';
import '../services/notification_scheduler.dart';
import '../services/notification_service.dart';
import '../utils/notification_planner.dart';
import 'section_card.dart';

/// Ajustes de avisos: cobros por vencer, día de pago, recordatorio diario y
/// de respaldo. Todo se agenda en el teléfono (no necesita internet).
class NotificationsCard extends StatefulWidget {
  const NotificationsCard({super.key});

  @override
  State<NotificationsCard> createState() => _NotificationsCardState();
}

class _NotificationsCardState extends State<NotificationsCard> {
  late NotificationPrefs _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = NotificationPrefs.load(context.read<FinanceProvider>().settingsBox);
  }

  Future<void> _update(NotificationPrefs next) async {
    final finance = context.read<FinanceProvider>();
    final locale = context.read<LocaleProvider>();
    setState(() => _prefs = next);
    await next.save(finance.settingsBox);
    await rescheduleNotifications(finance: finance, locale: locale);
  }

  Future<void> _toggleMaster(bool value) async {
    final locale = context.read<LocaleProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (value) {
      bool granted = false;
      try {
        granted = await NotificationService().requestPermission();
      } catch (_) {
        granted = false;
      }
      if (!granted) {
        messenger.showSnackBar(SnackBar(content: Text(locale.t('notif_permiso_denegado'))));
        return;
      }
    }
    await _update(_prefs.copyWith(enabled: value));
  }

  Future<void> _pickHour() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _prefs.dailyHour, minute: 0),
    );
    if (picked != null) await _update(_prefs.copyWith(dailyHour: picked.hour));
  }

  Future<void> _sendTest() async {
    final locale = context.read<LocaleProvider>();
    try {
      await NotificationService().showNow(
        id: 9999,
        title: locale.t('notif_prueba_titulo'),
        body: locale.t('notif_prueba_texto'),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final theme = Theme.of(context);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(locale.t('notificaciones')),
          const SizedBox(height: 4),
          if (!NotificationService.isAvailable)
            Text(locale.t('notificaciones_no_disponibles'), style: theme.textTheme.bodySmall)
          else ...[
            Text(locale.t('notificaciones_ayuda'), style: theme.textTheme.bodySmall),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(locale.t('notificaciones_activar')),
              value: _prefs.enabled,
              onChanged: _toggleMaster,
            ),
            if (_prefs.enabled) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(locale.t('notif_cobros')),
                value: _prefs.charges,
                onChanged: (v) => _update(_prefs.copyWith(charges: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(locale.t('notif_dia_pago')),
                value: _prefs.payday,
                onChanged: (v) => _update(_prefs.copyWith(payday: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(locale.t('notif_recordatorio_diario')),
                subtitle: _prefs.daily ? Text('${_prefs.dailyHour.toString().padLeft(2, '0')}:00') : null,
                value: _prefs.daily,
                onChanged: (v) => _update(_prefs.copyWith(daily: v)),
              ),
              if (_prefs.daily)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _pickHour,
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(locale.t('notif_cambiar_hora')),
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(locale.t('notif_respaldo')),
                value: _prefs.backup,
                onChanged: (v) => _update(_prefs.copyWith(backup: v)),
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: _sendTest,
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: Text(locale.t('notif_probar')),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
