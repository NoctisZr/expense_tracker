import 'package:flutter/material.dart';

/// Envoltorio de tarjeta consistente. Usa el widget `Card` real de
/// Flutter para que el `cardTheme` (radio, forma, estilo, sombra que
/// puede pedir un mod) se aplique automáticamente.
class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

/// Título de sección en mayúsculas con el color atenuado consistente en
/// toda la app.
class SectionLabel extends StatelessWidget {
  final String text;
  final TextOverflow? overflow;
  const SectionLabel(this.text, {super.key, this.overflow});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      overflow: overflow,
      maxLines: overflow == null ? null : 1,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: Theme.of(context).hintColor,
      ),
    );
  }
}
