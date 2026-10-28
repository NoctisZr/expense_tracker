import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/utils/sms_parser.dart';

const Set<String> _supported = {'USD', 'PEN', 'EUR', 'BRL', 'MXN', 'COP', 'GBP'};

BankMessageData _parse(String text, {String local = 'PEN'}) =>
    parseBankMessage(text, defaultCurrency: local, supportedCurrencies: _supported);

void main() {
  test('compra en soles con comercio, fecha, hora y tarjeta', () {
    final d = _parse('BCP: Compra aprobada por S/ 45.90 en TOTTUS el 16/10/2026 14:35. Tarjeta terminada en 4821.');
    expect(d.amount, 45.90);
    expect(d.currency, 'PEN');
    expect(d.merchant, 'Tottus');
    expect(d.date, isNotNull);
    expect(d.date!.month, 10);
    expect(d.date!.day, 16);
    expect(d.isIncome, isFalse);
  });

  test('inglés con signo \$ y moneda local USD', () {
    final d = _parse('Chase: You spent \$23.45 at STARBUCKS on 10/16/2026', local: 'USD');
    expect(d.amount, 23.45);
    expect(d.currency, 'USD');
    expect(d.merchant, 'Starbucks');
    expect(d.isIncome, isFalse);
  });

  test('portugués con R\$ y coma decimal', () {
    final d = _parse('Pagaste R\$ 30,00 em PADARIA SOL', local: 'BRL');
    expect(d.amount, 30.0);
    expect(d.currency, 'BRL');
    expect(d.merchant, 'Padaria Sol');
  });

  test('código de moneda después del número', () {
    final d = _parse('Consumo 12.50 USD en AMAZON');
    expect(d.amount, 12.5);
    expect(d.currency, 'USD');
    expect(d.merchant, 'Amazon');
  });

  test('ignora el saldo disponible', () {
    final d = _parse('Compra por S/ 45.90 en TOTTUS. Saldo disponible S/ 1,200.00');
    expect(d.amount, 45.90);
  });

  test('depósito se reconoce como ingreso', () {
    final d = _parse('Recibiste un depósito de S/ 1,500.00 en tu cuenta. Saldo: S/ 2,300.00');
    expect(d.isIncome, isTrue);
    expect(d.amount, 1500.0);
    expect(d.currency, 'PEN');
  });

  test('"en tu cuenta" no se toma como comercio', () {
    final d = _parse('Recibiste S/ 200.00 en tu cuenta');
    expect(d.merchant, isNull);
  });

  test('texto sin importe', () {
    final d = _parse('Hola, tu código es 123456');
    expect(d.amount, isNull);
  });
}
