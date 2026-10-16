// Archivo 2: mod_shapes.dart
import 'package:flutter/material.dart';

/// Traduce la clave de forma de un mod a un ShapeBorder real de Flutter.
///
/// "beveled" usa BeveledRectangleBorder (esquinas cortadas a 45°, como
/// el filo de una hoja) en vez de curvas. "stadium" es un óvalo
/// completo (bordes 100% redondeados, estilo píldora). "continuous" es
/// una curva más suave tipo "squircle". Todas son clases nativas de
/// Flutter: no hay pintura personalizada de por medio para esta parte,
/// solo geometría segura.
ShapeBorder shapeBorderFor(String? key, double radius, {BorderSide side = BorderSide.none}) {
  switch (key) {
    case 'beveled':
      return BeveledRectangleBorder(borderRadius: BorderRadius.circular(radius), side: side);
    case 'stadium':
      return StadiumBorder(side: side);
    case 'continuous':
      return ContinuousRectangleBorder(borderRadius: BorderRadius.circular(radius), side: side);
    case 'rounded':
    default:
      return RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: side);
  }
}

/// Igual que [shapeBorderFor] pero devuelve un BorderRadius simple para
/// los lugares que usan `Container` + `BoxDecoration`. "beveled" y
/// "stadium" no tienen un radio equivalente exacto ahí, así que caen a
/// un radio pequeño (beveled) o muy grande (stadium) razonable.
BorderRadius borderRadiusApproxFor(String? key, double radius) {
  switch (key) {
    case 'beveled':
      return BorderRadius.circular(2);
    case 'stadium':
      return BorderRadius.circular(999);
    case 'continuous':
    case 'rounded':
    default:
      return BorderRadius.circular(radius);
  }
}
