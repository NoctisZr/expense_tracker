import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// La "máscara" que un mod puede poner encima de toda la app: un patrón
/// liviano dibujado por código o, si el mod trae su propia textura, una
/// imagen embebida en el propio archivo del mod (base64 — sigue siendo
/// solo datos, nunca código ejecutable). Se dibuja con `IgnorePointer`
/// para no bloquear ningún toque.
class ModOverlay extends StatelessWidget {
  final String pattern;
  final double opacity;
  final Color color;
  final String? imageBase64;

  const ModOverlay({
    super.key,
    required this.pattern,
    required this.opacity,
    required this.color,
    this.imageBase64,
  });

  @override
  Widget build(BuildContext context) {
    if (imageBase64 != null && imageBase64!.isNotEmpty) {
      Uint8List? bytes;
      try {
        bytes = base64Decode(imageBase64!);
      } catch (_) {
        bytes = null;
      }
      if (bytes != null) {
        return IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Image.memory(bytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
          ),
        );
      }
    }

    if (pattern == 'none') return const SizedBox.shrink();

    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: CustomPaint(
          size: Size.infinite,
          painter: pattern == 'grid'
              ? _GridPatternPainter(color: color)
              : _ScanlinesPatternPainter(color: color),
        ),
      ),
    );
  }
}

class _ScanlinesPatternPainter extends CustomPainter {
  final Color color;
  const _ScanlinesPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const double gap = 3;
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlinesPatternPainter oldDelegate) => color != oldDelegate.color;
}

class _GridPatternPainter extends CustomPainter {
  final Color color;
  const _GridPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const double gap = 28;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPatternPainter oldDelegate) => color != oldDelegate.color;
}
