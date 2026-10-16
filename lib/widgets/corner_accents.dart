import 'package:flutter/material.dart';

/// Dibuja 4 "corchetes" decorativos en las esquinas de lo que envuelva —
/// el motivo de interfaz técnica/HUD, disponible para cualquier mod vía
/// `cornerAccent: "brackets"`. Es puro dibujo geométrico (líneas rectas
/// con Canvas), sin lógica de negocio: en el peor caso se ve raro,
/// nunca rompe algo.
class CornerAccents extends StatelessWidget {
  final Widget child;
  final bool enabled;
  final Color color;

  const CornerAccents({
    super.key,
    required this.child,
    required this.enabled,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _CornerBracketsPainter(color: color)),
          ),
        ),
      ],
    );
  }
}

class _CornerBracketsPainter extends CustomPainter {
  final Color color;
  final double length;
  final double thickness;
  final double inset;

  _CornerBracketsPainter({
    required this.color,
    this.length = 13,
    this.thickness = 2,
    this.inset = 7,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < (inset + length) * 2 || size.height < (inset + length) * 2) {
      return;
    }

    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(Offset(inset, inset + length), Offset(inset, inset), paint);
    canvas.drawLine(Offset(inset, inset), Offset(inset + length, inset), paint);

    canvas.drawLine(
      Offset(size.width - inset, inset + length),
      Offset(size.width - inset, inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(size.width - inset - length, inset),
      paint,
    );

    canvas.drawLine(
      Offset(inset, size.height - inset - length),
      Offset(inset, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(inset, size.height - inset),
      Offset(inset + length, size.height - inset),
      paint,
    );

    canvas.drawLine(
      Offset(size.width - inset, size.height - inset - length),
      Offset(size.width - inset, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset),
      Offset(size.width - inset - length, size.height - inset),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerBracketsPainter oldDelegate) {
    return color != oldDelegate.color ||
        length != oldDelegate.length ||
        thickness != oldDelegate.thickness ||
        inset != oldDelegate.inset;
  }
}
