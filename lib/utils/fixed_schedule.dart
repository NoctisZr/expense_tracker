/// Fechas de vencimiento de un gasto fijo mensual (p. ej. la renta).
///
/// El primer vencimiento es el primer día [day] que cae DESPUÉS de [start]
/// (si lo agregas el día 15 con día 1, empieza el mes siguiente). Se devuelven
/// solo los que ya pasaron ([now]), a las 9:00, como máximo [maxMonths].
/// El día se limita a 1–28 para que exista en todos los meses.
List<DateTime> fixedDueDates({
  required DateTime start,
  required int day,
  required DateTime now,
  int maxMonths = 24,
}) {
  final int d = day.clamp(1, 28).toInt();
  final List<DateTime> out = [];
  int year = start.year;
  int month = start.month;
  for (int i = 0; i < 600; i++) {
    final DateTime due = DateTime(year, month, d, 9);
    if (due.isAfter(now)) break;
    if (due.isAfter(start)) out.add(due);
    month++;
    if (month > 12) {
      month = 1;
      year++;
    }
  }
  return out.length <= maxMonths ? out : out.sublist(out.length - maxMonths);
}
