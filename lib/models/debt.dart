/// Deuda o préstamo: dinero que alguien te debe ([owedToMe] = true) o que
/// tú debes. Se guarda como mapa simple en la caja de ajustes, por espacio
/// de trabajo.
class Debt {
  final String id;
  final String person;
  final double amount;
  final String currency;
  final bool owedToMe;
  final DateTime date;
  final bool paid;
  final String? note;

  const Debt({
    required this.id,
    required this.person,
    required this.amount,
    required this.currency,
    required this.owedToMe,
    required this.date,
    required this.paid,
    this.note,
  });

  Debt copyWith({bool? paid}) => Debt(
        id: id,
        person: person,
        amount: amount,
        currency: currency,
        owedToMe: owedToMe,
        date: date,
        paid: paid ?? this.paid,
        note: note,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'person': person,
        'amount': amount,
        'currency': currency,
        'owedToMe': owedToMe,
        'date': date.toIso8601String(),
        'paid': paid,
        if (note != null && note!.isNotEmpty) 'note': note,
      };

  factory Debt.fromMap(Map<dynamic, dynamic> map) => Debt(
        id: map['id'].toString(),
        person: map['person'].toString(),
        amount: (map['amount'] as num).toDouble(),
        currency: map['currency'].toString(),
        owedToMe: map['owedToMe'] == true,
        date: DateTime.parse(map['date'].toString()),
        paid: map['paid'] == true,
        note: map['note'] as String?,
      );
}
