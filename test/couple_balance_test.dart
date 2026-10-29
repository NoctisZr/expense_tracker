import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/utils/couple_balance.dart';

void main() {
  test('pagué yo 100 y mi parte es 50: mi pareja me debe 50', () {
    final e = SharedEntry(total: 100, authorPart: 50, paidByAuthor: true);
    expect(e.myBalance, 50);
    expect(coupleNetBalance([e]), 50);
  });

  test('pagó mi pareja 80 y mi parte es 30: le debo 30', () {
    final e = SharedEntry(total: 80, authorPart: 30, paidByAuthor: false);
    expect(coupleNetBalance([e]), -30);
  });

  test('los saldos de varios gastos se compensan', () {
    expect(
      coupleNetBalance(const [
        SharedEntry(total: 100, authorPart: 50, paidByAuthor: true), // +50
        SharedEntry(total: 60, authorPart: 30, paidByAuthor: false), // -30
      ]),
      20,
    );
    expect(
      coupleNetBalance(const [
        SharedEntry(total: 100, authorPart: 50, paidByAuthor: true),
        SharedEntry(total: 100, authorPart: 50, paidByAuthor: false),
      ]),
      0,
    );
  });

  test('gasto anotado por mi pareja: el saldo se invierte', () {
    // Mi pareja pagó 100 y su parte es 40 → yo le debo 60.
    final e = SharedEntry(total: 100, authorPart: 40, paidByAuthor: true, byMe: false);
    expect(e.myBalance, -60);
    // Mi pareja anotó que yo pagué (paidByAuthor false) y su parte es 40 → ella me debe 40.
    final f = SharedEntry(total: 100, authorPart: 40, paidByAuthor: false, byMe: false);
    expect(f.myBalance, 40);
  });

  test('sin gastos el saldo es 0 y se redondea a 2 decimales', () {
    expect(coupleNetBalance(const []), 0);
    expect(coupleNetBalance(const [SharedEntry(total: 10, authorPart: 3.333, paidByAuthor: true)]), 6.67);
  });
}
