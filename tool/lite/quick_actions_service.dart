/// Versión "lite" (sin quick_actions) de QuickActionsService: misma API, sin
/// atajos. Solo se usa si el build completo falla.
class QuickActionsService {
  static const bool isAvailable = false;

  void setup({required Map<String, String> titles, required void Function(String type) onAction}) {}
}
