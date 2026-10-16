/// Gasto que se repite (suscripciones, alquiler, internet...). No necesita
/// adaptador de Hive: se guarda como lista de mapas simples dentro de la
/// caja de ajustes, separada por espacio de trabajo.
///
/// Desde la v1.2 admite frecuencia semanal, mensual o anual, se puede
/// pausar y guarda la fecha del próximo cobro (`nextDue`). Los registros
/// de la v1.1 (que solo tenían `lastGeneratedMonth`) se convierten solos
/// al leerlos.
class RecurringExpense {
  static const String weekly = 'weekly';
  static const String monthly = 'monthly';
  static const String yearly = 'yearly';
  static const List<String> frequencies = [weekly, monthly, yearly];

  final String id;
  final String name;
  final double amount;
  final String currency;
  final String category;

  /// 'weekly' | 'monthly' | 'yearly'.
  final String frequency;

  /// Día del mes ancla (1-31) para mensual y anual. En meses más cortos se
  /// usa el último día del mes.
  final int dayOfMonth;

  final bool paused;

  /// Fecha del próximo cobro pendiente de registrar.
  final DateTime nextDue;

  const RecurringExpense({
    required this.id,
    required this.name,
    required this.amount,
    required this.currency,
    required this.category,
    required this.frequency,
    required this.dayOfMonth,
    required this.paused,
    required this.nextDue,
  });

  RecurringExpense copyWith({
    String? name,
    double? amount,
    String? currency,
    String? category,
    String? frequency,
    int? dayOfMonth,
    bool? paused,
    DateTime? nextDue,
  }) =>
      RecurringExpense(
        id: id,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        category: category ?? this.category,
        frequency: frequency ?? this.frequency,
        dayOfMonth: dayOfMonth ?? this.dayOfMonth,
        paused: paused ?? this.paused,
        nextDue: nextDue ?? this.nextDue,
      );

  /// Fecha del cobro siguiente a [due] según la frecuencia. Función pura
  /// (sin Hive ni Flutter) para poder probarla fácilmente.
  static DateTime advance(DateTime due, String frequency, int dayOfMonth) {
    switch (frequency) {
      case weekly:
        return DateTime(due.year, due.month, due.day + 7, due.hour, due.minute);
      case yearly:
        return _clamped(due.year + 1, due.month, dayOfMonth, due);
      case monthly:
      default:
        final int month = due.month + 1;
        final int year = month > 12 ? due.year + 1 : due.year;
        return _clamped(year, month > 12 ? 1 : month, dayOfMonth, due);
    }
  }

  static DateTime _clamped(int year, int month, int day, DateTime like) {
    final int daysInMonth = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > daysInMonth ? daysInMonth : day, like.hour, like.minute);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'amount': amount,
        'currency': currency,
        'category': category,
        'frequency': frequency,
        'dayOfMonth': dayOfMonth,
        'paused': paused,
        'nextDue': nextDue.toIso8601String(),
      };

  factory RecurringExpense.fromMap(Map<dynamic, dynamic> map) {
    final int day = (map['dayOfMonth'] as num).toInt();

    DateTime? due;
    final dynamic rawDue = map['nextDue'];
    if (rawDue is String) due = DateTime.tryParse(rawDue);

    // Formato de la v1.1: solo traía el último mes generado (año*12 + mes-1).
    if (due == null) {
      final int last = (map['lastGeneratedMonth'] as num?)?.toInt() ?? 0;
      final int next = last + 1;
      final int year = next ~/ 12;
      final int month = next % 12 + 1;
      due = _clamped(year, month, day, DateTime(year, month, 1, 9));
    }

    final String freq = map['frequency']?.toString() ?? monthly;

    return RecurringExpense(
      id: map['id'].toString(),
      name: map['name'].toString(),
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'].toString(),
      category: map['category'].toString(),
      frequency: frequencies.contains(freq) ? freq : monthly,
      dayOfMonth: day,
      paused: map['paused'] == true,
      nextDue: due,
    );
  }
}
