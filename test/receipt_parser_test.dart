import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/utils/receipt_parser.dart';

const Set<String> _currencies = {'USD', 'EUR', 'PEN', 'BRL', 'MXN'};

void main() {
  test('ticket de restaurante: comercio, total, fecha, moneda y categoría', () {
    const text = 'Restaurante El Buen Sabor\n'
        'RUC 20123456789\n'
        'Fecha: 16/10/2026\n'
        'Ceviche mixto   S/ 38.00\n'
        'Chicha morada   S/ 12.00\n'
        'Subtotal  S/ 42.37\n'
        'IGV 18%   S/ 7.63\n'
        'TOTAL     S/ 50.00\n';
    final data = parseReceiptText(text, defaultCurrency: 'PEN', supportedCurrencies: _currencies);
    expect(data.merchant, 'Restaurante El Buen Sabor');
    expect(data.total, 50.0);
    expect(data.currency, 'PEN');
    expect(data.categoryGuess, 'comida');
    expect([data.date!.year, data.date!.month, data.date!.day], [2026, 10, 16]);
  });

  test('el total puede estar en la línea siguiente y con formato europeo', () {
    const text = 'SUPERMERCADO CENTRAL\n'
        '03.02.2026\n'
        'Leche 1,20\n'
        'Total a pagar\n'
        '1.234,56 EUR\n';
    final data = parseReceiptText(text, defaultCurrency: 'USD', supportedCurrencies: _currencies);
    expect(data.total, 1234.56);
    expect(data.currency, 'EUR');
    expect([data.date!.year, data.date!.month, data.date!.day], [2026, 2, 3]);
  });

  test('fecha con mes escrito', () {
    const text = 'Tienda Demo\n16 de octubre de 2026\nTotal 10.00\n';
    final data = parseReceiptText(text, defaultCurrency: 'USD', supportedCurrencies: _currencies);
    expect([data.date!.year, data.date!.month, data.date!.day], [2026, 10, 16]);
    expect(data.total, 10.0);
  });

  test('sin palabra "total" usa el importe más grande', () {
    const text = 'Kiosco\nAgua 2.50\nGalletas 8.90\n';
    final data = parseReceiptText(text, defaultCurrency: 'USD', supportedCurrencies: _currencies);
    expect(data.total, 8.9);
  });

  test('texto vacío no rompe nada', () {
    final data = parseReceiptText('', defaultCurrency: 'USD', supportedCurrencies: _currencies);
    expect(data.total, isNull);
    expect(data.merchant, isNull);
    expect(data.date, isNull);
  });
}
