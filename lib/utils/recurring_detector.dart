import '../models/expense.dart';
import '../models/recurring_expense.dart';

/// Un gasto que parece repetirse solo (suscripción, alquiler...) y que aún no
/// está registrado como recurrente.
class RecurringSuggestion {
  final String name;
  final double amount;
  final String currency;
  final String category;
  final String frequency;
  final DateTime nextDue;
  final int occurrences;

  const RecurringSuggestion({
    required this.name,
    required this.amount,
    required this.currency,
    required this.category,
    required this.frequency,
    required this.nextDue,
    required this.occurrences,
  });
}

/// Tolerancia (en días) y distancia típica para cada frecuencia.
const Map<String, List<int>> _frequencyRanges = {
  RecurringExpense.weekly: [7, 2],
  RecurringExpense.biweekly: [14, 3],
  RecurringExpense.monthly: [30, 4],
  RecurringExpense.yearly: [365, 10],
};

/// Busca gastos con el mismo nombre, importe parecido y una separación
/// regular (semanal, cada 2 semanas, mensual o anual). Función pura.
///  - Necesita al menos 3 repeticiones.
///  - Ignora los que ya son recurrentes ([existingNames]) o fueron
///    descartados por el usuario ([ignoredNames]); ambos en minúscula.
///  - Ignora los que dejaron de repetirse (pasó más del doble del intervalo).
List<RecurringSuggestion> detectRecurringPatterns(
  List<Expense> expenses, {
  required Set<String> existingNames,
  required Set<String> ignoredNames,
  DateTime? now,
}) {
  final DateTime today = now ?? DateTime.now();
  final Map<String, List<Expense>> groups = {};
  for (final e in expenses) {
    final String key = e.name.trim().toLowerCase();
    if (key.isEmpty || existingNames.contains(key) || ignoredNames.contains(key)) continue;
    groups.putIfAbsent(key, () => []).add(e);
  }

  final List<RecurringSuggestion> result = [];
  for (final entry in groups.entries) {
    final List<Expense> list = entry.value..sort((a, b) => a.date.compareTo(b.date));
    if (list.length < 3) continue;

    // Se analizan las últimas 6 repeticiones como máximo.
    final List<Expense> recent = list.length > 6 ? list.sublist(list.length - 6) : list;
    final Expense last = recent.last;

    // Misma divisa e importes parecidos (±15 % respecto al promedio).
    if (recent.any((e) => e.currency != last.currency)) continue;
    final double mean = recent.fold<double>(0, (sum, e) => sum + e.amount) / recent.length;
    if (mean <= 0 || recent.any((e) => (e.amount - mean).abs() / mean > 0.15)) continue;

    final List<int> gaps = [
      for (int i = 1; i < recent.length; i++) recent[i].date.difference(recent[i - 1].date).inDays,
    ];
    final List<int> sorted = List<int>.of(gaps)..sort();
    final int median = sorted[sorted.length ~/ 2];

    String? frequency;
    for (final f in _frequencyRanges.entries) {
      final int typical = f.value[0];
      final int tolerance = f.value[1];
      if ((median - typical).abs() <= tolerance) {
        final int consistent = gaps.where((g) => (g - typical).abs() <= tolerance + 1).length;
        if (consistent / gaps.length >= 0.7) frequency = f.key;
        break;
      }
    }
    if (frequency == null) continue;

    // Si hace mucho que no se repite, probablemente ya se canceló.
    final int typicalGap = _frequencyRanges[frequency]![0];
    if (today.difference(last.date).inDays > typicalGap * 2) continue;

    DateTime due = DateTime(last.date.year, last.date.month, last.date.day, 9);
    int guard = 0;
    while (!due.isAfter(today) && guard < 60) {
      due = RecurringExpense.advance(due, frequency, last.date.day);
      guard++;
    }

    result.add(RecurringSuggestion(
      name: last.name.trim(),
      amount: double.parse(mean.toStringAsFixed(2)),
      currency: last.currency,
      category: last.category,
      frequency: frequency,
      nextDue: due,
      occurrences: list.length,
    ));
  }
  result.sort((a, b) => b.occurrences.compareTo(a.occurrences));
  return result;
}
