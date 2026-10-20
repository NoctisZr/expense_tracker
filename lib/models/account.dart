/// Cuenta o billetera (efectivo, tarjeta, banco, ahorros) con su propia
/// divisa y saldo inicial. El saldo actual se calcula con los gastos e
/// ingresos asignados a ella y sus transferencias. Se guarda como mapa
/// simple en la caja de ajustes, por espacio de trabajo.
class Account {
  static const String cash = 'cash';
  static const String card = 'card';
  static const String bank = 'bank';
  static const String savings = 'savings';
  static const List<String> types = [cash, card, bank, savings];

  final String id;
  final String name;
  final String type;
  final String currency;
  final double initialBalance;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.initialBalance,
  });

  Account copyWith({String? name, String? type, double? initialBalance}) => Account(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        currency: currency,
        initialBalance: initialBalance ?? this.initialBalance,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'currency': currency,
        'initialBalance': initialBalance,
      };

  factory Account.fromMap(Map<dynamic, dynamic> map) {
    final String type = map['type']?.toString() ?? cash;
    return Account(
      id: map['id'].toString(),
      name: map['name'].toString(),
      type: types.contains(type) ? type : cash,
      currency: map['currency'].toString(),
      initialBalance: (map['initialBalance'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Movimiento de dinero entre dos cuentas. Guarda lo que sale de una (en la
/// divisa de esa cuenta) y lo que entra en la otra (en la suya).
class Transfer {
  final String id;
  final String fromId;
  final String toId;
  final double fromAmount;
  final double toAmount;
  final DateTime date;

  const Transfer({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.fromAmount,
    required this.toAmount,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'fromId': fromId,
        'toId': toId,
        'fromAmount': fromAmount,
        'toAmount': toAmount,
        'date': date.toIso8601String(),
      };

  factory Transfer.fromMap(Map<dynamic, dynamic> map) => Transfer(
        id: map['id'].toString(),
        fromId: map['fromId'].toString(),
        toId: map['toId'].toString(),
        fromAmount: (map['fromAmount'] as num).toDouble(),
        toAmount: (map['toAmount'] as num).toDouble(),
        date: DateTime.parse(map['date'].toString()),
      );
}
