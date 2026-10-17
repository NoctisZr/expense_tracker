import 'package:hive/hive.dart';
import '../utils/category_registry.dart';

/// Claves internas de categoría. No se traducen aquí: la etiqueta visible
/// se resuelve en tiempo de UI a través de AppStrings, para que un cambio
/// de idioma no requiera migrar los datos ya guardados.
class ExpenseCategory {
  static const String compras = 'compras';
  static const String servicios = 'servicios';
  static const String comida = 'comida';
  static const String otros = 'otros';

  static const List<String> builtIn = [compras, servicios, comida, otros];

  /// Categorías integradas + las que creó el usuario.
  static List<String> get all => [
        ...builtIn,
        ...CategoryRegistry.custom.map((c) => c.name),
      ];
}

/// Representa un gasto individual registrado por el usuario.
class Expense {
  final String id;
  String name;
  double amount;
  String currency;
  String category;
  DateTime date;

  /// Nota opcional del usuario.
  String? note;

  /// Equivalente en moneda local calculado con la tasa del día en que se
  /// registró el gasto (y la moneda local de ese momento). Es una foto
  /// histórica: no cambia cuando cambian las tasas.
  double? localAmount;
  String? localCurrencyAtCreation;

  /// Ruta de la foto de la factura (copiada al almacenamiento de la app).
  String? receiptPath;

  Expense({
    required this.id,
    required this.name,
    required this.amount,
    required this.currency,
    required this.category,
    required this.date,
    this.note,
    this.localAmount,
    this.localCurrencyAtCreation,
    this.receiptPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'currency': currency,
        'category': category,
        'date': date.toIso8601String(),
        if (note != null && note!.isNotEmpty) 'note': note,
        if (localAmount != null) 'localAmount': localAmount,
        if (localCurrencyAtCreation != null) 'localCurrencyAtCreation': localCurrencyAtCreation,
        if (receiptPath != null) 'receiptPath': receiptPath,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        name: json['name'] as String,
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String,
        category: json['category'] as String,
        date: DateTime.parse(json['date'] as String),
        note: json['note'] as String?,
        localAmount: (json['localAmount'] as num?)?.toDouble(),
        localCurrencyAtCreation: json['localCurrencyAtCreation'] as String?,
        receiptPath: json['receiptPath'] as String?,
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
      // Campos añadidos en la v1.2: los gastos antiguos no los tienen (null).
      note: fields[6] as String?,
      localAmount: (fields[7] as num?)?.toDouble(),
      localCurrencyAtCreation: fields[8] as String?,
      // Campo añadido en la v1.3.
      receiptPath: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Expense obj) {
    writer
      ..writeByte(10)
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
      ..write(obj.date)
      ..writeByte(6)
      ..write(obj.note)
      ..writeByte(7)
      ..write(obj.localAmount)
      ..writeByte(8)
      ..write(obj.localCurrencyAtCreation)
      ..writeByte(9)
      ..write(obj.receiptPath);
  }
}
