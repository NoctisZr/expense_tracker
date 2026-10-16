import '../models/vault_transaction.dart';

class SavingsProjection {
  final bool goalReached;
  final bool hasEnoughData;
  final double avgPerDay;
  final int estimatedDaysRemaining;
  final DateTime? estimatedCompletionDate;

  const SavingsProjection({
    required this.goalReached,
    required this.hasEnoughData,
    required this.avgPerDay,
    required this.estimatedDaysRemaining,
    required this.estimatedCompletionDate,
  });

  static const SavingsProjection notEnoughData = SavingsProjection(
    goalReached: false,
    hasEnoughData: false,
    avgPerDay: 0,
    estimatedDaysRemaining: 0,
    estimatedCompletionDate: null,
  );
}

SavingsProjection calculateSavingsProjection({
  required List<VaultTransaction> transactions,
  required double currentAmount,
  required double targetAmount,
}) {
  if (targetAmount > 0 && currentAmount >= targetAmount) {
    return const SavingsProjection(
      goalReached: true,
      hasEnoughData: true,
      avgPerDay: 0,
      estimatedDaysRemaining: 0,
      estimatedCompletionDate: null,
    );
  }

  final List<VaultTransaction> deposits = transactions
      .where((t) => !t.isWithdrawal)
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  if (deposits.length < 2) {
    return SavingsProjection.notEnoughData;
  }

  final DateTime first = deposits.first.date;
  final DateTime last = deposits.last.date;
  final int spanDays = last.difference(first).inDays;

  if (spanDays <= 0) {
    return SavingsProjection.notEnoughData;
  }

  final double totalDeposited =
      deposits.fold(0.0, (sum, t) => sum + t.convertedAmount);
  final double avgPerDay = totalDeposited / spanDays;

  if (avgPerDay <= 0) {
    return SavingsProjection.notEnoughData;
  }

  final double remaining = targetAmount - currentAmount;
  final int daysRemaining = (remaining / avgPerDay).ceil();
  final DateTime completion = DateTime.now().add(Duration(days: daysRemaining));

  return SavingsProjection(
    goalReached: false,
    hasEnoughData: true,
    avgPerDay: avgPerDay,
    estimatedDaysRemaining: daysRemaining,
    estimatedCompletionDate: completion,
  );
}
