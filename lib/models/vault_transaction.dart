import 'package:hive/hive.dart';

/// Un movimiento individual (aporte o retiro) dentro de una bóveda.
class VaultTransaction {
  final String id;
  final String vaultId;
  final double amount;
  final String currency;
  final double convertedAmount;
  final double rateUsed;
  final DateTime date;
  final bool isWithdrawal;

  VaultTransaction({
    required this.id,
    required this.vaultId,
    required this.amount,
    required this.currency,
    required this.convertedAmount,
    required this.rateUsed,
    required this.date,
    required this.isWithdrawal,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'vaultId': vaultId,
        'amount': amount,
        'currency': currency,
        'convertedAmount': convertedAmount,
        'rateUsed': rateUsed,
        'date': date.toIso8601String(),
        'isWithdrawal': isWithdrawal,
      };

  factory VaultTransaction.fromJson(Map<String, dynamic> json) => VaultTransaction(
        id: json['id'] as String,
        vaultId: json['vaultId'] as String,
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String,
        convertedAmount: (json['convertedAmount'] as num).toDouble(),
        rateUsed: (json['rateUsed'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        isWithdrawal: json['isWithdrawal'] as bool,
      );
}

/// Adaptador manual de Hive para VaultTransaction (typeId = 2).
class VaultTransactionAdapter extends TypeAdapter<VaultTransaction> {
  @override
  final int typeId = 2;

  @override
  VaultTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VaultTransaction(
      id: fields[0] as String,
      vaultId: fields[1] as String,
      amount: (fields[2] as num).toDouble(),
      currency: fields[3] as String,
      convertedAmount: (fields[4] as num).toDouble(),
      rateUsed: (fields[5] as num).toDouble(),
      date: fields[6] as DateTime,
      isWithdrawal: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, VaultTransaction obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.vaultId)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.currency)
      ..writeByte(4)
      ..write(obj.convertedAmount)
      ..writeByte(5)
      ..write(obj.rateUsed)
      ..writeByte(6)
      ..write(obj.date)
      ..writeByte(7)
      ..write(obj.isWithdrawal);
  }
}
