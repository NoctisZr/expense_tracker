import 'package:quick_actions/quick_actions.dart';

/// Atajos al mantener pulsado el icono de la app (por ejemplo "Añadir gasto").
/// Es el ÚNICO archivo que importa quick_actions; si el plugin diera
/// problemas, el workflow lo reemplaza por `tool/lite/quick_actions_service.dart`.
class QuickActionsService {
  static const bool isAvailable = true;

  /// [titles]: tipo de atajo -> texto visible. [onAction] recibe el tipo.
  void setup({required Map<String, String> titles, required void Function(String type) onAction}) {
    const QuickActions quickActions = QuickActions();
    quickActions.initialize(onAction);
    quickActions.setShortcutItems(<ShortcutItem>[
      for (final entry in titles.entries) ShortcutItem(type: entry.key, localizedTitle: entry.value),
    ]);
  }
}
