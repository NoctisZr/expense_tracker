import 'package:hive/hive.dart';

/// Un ingreso registrado por el usuario: el día que recibió un pago
/// (sueldo, freelance, bono, etc.), cuánto y en qué divisa.
class Income {
  final String id;
  String label;
  double amount;
  String currency;
  DateTime date;

  /// Cuenta en la que entró el dinero (opcional, v1.4).
  String? accountId;

  Income({
    required this.id,
    required this.label,
    required this.amount,
    required this.currency,
    required this.date,
    this.accountId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'amount': amount,
        'currency': currency,
        'date': date.toIso8601String(),
        if (accountId != null) 'accountId': accountId,
      };

  factory Income.fromJson(Map<String, dynamic> json) => Income(
        id: json['id'] as String,
        label: json['label'] as String,
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String,
        date: DateTime.parse(json['date'] as String),
        accountId: json['accountId'] as String?,
      );
}

/// Adaptador manual de Hive para Income (typeId = 3).
class IncomeAdapter extends TypeAdapter<Income> {
  @override
  final int typeId = 3;

  @override
  Income read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Income(
      id: fields[0] as String,
      label: fields[1] as String,
      amount: (fields[2] as num).toDouble(),
      currency: fields[3] as String,
      date: fields[4] as DateTime,
      // Campo añadido en la v1.4: los ingresos antiguos no lo tienen (null).
      accountId: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Income obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.label)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.currency)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.accountId);
  }
}
