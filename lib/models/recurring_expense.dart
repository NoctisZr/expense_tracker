/// Gasto que se repite cada mes (suscripciones, alquiler, internet...).
/// No necesita adaptador de Hive: se guarda como lista de mapas simples
/// dentro de la caja de ajustes, separada por espacio de trabajo.
class RecurringExpense {
  final String id;
  final String name;
  final double amount;
  final String currency;
  final String category;

  /// Día del mes en que se cobra (1-31). En meses más cortos se usa el
  /// último día del mes.
  final int dayOfMonth;

  /// Último mes para el que ya se generó el gasto, como índice
  /// `año * 12 + (mes - 1)`.
  final int lastGeneratedMonth;

  const RecurringExpense({
    required this.id,
    required this.name,
    required this.amount,
    required this.currency,
    required this.category,
    required this.dayOfMonth,
    required this.lastGeneratedMonth,
  });

  static int monthIndex(DateTime date) => date.year * 12 + (date.month - 1);

  RecurringExpense copyWith({int? lastGeneratedMonth}) => RecurringExpense(
        id: id,
        name: name,
        amount: amount,
        currency: currency,
        category: category,
        dayOfMonth: dayOfMonth,
        lastGeneratedMonth: lastGeneratedMonth ?? this.lastGeneratedMonth,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'amount': amount,
        'currency': currency,
        'category': category,
        'dayOfMonth': dayOfMonth,
        'lastGeneratedMonth': lastGeneratedMonth,
      };

  factory RecurringExpense.fromMap(Map<dynamic, dynamic> map) => RecurringExpense(
        id: map['id'].toString(),
        name: map['name'].toString(),
        amount: (map['amount'] as num).toDouble(),
        currency: map['currency'].toString(),
        category: map['category'].toString(),
        dayOfMonth: (map['dayOfMonth'] as num).toInt(),
        lastGeneratedMonth: (map['lastGeneratedMonth'] as num).toInt(),
      );
}
