import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/utils/csv_utils.dart';
import 'package:expense_tracker/utils/xlsx_reader.dart';

// Hoja de Excel de ejemplo (.xlsx real) codificada en base64.
const String _sampleXlsxBase64 =
    'UEsDBBQAAAAIALmFUV3muHRrXAAAAGIAAAATAAAAW0NvbnRlbnRfVHlwZXNdLnhtbBXMTQqAIBBA'
    '4auE+xxr0SJKL9EFRKYfylGcIer22fLxwZvcE6/mxsJHoll12ihnp+XNyE0V4lntInkE4LBj9KxT'
    'RqqyphK91CwbZB9OvyH0xgwQEgmStPI/FNgPUEsDBBQAAAAIALmFUV2gO5PKnwAAAPgAAAAPAAAA'
    'eGwvd29ya2Jvb2sueG1sjY87EoMwDESv4tEBYkiRgjHQpAjHcEDEDtjySM7n+PGQ0KfSard4u6Z/'
    'h1U9kcVTbKE+VNB35kW8XIkWVcIoLbicU6O1jA6DlQMljCWZiYPN5eWblsRoJ3GIOaz6WFUnHayP'
    '0JnNk99V0QZs4UJ3W4ParGEqWFDc+CJ4mIreqA3/w6V59iOeaXwEjPkLZlxtLnPE+SSgO6P3Dnof'
    '1n0AUEsDBBQAAAAIALmFUV2MbvSnHAEAAMECAAAYAAAAeGwvd29ya3NoZWV0cy9zaGVldDEueG1s'
    'dZLbboMgGIDv9xSE+4mCs6ZBmnV1D7C1D0Asq2SKBojt449qp0jSO36+//BxoLtb24BBaCM7VcAk'
    'iiEQqurOUl0KeDp+vuZwx+i107+mFsICl65MAWtr+y1CpqpFy03U9UI58tPpllsX6gsyvRb8PBa1'
    'DcJxnKGWSwUZHfcO3HL2QnV3BdrNddvVffGeQGALaFw8sJiigVFUPdjeZ8maffgMr9nBZ2TNSp+l'
    'M0POa7HDsx2GwEy2LjuLySYwxF63t8DQZ1lgiCe3KKgp/ZrNEzsy25HALg/77cnYT6pGKvFttcuU'
    'hlHLjvwmKbIu9R4vXmS6a/xkdDqPTiH6n5F6znlwznR6nzjC4UkfVaPTwMrTVzgSLd+Govk/sj9Q'
    'SwMEFAAAAAgAuYVRXY7RJcrPAAAAZgEAABQAAAB4bC9zaGFyZWRTdHJpbmdzLnhtbG2QTU4DMQxG'
    'rxJlwY5mygLxk0kXg7qDDfQAJuPORJrYQ+KpeiUWnKIXI1WFkAhLPz/7s2w3xzipA6YcmFq9XjVa'
    'IXnuAw2t3r1tr+/0xtmcRRWRcqtHkfnBmOxHjJBXPCOVzp5TBCllGkyeE0KfR0SJk7lpmlsTIZBW'
    'nheSVt9rtVD4WLD7qUtAcFbcFv0I1oiz5gwu8IXje8K/tAPBgdPpq/KfmYT/gdhXagf702c5i9RU'
    'kqsMzzHUQ7vXp2oPEqgriPOjghgGzr+CKa9z31BLAQIUAxQAAAAIALmFUV3muHRrXAAAAGIAAAAT'
    'AAAAAAAAAAAAAACAAQAAAABbQ29udGVudF9UeXBlc10ueG1sUEsBAhQDFAAAAAgAuYVRXaA7k8qf'
    'AAAA+AAAAA8AAAAAAAAAAAAAAIABjQAAAHhsL3dvcmtib29rLnhtbFBLAQIUAxQAAAAIALmFUV2M'
    'bvSnHAEAAMECAAAYAAAAAAAAAAAAAACAAVkBAAB4bC93b3Jrc2hlZXRzL3NoZWV0MS54bWxQSwEC'
    'FAMUAAAACAC5hVFdjtElys8AAABmAQAAFAAAAAAAAAAAAAAAgAGrAgAAeGwvc2hhcmVkU3RyaW5n'
    'cy54bWxQSwUGAAAAAAQABAAGAQAArAMAAAAA';

void main() {
  test('lee la primera hoja de un .xlsx (textos compartidos, inline y números)', () {
    final rows = readXlsxRows(base64Decode(_sampleXlsxBase64));
    expect(rows.length, 4);
    expect(rows[0], ['Fecha', 'Nombre', 'Categoría', 'Monto', 'Moneda']);
    expect(rows[1], ['46037', 'Café con leche', 'comida', '3.5', 'USD']);
    expect(rows[2][1], 'Taxi');
    expect(rows[3][1], 'Cena & amigos');
    expect(rows[3][4], 'EUR');
  });

  test('un .xlsx se convierte en gastos (con fechas de serie de Excel)', () {
    final rows = readXlsxRows(base64Decode(_sampleXlsxBase64));
    final result = parseExpensesRows(
      rows,
      defaultCurrency: 'PEN',
      knownCategories: const ['compras', 'servicios', 'comida', 'otros'],
      supportedCurrencies: const {'USD', 'EUR', 'PEN'},
    );
    expect(result.headerRecognized, isTrue);
    expect(result.expenses.length, 3);
    expect(result.expenses[0].name, 'Café con leche');
    expect(result.expenses[0].category, 'comida');
    expect(result.expenses[0].currency, 'USD');
    expect(result.expenses[0].amount, 3.5);
    expect(
      [result.expenses[0].date.year, result.expenses[0].date.month, result.expenses[0].date.day],
      [2026, 1, 15],
    );
    // Sin moneda en la fila: usa la moneda por defecto.
    expect(result.expenses[1].currency, 'PEN');
    expect(result.expenses[2].currency, 'EUR');
  });

  test('un archivo que no es .xlsx lanza un error claro', () {
    final Uint8List notZip = Uint8List.fromList(
      utf8.encode('esto no es un archivo zip, solo texto plano de relleno para superar el tamaño mínimo'),
    );
    expect(() => readXlsxRows(notZip), throwsA(isA<XlsxFormatException>()));
  });
}
