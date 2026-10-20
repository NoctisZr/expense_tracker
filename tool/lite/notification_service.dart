/// Versión "lite" (sin flutter_local_notifications) de NotificationService:
/// misma API, pero sin avisos. Solo se usa si el build completo falla.
class NotificationService {
  static const bool isAvailable = false;

  Future<void> init() async {}

  Future<bool> requestPermission() async => false;

  Future<void> cancelAll() async {}

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {}

  Future<void> showNow({required int id, required String title, required String body}) async {}
}
