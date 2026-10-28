import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/utils/xlsx_reader.dart';
import 'package:expense_tracker/utils/xlsx_writer.dart';

void main() {
  test('lo que se escribe se vuelve a leer igual (texto, números, acentos y símbolos)', () {
    final bytes = buildXlsx([
      ['Fecha', 'Nombre', 'Monto', 'Moneda'],
      ['2026-10-16', 'Café & Té <ñandú> "uno"', 12.5, 'USD'],
      ['2026-10-17', 'Súper', 1234, 'PEN'],
    ], sheetName: 'Gastos');
    final rows = readXlsxRows(bytes);
    expect(rows.length, 3);
    expect(rows[0], ['Fecha', 'Nombre', 'Monto', 'Moneda']);
    expect(rows[1][1], 'Café & Té <ñandú> "uno"');
    expect(double.parse(rows[1][2]), 12.5);
    expect(double.parse(rows[2][2]), 1234);
    expect(rows[2][3], 'PEN');
  });

  test('celdas vacías (null) conservan la posición de las columnas', () {
    final rows = readXlsxRows(buildXlsx([
      ['A', 'B', 'C'],
      ['x', null, 'z'],
    ]));
    expect(rows[1], ['x', '', 'z']);
  });

  test('más de 26 columnas', () {
    final row = List<Object?>.generate(30, (i) => 'c$i');
    final rows = readXlsxRows(buildXlsx([row]));
    expect(rows.first.length, 30);
    expect(rows.first.last, 'c29');
  });
}
