/// Cálculo PURO (sin Flutter ni Hive) del saldo entre dos personas que
/// comparten gastos. Un gasto en pareja guarda el total de la cuenta, la parte
/// de quien lo anotó (el "autor") y quién pagó.
class SharedEntry {
  /// Total de la cuenta (ya convertido a una misma moneda).
  final double total;

  /// Parte que le corresponde al autor del gasto.
  final double authorPart;

  /// Si quien pagó la cuenta fue el autor.
  final bool paidByAuthor;

  /// Si el autor del gasto soy yo (true) o mi pareja (false).
  final bool byMe;

  const SharedEntry({
    required this.total,
    required this.authorPart,
    required this.paidByAuthor,
    this.byMe = true,
  });

  /// Lo que el otro le debe al autor (negativo: el autor le debe al otro).
  double get owedToAuthor => paidByAuthor ? total - authorPart : -authorPart;

  /// Mi saldo en este gasto: positivo = mi pareja me debe.
  double get myBalance => byMe ? owedToAuthor : -owedToAuthor;
}

/// Un pago entre ustedes para saldar cuentas (ya convertido a una moneda).
class SettlementEntry {
  final double amount;

  /// Si quien anotó el pago fue quien pagó (a la otra persona).
  final bool paidByAuthor;

  /// Si el autor del registro soy yo.
  final bool byMe;

  const SettlementEntry({required this.amount, required this.paidByAuthor, this.byMe = true});

  /// Efecto en mi saldo: si yo pagué, lo que me deben sube; si me pagaron, baja.
  double get myBalance => (paidByAuthor == byMe) ? amount : -amount;
}

/// Saldo total de la pareja desde mi punto de vista, redondeado a 2 decimales:
/// positivo = tu pareja te debe; negativo = tú le debes; 0 = están a mano.
double coupleNetBalance(
  Iterable<SharedEntry> entries, {
  Iterable<SettlementEntry> settlements = const [],
}) {
  double sum = 0;
  for (final e in entries) {
    sum += e.myBalance;
  }
  for (final s in settlements) {
    sum += s.myBalance;
  }
  return (sum * 100).roundToDouble() / 100;
}
