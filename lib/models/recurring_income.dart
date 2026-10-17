import 'recurring_expense.dart';

/// Ingreso que se repite (sueldo semanal, quincenal, mensual...). Se guarda
/// como mapa simple dentro de la caja de ajustes, por espacio de trabajo, y
/// comparte las reglas de fechas de [RecurringExpense].
class RecurringIncome {
  final String id;
  final String label;
  final double amount;
  final String currency;

  /// Una de [RecurringExpense.frequencies].
  final String frequency;
  final int dayOfMonth;
  final bool paused;
  final DateTime nextDue;

  const RecurringIncome({
    required this.id,
    required this.label,
    required this.amount,
    required this.currency,
    required this.frequency,
    required this.dayOfMonth,
    required this.paused,
    required this.nextDue,
  });

  RecurringIncome copyWith({
    String? label,
    double? amount,
    String? currency,
    String? frequency,
    int? dayOfMonth,
    bool? paused,
    DateTime? nextDue,
  }) =>
      RecurringIncome(
        id: id,
        label: label ?? this.label,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        frequency: frequency ?? this.frequency,
        dayOfMonth: dayOfMonth ?? this.dayOfMonth,
        paused: paused ?? this.paused,
        nextDue: nextDue ?? this.nextDue,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'amount': amount,
        'currency': currency,
        'frequency': frequency,
        'dayOfMonth': dayOfMonth,
        'paused': paused,
        'nextDue': nextDue.toIso8601String(),
      };

  factory RecurringIncome.fromMap(Map<dynamic, dynamic> map) {
    final String freq = map['frequency']?.toString() ?? RecurringExpense.monthly;
    return RecurringIncome(
      id: map['id'].toString(),
      label: map['label'].toString(),
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'].toString(),
      frequency: RecurringExpense.frequencies.contains(freq) ? freq : RecurringExpense.monthly,
      dayOfMonth: (map['dayOfMonth'] as num).toInt(),
      paused: map['paused'] == true,
      nextDue: DateTime.parse(map['nextDue'].toString()),
    );
  }
}
