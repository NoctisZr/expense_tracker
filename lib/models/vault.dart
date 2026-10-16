import 'package:hive/hive.dart';

/// Representa una bóveda (meta de ahorro). El monto objetivo y el monto
/// actual SIEMPRE se guardan y se muestran en la misma divisa (`currency`),
/// fijada al momento de crear la bóveda. Nunca se reinterpreta con la
/// "Moneda Local" global.
///
/// Extiende HiveObject para poder llamar a `.save()` tras modificar
/// `currentAmount` in-place (sumar/restar fondos) sin tener que volver a
/// buscar su clave en la caja manualmente.
class Vault extends HiveObject {
  final String id;
  String name;
  double targetAmount;
  double currentAmount;
  final String currency;

  /// Fecha límite opcional para alcanzar la meta (v1.2).
  DateTime? targetDate;

  Vault({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.currency,
    this.targetDate,
  });

  double get progress => targetAmount <= 0
      ? 0
      : (currentAmount / targetAmount).clamp(0, 1).toDouble();

  double get progressPercent => progress * 100;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'currency': currency,
        if (targetDate != null) 'targetDate': targetDate!.toIso8601String(),
      };

  factory Vault.fromJson(Map<String, dynamic> json) => Vault(
        id: json['id'] as String,
        name: json['name'] as String,
        targetAmount: (json['targetAmount'] as num).toDouble(),
        currentAmount: (json['currentAmount'] as num).toDouble(),
        currency: json['currency'] as String,
        targetDate: json['targetDate'] == null
            ? null
            : DateTime.tryParse(json['targetDate'] as String),
      );
}

/// Adaptador manual de Hive para Vault (typeId = 1).
class VaultAdapter extends TypeAdapter<Vault> {
  @override
  final int typeId = 1;

  @override
  Vault read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Vault(
      id: fields[0] as String,
      name: fields[1] as String,
      targetAmount: (fields[2] as num).toDouble(),
      currentAmount: (fields[3] as num).toDouble(),
      currency: fields[4] as String,
      targetDate: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Vault obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.targetAmount)
      ..writeByte(3)
      ..write(obj.currentAmount)
      ..writeByte(4)
      ..write(obj.currency)
      ..writeByte(5)
      ..write(obj.targetDate);
  }
}
