import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/utils/expense_filter.dart';

Expense _e(String id, String name, double amount, DateTime date,
        {String category = 'comida', String? note, List<String>? tags, String? account, String currency = 'USD', double? shared, String? credit}) =>
    Expense(
      id: id,
      name: name,
      amount: amount,
      currency: currency,
      category: category,
      date: date,
      note: note,
      tags: tags,
      accountId: account,
      sharedTotal: shared,
      creditId: credit,
    );

double _value(Expense e) => e.currency == 'USD' ? e.amount : e.amount * 0.25;
String _label(String c) => {'comida': 'Comida', 'servicios': 'Servicios', 'compras': 'Compras'}[c] ?? c;

void main() {
  final all = [
    _e('1', 'Uber al aeropuerto', 16.94, DateTime(2026, 10, 8, 10), category: 'servicios', tags: ['viaje']),
    _e('2', 'Supermercado', 45.90, DateTime(2026, 10, 15, 18), note: 'compra del mes'),
    _e('3', 'Cena con Ana', 30.0, DateTime(2026, 11, 2, 21), shared: 60.0, tags: ['pareja']),
    _e('4', 'Laptop (1/6)', 214.23, DateTime(2026, 11, 3, 9), category: 'compras', credit: 'c1'),
    _e('5', 'Café', 2.5, DateTime(2026, 11, 3, 8), account: 'a1'),
    _e('6', 'Pan', 40.0, DateTime(2026, 11, 4, 8), currency: 'BRL'),
  ];
  List<String> ids(ExpenseFilter f) =>
      f.apply(all, valueOf: _value, categoryLabel: _label).map((e) => e.id).toList();

  test('sin filtros devuelve todo, más recientes primero', () {
    expect(ids(const ExpenseFilter()), ['6', '4', '5', '3', '2', '1']);
    expect(const ExpenseFilter().isActive, isFalse);
  });

  group('texto', () {
    test('busca en nombre, nota, categoría, etiqueta y monto', () {
      expect(ids(const ExpenseFilter(query: 'uber')), ['1']);
      expect(ids(const ExpenseFilter(query: 'compra del')), ['2']);
      expect(ids(const ExpenseFilter(query: 'servicios')), ['1']);
      expect(ids(const ExpenseFilter(query: '#pareja')), ['3']);
      expect(ids(const ExpenseFilter(query: '45.90')), ['2']);
      expect(ids(const ExpenseFilter(query: '45,90')), ['2']);
    });
    test('todas las palabras deben aparecer, sin importar mayúsculas', () {
      expect(ids(const ExpenseFilter(query: 'CENA ana')), ['3']);
      expect(ids(const ExpenseFilter(query: 'cena uber')), isEmpty);
    });
  });

  group('filtros', () {
    test('categorías (varias)', () {
      expect(ids(const ExpenseFilter(categories: {'servicios', 'compras'})), ['4', '1']);
    });
    test('etiquetas', () {
      expect(ids(const ExpenseFilter(tags: {'viaje', 'pareja'})), ['3', '1']);
    });
    test('fechas inclusivas', () {
      expect(ids(ExpenseFilter(from: DateTime(2026, 11, 3), to: DateTime(2026, 11, 3))), ['4', '5']);
    });
    test('cuenta y moneda', () {
      expect(ids(const ExpenseFilter(accountId: 'a1')), ['5']);
      expect(ids(const ExpenseFilter(currency: 'BRL')), ['6']);
    });
    test('monto en moneda local', () {
      // BRL 40 * 0.25 = 10 en moneda local
      expect(ids(const ExpenseFilter(minAmount: 9, maxAmount: 20)), ['6', '1']);
      expect(ids(const ExpenseFilter(minAmount: 100)), ['4']);
    });
    test('tipo de gasto', () {
      expect(ids(const ExpenseFilter(kind: ExpenseKindFilter.couple)), ['3']);
      expect(ids(const ExpenseFilter(kind: ExpenseKindFilter.credit)), ['4']);
      expect(ids(const ExpenseFilter(kind: ExpenseKindFilter.personal)), ['6', '5', '2', '1']);
    });
    test('filtros combinados y conteo', () {
      final f = ExpenseFilter(categories: const {'comida'}, from: DateTime(2026, 11, 1), kind: ExpenseKindFilter.personal);
      expect(ids(f), ['6', '5']);
      expect(f.activeCount, 3);
      expect(f.isActive, isTrue);
    });
  });

  group('orden', () {
    test('por monto y por antigüedad', () {
      expect(ids(const ExpenseFilter(sort: ExpenseSort.amountDesc)), ['4', '2', '3', '1', '6', '5']);
      expect(ids(const ExpenseFilter(sort: ExpenseSort.amountAsc)).first, '5');
      expect(ids(const ExpenseFilter(sort: ExpenseSort.oldest)).first, '1');
    });
  });

  group('periodos rápidos', () {
    final now = DateTime(2026, 11, 4, 15); // miércoles
    test('hoy, semana, mes, mes pasado, año', () {
      expect(periodRange('today', now), (from: DateTime(2026, 11, 4), to: DateTime(2026, 11, 4)));
      expect(periodRange('week', now), (from: DateTime(2026, 11, 2), to: DateTime(2026, 11, 8)));
      expect(periodRange('month', now), (from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 30)));
      expect(periodRange('lastMonth', now), (from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 31)));
      expect(periodRange('year', now), (from: DateTime(2026, 1, 1), to: DateTime(2026, 12, 31)));
    });
    test('reconoce el periodo activo', () {
      expect(matchingPeriod(DateTime(2026, 11, 1), DateTime(2026, 11, 30), now), 'month');
      expect(matchingPeriod(DateTime(2026, 10, 5), DateTime(2026, 11, 9), now), isNull);
      expect(matchingPeriod(null, null, now), isNull);
    });
  });
}
