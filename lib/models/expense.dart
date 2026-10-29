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

  /// Cuenta de la que salió el dinero (opcional, v1.4).
  String? accountId;

  /// Etiquetas libres en minúscula (opcional, v1.4).
  List<String>? tags;

  /// Compra a crédito de la que salió este gasto y número de cuota (v1.6).
  String? creditId;
  int? installmentNumber;

  /// Gasto en pareja (v1.8): total de la cuenta. [amount] es SOLO tu parte.
  /// Null = gasto personal.
  double? sharedTotal;

  /// Quién pagó la cuenta completa: tú (true) o tu pareja (false).
  bool paidByCreator;

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
    this.accountId,
    this.tags,
    this.creditId,
    this.installmentNumber,
    this.sharedTotal,
    this.paidByCreator = true,
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
        if (accountId != null) 'accountId': accountId,
        if (tags != null && tags!.isNotEmpty) 'tags': tags,
        if (creditId != null) 'creditId': creditId,
        if (installmentNumber != null) 'installmentNumber': installmentNumber,
        if (sharedTotal != null) 'sharedTotal': sharedTotal,
        if (sharedTotal != null) 'paidByCreator': paidByCreator,
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
        accountId: json['accountId'] as String?,
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList(),
        creditId: json['creditId'] as String?,
        installmentNumber: (json['installmentNumber'] as num?)?.toInt(),
        sharedTotal: (json['sharedTotal'] as num?)?.toDouble(),
        paidByCreator: json['paidByCreator'] as bool? ?? true,
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
      // Campos añadidos en la v1.4.
      accountId: fields[10] as String?,
      tags: (fields[11] as List?)?.map((e) => e.toString()).toList(),
      // Campos añadidos en la v1.6 (créditos y cuotas).
      creditId: fields[12] as String?,
      installmentNumber: (fields[13] as num?)?.toInt(),
      // Campos añadidos en la v1.8 (gastos en pareja).
      sharedTotal: (fields[14] as num?)?.toDouble(),
      paidByCreator: fields[15] as bool? ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, Expense obj) {
    writer
      ..writeByte(16)
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
      ..write(obj.receiptPath)
      ..writeByte(10)
      ..write(obj.accountId)
      ..writeByte(11)
      ..write(obj.tags)
      ..writeByte(12)
      ..write(obj.creditId)
      ..writeByte(13)
      ..write(obj.installmentNumber)
      ..writeByte(14)
      ..write(obj.sharedTotal)
      ..writeByte(15)
      ..write(obj.paidByCreator);
  }
}
