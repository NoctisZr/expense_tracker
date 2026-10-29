/// Lógica PURA del presupuesto semanal (semana de lunes a domingo).

/// Lunes de la semana de [d], a las 00:00.
DateTime weekStartOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Último instante (domingo 23:59:59) de la semana que empieza en [start].
DateTime weekEndOf(DateTime start) =>
    DateTime(start.year, start.month, start.day + 7).subtract(const Duration(seconds: 1));

class WeekStatus {
  final double budget;
  final double spent;

  /// Día de la semana en curso (lunes = 1 ... domingo = 7).
  final int dayOfWeek;

  const WeekStatus({required this.budget, required this.spent, required this.dayOfWeek});

  double get remaining => budget - spent;

  /// Días que quedan contando hoy.
  int get daysLeft => 8 - dayOfWeek;

  /// Lo que puedes gastar por día para terminar la semana dentro del presupuesto.
  double get perDayLeft => daysLeft <= 0 || remaining <= 0 ? 0 : remaining / daysLeft;

  /// Gasto que correspondería llevar hasta hoy si repartes el presupuesto parejo.
  double get expectedByNow => budget * dayOfWeek / 7;

  bool get over => spent > budget + 0.004;

  /// Vas gastando más rápido de lo previsto (sin haberte pasado aún).
  bool get overPace => !over && spent > expectedByNow + 0.004;

  double get progress => budget <= 0 ? 0 : (spent / budget).clamp(0.0, 1.0).toDouble();
}

WeekStatus weekStatus({required DateTime now, required double budget, required double spent}) =>
    WeekStatus(budget: budget, spent: spent, dayOfWeek: now.weekday);
