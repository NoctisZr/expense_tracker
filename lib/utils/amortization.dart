import 'dart:math' as math;

/// Lógica PURA (sin Flutter ni Hive) de créditos y cuotas: cronograma de
/// pagos, costo efectivo anual (TCEA), comparador de plazos y simulación de
/// pago adelantado. Todo se redondea a 2 decimales y la última cuota se ajusta
/// para que la suma de capitales sea exactamente el monto financiado.

/// Método de amortización.
class LoanMethod {
  LoanMethod._();

  /// Cuota fija (sistema francés).
  static const String french = 'french';

  /// Capital fijo, cuotas decrecientes (sistema alemán).
  static const String german = 'german';

  /// Interés plano: el interés se calcula siempre sobre el monto original.
  static const String flat = 'flat';

  static const List<String> all = [french, german, flat];
}

/// Cómo se expresa la tasa de interés.
class RateType {
  RateType._();

  static const String none = 'none';

  /// Tasa efectiva mensual.
  static const String monthly = 'monthly';

  /// Tasa efectiva anual (TEA).
  static const String tea = 'tea';

  /// Tasa nominal anual (TNA), capitalización mensual.
  static const String tna = 'tna';

  static const List<String> all = [none, monthly, tea, tna];
}

/// Redondea a 2 decimales.
double round2(double value) => (value * 100).roundToDouble() / 100;

/// Suma [months] meses a [base] conservando el día ancla (si el mes es más
/// corto, usa su último día).
DateTime addMonthsClamped(DateTime base, int months) {
  final int total = base.year * 12 + (base.month - 1) + months;
  final int year = total ~/ 12;
  final int month = total % 12 + 1;
  final int daysInMonth = DateTime(year, month + 1, 0).day;
  final int day = base.day > daysInMonth ? daysInMonth : base.day;
  return DateTime(year, month, day, base.hour, base.minute);
}

/// Tasa efectiva MENSUAL (como fracción, 0.02 = 2 %) a partir de la tasa dada.
double monthlyRateFrom(String rateType, double percent) {
  final double r = percent / 100;
  switch (rateType) {
    case RateType.tea:
      return math.pow(1 + r, 1 / 12).toDouble() - 1;
    case RateType.tna:
      return r / 12;
    case RateType.monthly:
      return r;
    default:
      return 0;
  }
}

/// Cuota fija del sistema francés.
double frenchPayment(double principal, double monthlyRate, int installments) {
  if (installments <= 0) return 0;
  if (monthlyRate == 0) return round2(principal / installments);
  final double denom = 1 - math.pow(1 + monthlyRate, -installments).toDouble();
  return round2(principal * monthlyRate / denom);
}

/// Condiciones de un préstamo (sin la comisión inicial, que se pasa aparte).
class LoanTerms {
  final double principal;

  /// Cuotas de amortización (sin contar los meses de gracia).
  final int installments;
  final String rateType;
  final double ratePercent;
  final String method;

  /// Seguro o cargos que se suman a CADA cuota.
  final double installmentFee;

  /// Meses iniciales en que solo se pagan intereses y cargos.
  final int graceMonths;

  /// Fecha de la primera cuota.
  final DateTime firstDue;

  const LoanTerms({
    required this.principal,
    required this.installments,
    required this.firstDue,
    this.rateType = RateType.none,
    this.ratePercent = 0,
    this.method = LoanMethod.french,
    this.installmentFee = 0,
    this.graceMonths = 0,
  });

  double get monthlyRate => monthlyRateFrom(rateType, ratePercent);

  LoanTerms copyWith({
    double? principal,
    int? installments,
    String? rateType,
    double? ratePercent,
    String? method,
    double? installmentFee,
    int? graceMonths,
    DateTime? firstDue,
  }) =>
      LoanTerms(
        principal: principal ?? this.principal,
        installments: installments ?? this.installments,
        rateType: rateType ?? this.rateType,
        ratePercent: ratePercent ?? this.ratePercent,
        method: method ?? this.method,
        installmentFee: installmentFee ?? this.installmentFee,
        graceMonths: graceMonths ?? this.graceMonths,
        firstDue: firstDue ?? this.firstDue,
      );

  Map<String, dynamic> toMap() => {
        'principal': principal,
        'installments': installments,
        'rateType': rateType,
        'ratePercent': ratePercent,
        'method': method,
        'installmentFee': installmentFee,
        'graceMonths': graceMonths,
        'firstDue': firstDue.toIso8601String(),
      };

  factory LoanTerms.fromMap(Map<dynamic, dynamic> map) {
    final String rateType = map['rateType']?.toString() ?? RateType.none;
    final String method = map['method']?.toString() ?? LoanMethod.french;
    return LoanTerms(
      principal: (map['principal'] as num).toDouble(),
      installments: (map['installments'] as num).toInt(),
      rateType: RateType.all.contains(rateType) ? rateType : RateType.none,
      ratePercent: (map['ratePercent'] as num?)?.toDouble() ?? 0,
      method: LoanMethod.all.contains(method) ? method : LoanMethod.french,
      installmentFee: (map['installmentFee'] as num?)?.toDouble() ?? 0,
      graceMonths: (map['graceMonths'] as num?)?.toInt() ?? 0,
      firstDue: DateTime.parse(map['firstDue'].toString()),
    );
  }
}

/// Una cuota del cronograma.
class Installment {
  final int number;
  final DateTime dueDate;
  final double capital;
  final double interest;
  final double fees;

  /// Saldo de capital pendiente DESPUÉS de pagar esta cuota.
  final double balanceAfter;

  const Installment({
    required this.number,
    required this.dueDate,
    required this.capital,
    required this.interest,
    required this.fees,
    required this.balanceAfter,
  });

  double get total => round2(capital + interest + fees);

  Map<String, dynamic> toMap() => {
        'number': number,
        'dueDate': dueDate.toIso8601String(),
        'capital': capital,
        'interest': interest,
        'fees': fees,
        'balanceAfter': balanceAfter,
      };

  factory Installment.fromMap(Map<dynamic, dynamic> map) => Installment(
        number: (map['number'] as num).toInt(),
        dueDate: DateTime.parse(map['dueDate'].toString()),
        capital: (map['capital'] as num).toDouble(),
        interest: (map['interest'] as num).toDouble(),
        fees: (map['fees'] as num?)?.toDouble() ?? 0,
        balanceAfter: (map['balanceAfter'] as num).toDouble(),
      );
}

/// Construye el cronograma. Los meses de gracia van primero (solo intereses
/// y cargos). [numberOffset] desplaza la numeración (se usa al renegociar).
List<Installment> buildSchedule(LoanTerms t, {int numberOffset = 0}) {
  final int n = t.installments;
  if (n <= 0 || t.principal <= 0) return const [];

  final double i = t.monthlyRate;
  final double principal = round2(t.principal);
  double balance = principal;
  final List<Installment> out = [];
  int idx = 0;

  for (int g = 0; g < t.graceMonths; g++) {
    idx++;
    out.add(Installment(
      number: numberOffset + idx,
      dueDate: addMonthsClamped(t.firstDue, idx - 1),
      capital: 0,
      interest: round2(balance * i),
      fees: t.installmentFee,
      balanceAfter: balance,
    ));
  }

  final double fixed =
      t.method == LoanMethod.french ? frenchPayment(principal, i, n) : 0;

  for (int k = 1; k <= n; k++) {
    idx++;
    final double base = t.method == LoanMethod.flat ? principal : balance;
    final double interest = round2(base * i);
    double capital;
    if (k == n) {
      capital = balance;
    } else if (t.method == LoanMethod.french) {
      capital = round2(fixed - interest);
    } else {
      capital = round2(principal / n);
    }
    if (capital > balance) capital = balance;
    if (capital < 0) capital = 0;
    balance = round2(balance - capital);
    out.add(Installment(
      number: numberOffset + idx,
      dueDate: addMonthsClamped(t.firstDue, idx - 1),
      capital: capital,
      interest: interest,
      fees: t.installmentFee,
      balanceAfter: balance,
    ));
  }
  return out;
}

/// Costo efectivo anual (TCEA / CAE) en %, calculado con la TIR de los
/// flujos: entra (monto − comisión inicial) y salen las cuotas.
double effectiveAnnualCost(double principal, double upfrontFee, List<Installment> schedule) {
  if (schedule.isEmpty || principal <= 0) return 0;
  final List<double> flows = [principal - upfrontFee];
  for (final s in schedule) {
    flows.add(-s.total);
  }

  double npv(double r) {
    double sum = 0;
    for (int t = 0; t < flows.length; t++) {
      sum += flows[t] / math.pow(1 + r, t).toDouble();
    }
    return sum;
  }

  if (npv(0) >= -1e-9) return 0;
  double lo = 0;
  double hi = 5; // 500 % mensual como tope absurdo
  if (npv(hi) < 0) return (math.pow(1 + hi, 12).toDouble() - 1) * 100;
  for (int k = 0; k < 200; k++) {
    final double mid = (lo + hi) / 2;
    if (npv(mid) > 0) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  final double irr = (lo + hi) / 2;
  return (math.pow(1 + irr, 12).toDouble() - 1) * 100;
}

/// Resumen de un plan de pagos.
class LoanSummary {
  final double principal;
  final double firstPayment;
  final double lastPayment;
  final double minPayment;
  final double maxPayment;
  final double totalPaid;
  final double totalInterest;
  final double totalFees;
  final double tcea;
  final int count;

  const LoanSummary({
    required this.principal,
    required this.firstPayment,
    required this.lastPayment,
    required this.minPayment,
    required this.maxPayment,
    required this.totalPaid,
    required this.totalInterest,
    required this.totalFees,
    required this.tcea,
    required this.count,
  });

  /// Lo que pagas de más respecto al monto financiado.
  double get extraCost => round2(totalPaid - principal);

  /// El monto de cuota varía (método alemán o gracia).
  bool get varies => (maxPayment - minPayment).abs() > 0.009;
}

LoanSummary summarize(double principal, double upfrontFee, List<Installment> schedule) {
  if (schedule.isEmpty) {
    return LoanSummary(
      principal: principal,
      firstPayment: 0,
      lastPayment: 0,
      minPayment: 0,
      maxPayment: 0,
      totalPaid: 0,
      totalInterest: 0,
      totalFees: upfrontFee,
      tcea: 0,
      count: 0,
    );
  }
  double paid = upfrontFee;
  double interest = 0;
  double fees = upfrontFee;
  double minP = schedule.first.total;
  double maxP = schedule.first.total;
  for (final s in schedule) {
    paid += s.total;
    interest += s.interest;
    fees += s.fees;
    if (s.total < minP) minP = s.total;
    if (s.total > maxP) maxP = s.total;
  }
  return LoanSummary(
    principal: principal,
    firstPayment: schedule.first.total,
    lastPayment: schedule.last.total,
    minPayment: minP,
    maxPayment: maxP,
    totalPaid: round2(paid),
    totalInterest: round2(interest),
    totalFees: round2(fees),
    tcea: effectiveAnnualCost(principal, upfrontFee, schedule),
    count: schedule.length,
  );
}

/// Compara el mismo préstamo con distintos números de cuotas.
Map<int, LoanSummary> compareTerms(LoanTerms base, double upfrontFee, List<int> counts) {
  final Map<int, LoanSummary> result = {};
  for (final c in counts) {
    final LoanTerms t = base.copyWith(installments: c);
    result[c] = summarize(t.principal, upfrontFee, buildSchedule(t));
  }
  return result;
}

/// Resultado de simular un pago adelantado a capital.
class PrepayResult {
  /// Cuotas que quedan después del abono (con numeración continuada).
  final List<Installment> remaining;
  final double interestSaved;
  final int installmentsSaved;
  final double newPayment;

  const PrepayResult({
    required this.remaining,
    required this.interestSaved,
    required this.installmentsSaved,
    required this.newPayment,
  });
}

/// Simula abonar [extra] a capital justo después de pagar la cuota
/// [afterInstallment]. Con [reduceTerm] se mantiene la cuota y se acorta el
/// plazo; si no, se mantiene el plazo y baja la cuota. No aplica al interés
/// plano ni dentro del periodo de gracia (devuelve null).
PrepayResult? simulatePrepayment(
  LoanTerms t,
  List<Installment> schedule, {
  required int afterInstallment,
  required double extra,
  required bool reduceTerm,
}) {
  if (t.method == LoanMethod.flat) return null;
  final int k = afterInstallment;
  if (k <= t.graceMonths || k < 1 || k >= schedule.length) return null;
  if (extra <= 0) return null;

  final double balance = schedule[k - 1].balanceAfter;
  final double newBalance = round2(balance - (extra > balance ? balance : extra));
  final int originalRemaining = schedule.length - k;
  double originalInterest = 0;
  for (int j = k; j < schedule.length; j++) {
    originalInterest += schedule[j].interest;
  }

  if (newBalance <= 0) {
    return PrepayResult(
      remaining: const [],
      interestSaved: round2(originalInterest),
      installmentsSaved: originalRemaining,
      newPayment: 0,
    );
  }

  final double i = t.monthlyRate;
  int newCount = originalRemaining;
  if (reduceTerm) {
    final Installment ref = schedule[k - 1];
    if (t.method == LoanMethod.french) {
      final double pay = round2(ref.capital + ref.interest);
      if (i == 0) {
        if (pay <= 0) return null;
        newCount = (newBalance / pay).ceil();
      } else {
        if (pay <= newBalance * i) return null;
        newCount = (-math.log(1 - newBalance * i / pay) / math.log(1 + i)).ceil();
      }
    } else {
      if (ref.capital <= 0) return null;
      newCount = (newBalance / ref.capital).ceil();
    }
    if (newCount < 1) newCount = 1;
    if (newCount > originalRemaining) newCount = originalRemaining;
  }

  final LoanTerms next = LoanTerms(
    principal: newBalance,
    installments: newCount,
    firstDue: schedule[k].dueDate,
    rateType: t.rateType,
    ratePercent: t.ratePercent,
    method: t.method,
    installmentFee: t.installmentFee,
    graceMonths: 0,
  );
  final List<Installment> remaining = buildSchedule(next, numberOffset: k);
  double newInterest = 0;
  for (final s in remaining) {
    newInterest += s.interest;
  }
  return PrepayResult(
    remaining: remaining,
    interestSaved: round2(originalInterest - newInterest),
    installmentsSaved: originalRemaining - newCount,
    newPayment: remaining.isEmpty ? 0 : remaining.first.total,
  );
}
