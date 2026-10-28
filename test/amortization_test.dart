import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/credit_purchase.dart';
import 'package:expense_tracker/utils/amortization.dart';

LoanTerms _terms({
  double principal = 1200,
  int n = 6,
  String rateType = RateType.monthly,
  double rate = 2,
  String method = LoanMethod.french,
  double fee = 0,
  int grace = 0,
  DateTime? firstDue,
}) =>
    LoanTerms(
      principal: principal,
      installments: n,
      rateType: rateType,
      ratePercent: rate,
      method: method,
      installmentFee: fee,
      graceMonths: grace,
      firstDue: firstDue ?? DateTime(2026, 1, 31, 9),
    );

double _sumCapital(List<Installment> s) => s.fold(0.0, (a, b) => a + b.capital);

void main() {
  group('conversión de tasas', () {
    test('TEA 36 % = TEM 2.5955 %', () {
      expect(monthlyRateFrom(RateType.tea, 36) * 100, closeTo(2.5955, 0.0001));
    });
    test('TNA 36 % = TEM 3 %', () {
      expect(monthlyRateFrom(RateType.tna, 36) * 100, closeTo(3.0, 0.0001));
    });
    test('sin interés = 0', () {
      expect(monthlyRateFrom(RateType.none, 50), 0);
    });
  });

  group('cuota fija (francés)', () {
    final s = buildSchedule(_terms());
    test('cuota 214.23 y primera fila', () {
      expect(s.length, 6);
      expect(s.first.total, 214.23);
      expect(s.first.interest, 24.00);
      expect(s.first.capital, 190.23);
      expect(s.first.balanceAfter, 1009.77);
    });
    test('totales: 1285.39 y 85.39 de intereses', () {
      final sum = summarize(1200, 0, s);
      expect(sum.totalPaid, 1285.39);
      expect(sum.totalInterest, 85.39);
    });
    test('última cuota deja saldo 0 y la suma de capitales es exacta', () {
      expect(s.last.balanceAfter, 0);
      expect(s.last.interest, 4.20);
      expect(_sumCapital(s), closeTo(1200, 0.001));
    });
  });

  group('otros métodos', () {
    test('alemán: total 1284 (intereses 84)', () {
      final s = buildSchedule(_terms(method: LoanMethod.german));
      final sum = summarize(1200, 0, s);
      expect(sum.totalPaid, 1284.00);
      expect(sum.totalInterest, 84.00);
      expect(s.first.total, 224.00);
      expect(s.last.total, 204.00);
    });
    test('plano: intereses 144 y cuota 224', () {
      final s = buildSchedule(_terms(method: LoanMethod.flat));
      final sum = summarize(1200, 0, s);
      expect(sum.totalInterest, 144.00);
      expect(s.first.total, 224.00);
      expect(s.last.total, 224.00);
    });
    test('sin interés: 200 por cuota y TCEA 0', () {
      final s = buildSchedule(_terms(rateType: RateType.none, rate: 0));
      expect(s.every((x) => x.total == 200), isTrue);
      expect(summarize(1200, 0, s).tcea, 0);
    });
    test('una sola cuota', () {
      final s = buildSchedule(_terms(n: 1));
      expect(s.length, 1);
      expect(s.first.capital, 1200);
      expect(s.first.interest, 24.00);
      expect(s.first.balanceAfter, 0);
    });
  });

  group('TCEA', () {
    test('con comisión 30 y seguro 5: ≈ 50.28 %', () {
      final s = buildSchedule(_terms(fee: 5));
      expect(effectiveAnnualCost(1200, 30, s), closeTo(50.28, 0.05));
    });
  });

  group('gracia', () {
    test('los meses de gracia solo pagan interés y el saldo no baja', () {
      final s = buildSchedule(_terms(grace: 2));
      expect(s.length, 8);
      expect(s[0].capital, 0);
      expect(s[1].capital, 0);
      expect(s[1].balanceAfter, 1200);
      expect(s.last.balanceAfter, 0);
      expect(_sumCapital(s), closeTo(1200, 0.001));
    });
  });

  group('fechas', () {
    test('día 31 se ajusta a meses cortos y vuelve a 31', () {
      final s = buildSchedule(_terms(n: 4));
      expect(s[0].dueDate.day, 31); // enero
      expect(s[1].dueDate.day, 28); // febrero 2026
      expect(s[2].dueDate.day, 31); // marzo
      expect(s[3].dueDate.day, 30); // abril
    });
    test('cruza de año', () {
      final s = buildSchedule(_terms(n: 3, firstDue: DateTime(2026, 11, 15, 9)));
      expect(s[2].dueDate.year, 2027);
      expect(s[2].dueDate.month, 1);
    });
  });

  group('comparador y pago adelantado', () {
    test('más cuotas = cuota menor y más intereses', () {
      final r = compareTerms(_terms(), 0, const [6, 12]);
      expect(r[12]!.firstPayment < r[6]!.firstPayment, isTrue);
      expect(r[12]!.totalInterest > r[6]!.totalInterest, isTrue);
    });
    test('reducir plazo: abonar 300 tras la cuota 2 deja 3 cuotas', () {
      final t = _terms();
      final r = simulatePrepayment(t, buildSchedule(t), afterInstallment: 2, extra: 300, reduceTerm: true)!;
      expect(r.remaining.length, 3);
      expect(r.installmentsSaved, 1);
      expect(r.interestSaved > 0, isTrue);
      expect(r.remaining.last.balanceAfter, 0);
    });
    test('reducir cuota: mantiene el plazo y baja la cuota', () {
      final t = _terms();
      final s = buildSchedule(t);
      final r = simulatePrepayment(t, s, afterInstallment: 2, extra: 300, reduceTerm: false)!;
      expect(r.remaining.length, 4);
      expect(r.newPayment < s.first.total, isTrue);
    });
    test('no aplica al interés plano', () {
      final t = _terms(method: LoanMethod.flat);
      expect(simulatePrepayment(t, buildSchedule(t), afterInstallment: 2, extra: 100, reduceTerm: true), isNull);
    });
  });

  group('CreditPurchase', () {
    CreditPurchase credit() => CreditPurchase(
          id: 'c1',
          name: 'Laptop',
          category: 'compras',
          purchaseDate: DateTime(2026, 1, 1),
          currency: 'USD',
          financed: 1200,
          upfrontFee: 30,
          terms: _terms(),
        );

    test('la comisión inicial se suma a la primera cuota', () {
      final c = credit();
      expect(c.amountFor(1), 244.23);
      expect(c.amountFor(2), 214.23);
    });
    test('ajuste manual de una cuota', () {
      final c = credit().copyWith(overrides: {2: 220.0});
      expect(c.amountFor(2), 220.0);
    });
    test('saldo pendiente según las cuotas registradas', () {
      expect(credit().outstanding, 1200);
      expect(credit().copyWith(registeredCount: 2).outstanding, 815.74);
      expect(credit().copyWith(registeredCount: 6).outstanding, 0);
    });
    test('renegociar congela lo registrado y recalcula el resto', () {
      final c = credit().copyWith(registeredCount: 2);
      final r = c.renegotiate(rateType: RateType.monthly, ratePercent: 1, remainingInstallments: 4);
      expect(r.offset, 2);
      expect(r.frozen.length, 2);
      expect(r.totalInstallments, 6);
      expect(r.schedule[0].total, c.schedule[0].total);
      expect(r.schedule[1].total, c.schedule[1].total);
      expect(r.schedule[2].number, 3);
      expect(r.schedule.last.balanceAfter, 0);
      expect(r.outstanding, 815.74);
    });
    test('toMap/fromMap conserva todo (también tras renegociar)', () {
      final c = credit()
          .copyWith(registeredCount: 1, overrides: {1: 250.0})
          .renegotiate(rateType: RateType.tea, ratePercent: 30, remainingInstallments: 5);
      final back = CreditPurchase.fromMap(Map<dynamic, dynamic>.from(c.toMap()));
      expect(back.registeredCount, 1);
      expect(back.offset, 1);
      expect(back.frozen.length, 1);
      expect(back.overrides[1], 250.0);
      expect(back.totalInstallments, c.totalInstallments);
      expect(back.schedule.last.total, c.schedule.last.total);
    });
  });
}
