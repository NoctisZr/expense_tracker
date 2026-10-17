import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/utils/pdf_report.dart';

void main() {
  test('genera un PDF válido con cabecera, xref y fin de archivo', () {
    final bytes = buildSimplePdf(
      title: 'Reporte de gastos 10/2026',
      lines: ['Ingresos: 1000.00 USD', 'Café (acentos) ñandú', 'línea con (paréntesis) y \\ barra'],
    );
    final text = latin1.decode(bytes);
    expect(text.startsWith('%PDF-1.4'), isTrue);
    expect(text.trimRight().endsWith('%%EOF'), isTrue);
    expect(text.contains('xref'), isTrue);
    expect(text.contains('/Type /Catalog'), isTrue);
  });

  test('con muchas líneas crea varias páginas', () {
    final lines = [for (int i = 0; i < 160; i++) 'Línea número $i'];
    final text = latin1.decode(buildSimplePdf(title: 'Largo', lines: lines));
    final pages = RegExp(r'/Type /Page ').allMatches(text).length;
    expect(pages, greaterThan(1));
  });
}
