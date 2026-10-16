import 'package:hive/hive.dart';

/// Claves internas de categoría. No se traducen aquí: la etiqueta visible
/// se resuelve en tiempo de UI a través de AppStrings, para que un cambio
/// de idioma no requiera migrar los datos ya guardados.
class ExpenseCategory {
  static const String compras = 'compras';
  static const String servicios = 'servicios';
  static const String comida = 'comida';
  static const String otros = 'otros';

  static const List<String> all = [compras, servicios, comida, otros];
}

/// Representa un gasto individual registrado por el usuario.
class Expense {
  final String id;
  String name;
  double amount;
  String currency;
  String category;
  DateTime date;

  Expense({
    required this.id,
    required this.name,
    required this.amount,
    required this.currency,
    required this.category,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'currency': currency,
        'category': category,
        'date': date.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        name: json['name'] as String,
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String,
        category: json['category'] as String,
        date: DateTime.parse(json['date'] as String),
      );
}

/// Adaptador manual de Hive para Expense (typeId = 0).
///
/// Se escribe a mano en lugar de generarlo con build_runner para que el
/// proyecto compile de inmediato sin pasos de generación de código.
class ExpenseAdapter extends TypeAdapter<Expense> {
  @override
  final int typeId = 0;

  @override
  Expense read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Expense(
      id: fields[0] as String,
      name: fields[1] as String,
      amount: (fields[2] as num).toDouble(),
      currency: fields[3] as String,
      category: fields[4] as String,
      date: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Expense obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.currency)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.date);
  }
}
