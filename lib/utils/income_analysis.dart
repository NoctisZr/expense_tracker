import '../models/income.dart';

class IncomeSpendingAnalysis {
  final double totalSpent;
  final double percentSpent;
  final int daysElapsed;
  final double avgPerDay;
  final int? estimatedDaysUntilDepleted;
  final DateTime? estimatedDepletionDate;
  final bool periodClosed;
  final bool alreadyDepleted;

  const IncomeSpendingAnalysis({
    required this.totalSpent,
    required this.percentSpent,
    required this.daysElapsed,
    required this.avgPerDay,
    required this.estimatedDaysUntilDepleted,
    required this.estimatedDepletionDate,
    required this.periodClosed,
    required this.alreadyDepleted,
  });
}

IncomeSpendingAnalysis analyzeIncomeSpending({
  required Income income,
  required double totalSpentInPeriod,
  required DateTime periodEnd,
  required bool periodClosed,
}) {
  final Duration elapsed = periodEnd.difference(income.date);
  final int daysElapsed = elapsed.isNegative ? 0 : elapsed.inDays;

  final double percentSpent =
      income.amount > 0 ? (totalSpentInPeriod / income.amount * 100) : 0;
  final bool alreadyDepleted = income.amount > 0 && totalSpentInPeriod >= income.amount;

  double avgPerDay = 0;
  if (daysElapsed > 0 && totalSpentInPeriod > 0) {
    avgPerDay = totalSpentInPeriod / daysElapsed;
  }

  int? estimatedDaysUntilDepleted;
  DateTime? estimatedDepletionDate;
  if (!periodClosed && !alreadyDepleted && avgPerDay > 0) {
    final double remaining = income.amount - totalSpentInPeriod;
    estimatedDaysUntilDepleted = (remaining / avgPerDay).ceil();
    estimatedDepletionDate = DateTime.now().add(Duration(days: estimatedDaysUntilDepleted));
  }

  return IncomeSpendingAnalysis(
    totalSpent: totalSpentInPeriod,
    percentSpent: percentSpent,
    daysElapsed: daysElapsed,
    avgPerDay: avgPerDay,
    estimatedDaysUntilDepleted: estimatedDaysUntilDepleted,
    estimatedDepletionDate: estimatedDepletionDate,
    periodClosed: periodClosed,
    alreadyDepleted: alreadyDepleted,
  );
}
