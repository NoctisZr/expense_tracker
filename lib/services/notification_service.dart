import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Notificaciones locales programadas (sin servidor: las agenda el propio
/// teléfono). Este es el ÚNICO archivo que importa flutter_local_notifications;
/// si el plugin diera problemas, el workflow lo reemplaza por
/// `tool/lite/notification_service.dart` (misma API, sin avisos).
class NotificationService {
  static const bool isAvailable = true;

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const AndroidNotificationDetails _androidDetails = AndroidNotificationDetails(
    'expense_tracker_reminders',
    'Recordatorios',
    channelDescription: 'Cobros por vencer, día de pago y recordatorios',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// Pide el permiso de notificaciones (Android 13+). `true` si se concedió
  /// o si no hace falta pedirlo.
  Future<bool> requestPermission() async {
    await init();
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final bool? granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  /// Agenda una notificación para el instante [when] (hora local del teléfono).
  /// Se usa el huso UTC solo como contenedor del instante absoluto, así no
  /// hace falta ningún plugin para conocer la zona horaria.
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    await init();
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.UTC),
      const NotificationDetails(android: _androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> showNow({required int id, required String title, required String body}) async {
    await init();
    await _plugin.show(id, title, body, const NotificationDetails(android: _androidDetails));
  }
}
