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

  test('varios gráficos: el principal y los extra se dibujan con sus colores', () {
    final text = latin1.decode(buildSimplePdf(
      title: 'Con gráficos',
      lines: ['Una línea'],
      barsTitle: 'Por categoría',
      bars: [const MapEntry('Comida', 120.0), const MapEntry('Compras', 80.0)],
      extraCharts: [
        const PdfChart(
          title: 'Evolución',
          bars: [MapEntry('09/2026', 50.0), MapEntry('10/2026', 90.0)],
          rgb: [0.25, 0.45, 0.85],
        ),
      ],
    ));
    expect(text.contains('(Por categoria)') || text.contains('Por categor'), isTrue);
    expect(text.contains('Evoluci'), isTrue);
    expect(text.contains('0.25 0.45 0.85 rg'), isTrue);
    expect(text.contains('0.15 0.65 0.55 rg'), isTrue);
    expect(text.trimRight().endsWith('%%EOF'), isTrue);
  });

  test('con muchas líneas crea varias páginas', () {
    final lines = [for (int i = 0; i < 160; i++) 'Línea número $i'];
    final text = latin1.decode(buildSimplePdf(title: 'Largo', lines: lines));
    final pages = RegExp(r'/Type /Page ').allMatches(text).length;
    expect(pages, greaterThan(1));
  });
}
