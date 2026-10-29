import '../utils/amortization.dart';

/// Compra financiada en cuotas (tarjeta de crédito u otro financiamiento).
/// No necesita adaptador de Hive: se guarda como lista de mapas simples en la
/// caja de ajustes (clave `credits_<espacio>`).
///
/// Modo de registro ([mode]):
/// - `due` (B, por defecto): cada cuota genera un gasto en su vencimiento.
/// - `now` (A): un solo gasto hoy por el total; las cuotas no generan gastos.
/// - `interest` (C): un gasto hoy por el total y cada cuota solo registra su
///   interés y cargos (el capital ya se gastó al comprar).
///
/// Las cuotas se registran siempre en orden: [registeredCount] cuotas ya
/// tienen su gasto. Al renegociar (cambiar tasa o plazo) las ya registradas
/// quedan congeladas en [frozen] y solo se recalculan las futuras.
class CreditMode {
  CreditMode._();
  static const String due = 'due';
  static const String now = 'now';
  static const String interest = 'interest';
  static const List<String> all = [due, now, interest];
}

class CreditPurchase {
  final String id;
  final String name;
  final String category;
  final DateTime purchaseDate;
  final String currency;
  final String? accountId;
  final String? note;

  /// Cómo se registran los gastos (ver [CreditMode]).
  final String mode;

  /// Monto financiado original.
  final double financed;

  /// Comisión inicial: se suma al gasto de la primera cuota.
  final double upfrontFee;

  /// Condiciones vigentes (sobre el saldo restante tras la última
  /// renegociación; si nunca se renegoció, son las originales).
  final LoanTerms terms;

  /// Cuántas cuotas congeladas hay antes de las condiciones vigentes.
  final int offset;
  final List<Installment> frozen;

  /// Cuántas cuotas ya generaron su gasto.
  final int registeredCount;

  /// Monto real cobrado por el banco en una cuota (número -> monto).
  final Map<int, double> overrides;

  const CreditPurchase({
    required this.id,
    required this.name,
    required this.category,
    required this.purchaseDate,
    required this.currency,
    required this.financed,
    required this.terms,
    this.accountId,
    this.note,
    this.mode = CreditMode.due,
    this.upfrontFee = 0,
    this.offset = 0,
    this.frozen = const [],
    this.registeredCount = 0,
    this.overrides = const {},
  });

  /// Cronograma completo: cuotas congeladas + las calculadas con las
  /// condiciones vigentes.
  List<Installment> get schedule =>
      [...frozen, ...buildSchedule(terms, numberOffset: offset)];

  int get totalInstallments => schedule.length;

  bool get isFinished => registeredCount >= totalInstallments;

  /// Monto del gasto de la cuota [n]: lo que el usuario anotó como cobrado
  /// o, si no, el calculado (+ comisión inicial en la primera cuota).
  double amountFor(int n) {
    final double? manual = overrides[n];
    if (manual != null) return manual;
    final List<Installment> s = schedule;
    if (n < 1 || n > s.length) return 0;
    return round2(s[n - 1].total + (n == 1 ? upfrontFee : 0));
  }

  /// Monto del GASTO que genera la cuota [n] según el modo: la cuota entera
  /// (B), nada (A) o solo interés y cargos (C). 0 = no genera gasto.
  double expenseAmountFor(int n) {
    switch (mode) {
      case CreditMode.now:
        return 0;
      case CreditMode.interest:
        final List<Installment> s = schedule;
        if (n < 1 || n > s.length) return 0;
        final double v = round2(amountFor(n) - s[n - 1].capital);
        return v < 0 ? 0 : v;
      default:
        return amountFor(n);
    }
  }

  /// Capital que falta por pagar.
  double get outstanding {
    final List<Installment> s = schedule;
    if (registeredCount <= 0) return financed;
    if (registeredCount >= s.length) return 0;
    return s[registeredCount - 1].balanceAfter;
  }

  /// Lo que falta por pagar en total (capital + intereses + cargos).
  double get remainingToPay {
    final int count = totalInstallments;
    double sum = 0;
    for (int n = registeredCount + 1; n <= count; n++) {
      sum += amountFor(n);
    }
    return round2(sum);
  }

  /// Próxima cuota pendiente (null si ya está todo registrado).
  Installment? get nextInstallment {
    final List<Installment> s = schedule;
    if (registeredCount >= s.length) return null;
    return s[registeredCount];
  }

  LoanSummary get summary {
    final List<Installment> s = schedule;
    double paid = upfrontFee;
    double interest = 0;
    double fees = upfrontFee;
    double minP = s.isEmpty ? 0 : s.first.total;
    double maxP = minP;
    for (final x in s) {
      paid += amountFor(x.number) - (x.number == 1 ? upfrontFee : 0);
      interest += x.interest;
      fees += x.fees;
      if (x.total < minP) minP = x.total;
      if (x.total > maxP) maxP = x.total;
    }
    final LoanSummary base = summarize(financed, upfrontFee, s);
    return LoanSummary(
      principal: financed,
      firstPayment: s.isEmpty ? 0 : s.first.total,
      lastPayment: s.isEmpty ? 0 : s.last.total,
      minPayment: minP,
      maxPayment: maxP,
      totalPaid: round2(paid),
      totalInterest: round2(interest),
      totalFees: round2(fees),
      tcea: base.tcea,
      count: s.length,
    );
  }

  CreditPurchase copyWith({
    String? name,
    String? category,
    String? accountId,
    String? note,
    String? mode,
    LoanTerms? terms,
    int? offset,
    List<Installment>? frozen,
    int? registeredCount,
    Map<int, double>? overrides,
  }) =>
      CreditPurchase(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        purchaseDate: purchaseDate,
        currency: currency,
        financed: financed,
        upfrontFee: upfrontFee,
        terms: terms ?? this.terms,
        accountId: accountId ?? this.accountId,
        note: note ?? this.note,
        mode: mode ?? this.mode,
        offset: offset ?? this.offset,
        frozen: frozen ?? this.frozen,
        registeredCount: registeredCount ?? this.registeredCount,
        overrides: overrides ?? this.overrides,
      );

  /// Cambia la tasa y/o el plazo SOLO de las cuotas futuras: las ya
  /// registradas quedan congeladas con su historial.
  CreditPurchase renegotiate({
    required String rateType,
    required double ratePercent,
    required int remainingInstallments,
    String? method,
  }) {
    final List<Installment> s = schedule;
    final int k = registeredCount.clamp(0, s.length).toInt();
    if (k >= s.length || remainingInstallments <= 0) return this;
    final Map<int, double> keptOverrides = {
      for (final e in overrides.entries)
        if (e.key <= k) e.key: e.value,
    };
    return copyWith(
      terms: LoanTerms(
        principal: outstanding,
        installments: remainingInstallments,
        firstDue: s[k].dueDate,
        rateType: rateType,
        ratePercent: ratePercent,
        method: method ?? terms.method,
        installmentFee: terms.installmentFee,
        installmentFeePct: terms.installmentFeePct,
        graceMonths: 0,
      ),
      offset: k,
      frozen: s.sublist(0, k),
      overrides: keptOverrides,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'purchaseDate': purchaseDate.toIso8601String(),
        'currency': currency,
        if (accountId != null) 'accountId': accountId,
        if (note != null && note!.isNotEmpty) 'note': note,
        'financed': financed,
        'upfrontFee': upfrontFee,
        'mode': mode,
        'terms': terms.toMap(),
        'offset': offset,
        'frozen': frozen.map((x) => x.toMap()).toList(),
        'registeredCount': registeredCount,
        'overrides': {for (final e in overrides.entries) e.key.toString(): e.value},
      };

  factory CreditPurchase.fromMap(Map<dynamic, dynamic> map) {
    final Map<int, double> overrides = {};
    final dynamic rawOverrides = map['overrides'];
    if (rawOverrides is Map) {
      rawOverrides.forEach((key, value) {
        final int? n = int.tryParse(key.toString());
        if (n != null && value is num) overrides[n] = value.toDouble();
      });
    }
    final List<Installment> frozen = [];
    final dynamic rawFrozen = map['frozen'];
    if (rawFrozen is List) {
      for (final item in rawFrozen) {
        if (item is Map) frozen.add(Installment.fromMap(item));
      }
    }
    return CreditPurchase(
      id: map['id'].toString(),
      name: map['name'].toString(),
      category: map['category']?.toString() ?? 'otros',
      purchaseDate: DateTime.parse(map['purchaseDate'].toString()),
      currency: map['currency'].toString(),
      accountId: map['accountId']?.toString(),
      note: map['note']?.toString(),
      mode: CreditMode.all.contains(map['mode']?.toString()) ? map['mode'].toString() : CreditMode.due,
      financed: (map['financed'] as num).toDouble(),
      upfrontFee: (map['upfrontFee'] as num?)?.toDouble() ?? 0,
      terms: LoanTerms.fromMap(map['terms'] as Map),
      offset: (map['offset'] as num?)?.toInt() ?? 0,
      frozen: frozen,
      registeredCount: (map['registeredCount'] as num?)?.toInt() ?? 0,
      overrides: overrides,
    );
  }
}
