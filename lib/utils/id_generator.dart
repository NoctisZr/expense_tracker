/// Genera un identificador único simple para gastos, ingresos y bóvedas.
String generateId() {
  final int micros = DateTime.now().microsecondsSinceEpoch;
  final int salt = identityHashCode(Object()) % 100000;
  return '${micros}_$salt';
}
