import 'package:flutter/foundation.dart';

/// Pequeño canal para que los atajos de pantalla (mantener pulsado el icono)
/// puedan pedirle al tablero que cambie de vista: 0 Resumen, 1 Movimientos,
/// 2 Planificación. El tablero lo consume y lo vuelve a poner en `null`.
class AppNavigation {
  static final ValueNotifier<int?> dashboardView = ValueNotifier<int?>(null);
}
