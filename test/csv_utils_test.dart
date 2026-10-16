import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/utils/csv_utils.dart';

void main() {
  group('parseCsv', () {
    test('separa filas y celdas con comillas', () {
      final rows = parseCsv('a,b,c\n1,"hola, mundo",3\n');
      expect(rows.length, 2);
      expect(rows[1], ['1', 'hola, mundo', '3']);
    });

    test('detecta punto y coma y quita el BOM', () {
      final rows = parseCsv('\uFEFFfecha;monto\n2026-01-01;10,5\n');
      expect(rows.first, ['fecha', 'monto']);
      expect(rows[1], ['2026-01-01', '10,5']);
    });

    test('comillas escapadas', () {
      final rows = parseCsv('x\n"di ""hola"""\n');
      expect(rows[1], ['di "hola"']);
    });
  });

  group('parseFlexibleAmount', () {
    test('formatos comunes', () {
      expect(parseFlexibleAmount('1.234,56'), 1234.56);
      expect(parseFlexibleAmount('1,234.56'), 1234.56);
      expect(parseFlexibleAmount('12,50'), 12.5);
      expect(parseFlexibleAmount(r'$ 45'), 45);
      expect(parseFlexibleAmount('-45.5'), -45.5);
    });

    test('texto inválido devuelve null', () {
      expect(parseFlexibleAmount('abc'), isNull);
      expect(parseFlexibleAmount(''), isNull);
    });
  });

  group('parseFlexibleDate', () {
    test('ISO y dd/MM/yyyy', () {
      expect(parseFlexibleDate('2026-10-16')!.day, 16);
      final d = parseFlexibleDate('05/03/2026')!;
      expect([d.day, d.month, d.year], [5, 3, 2026]);
    });

    test('fecha inválida devuelve null', () {
      expect(parseFlexibleDate('no es fecha'), isNull);
    });
  });

  group('parseExpensesCsv', () {
    test('lee el CSV que exporta la app', () {
      const csv = 'date,name,category,amount,currency\n'
          '2026-10-01T09:00:00.000,Café,comida,3.50,USD\n'
          '2026-10-02T09:00:00.000,"Cena, amigos",otros,20.00,EUR\n'
          '2026-10-03T09:00:00.000,,comida,5.00,USD\n';
      final result = parseExpensesCsv(
        csv,
        defaultCurrency: 'USD',
        knownCategories: const ['compras', 'servicios', 'comida', 'otros'],
        supportedCurrencies: const {'USD', 'EUR'},
      );
      expect(result.headerRecognized, isTrue);
      expect(result.expenses.length, 2);
      expect(result.skipped, 1);
      expect(result.expenses[1].name, 'Cena, amigos');
      expect(result.expenses[1].currency, 'EUR');
    });

    test('sin cabecera reconocible no importa nada', () {
      final result = parseExpensesCsv(
        'uno,dos\n1,2\n',
        defaultCurrency: 'USD',
        knownCategories: const ['otros'],
        supportedCurrencies: const {'USD'},
      );
      expect(result.headerRecognized, isFalse);
      expect(result.expenses, isEmpty);
    });
  });
}
