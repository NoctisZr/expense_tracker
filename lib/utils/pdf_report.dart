import 'dart:convert';
import 'dart:typed_data';

/// Un gráfico de barras horizontales del PDF.
class PdfChart {
  final String title;
  final List<MapEntry<String, double>> bars;

  /// Color de las barras (RGB de 0 a 1).
  final List<double> rgb;

  const PdfChart({required this.title, required this.bars, this.rgb = const [0.15, 0.65, 0.55]});
}

/// Generador mínimo de PDF (Helvetica, A4) escrito sin paquetes externos:
/// título, un gráfico de barras horizontales opcional y líneas de texto.
/// Admite caracteres Latin-1 (acentos y ñ); el resto se sustituye por "?".
Uint8List buildSimplePdf({
  required String title,
  required List<String> lines,
  String? barsTitle,
  List<MapEntry<String, double>>? bars,
  List<PdfChart>? extraCharts,
}) {
  const double pageWidth = 595;
  const double pageHeight = 842;
  const double margin = 50;
  const double leading = 14;
  const int maxChars = 92;

  String clean(String s) {
    final StringBuffer b = StringBuffer();
    for (final unit in s.runes) {
      if (unit == 0x2248) {
        b.write('~');
      } else if (unit < 32) {
        b.write(' ');
      } else if (unit < 256) {
        b.writeCharCode(unit);
      } else {
        b.write('?');
      }
    }
    return b.toString();
  }

  String escape(String s) => s.replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');
  String n2(double v) => v.toStringAsFixed(2);

  // Ajuste de líneas largas.
  final List<String> wrapped = [];
  for (final raw in lines) {
    final String line = clean(raw);
    if (line.length <= maxChars) {
      wrapped.add(line);
      continue;
    }
    String rest = line;
    while (rest.length > maxChars) {
      int cut = rest.lastIndexOf(' ', maxChars);
      if (cut <= 0) cut = maxChars;
      wrapped.add(rest.substring(0, cut));
      rest = '  ${rest.substring(cut).trimLeft()}';
    }
    wrapped.add(rest);
  }

  // Gráficos: el principal (por categoría) y los extra (evolución, comparativas...).
  final List<PdfChart> charts = [];
  final List<MapEntry<String, double>> mainBars =
      (bars ?? const <MapEntry<String, double>>[]).where((e) => e.value > 0).take(10).toList();
  if (mainBars.isNotEmpty) charts.add(PdfChart(title: barsTitle ?? '', bars: mainBars));
  for (final c in extraCharts ?? const <PdfChart>[]) {
    final List<MapEntry<String, double>> b = c.bars.where((e) => e.value > 0).take(10).toList();
    if (b.isNotEmpty) charts.add(PdfChart(title: c.title, bars: b, rgb: c.rgb));
  }
  double chartHeight = 0;
  for (final c in charts) {
    chartHeight += 20 + c.bars.length * 15 + 10;
  }

  // Capacidad de líneas: la primera página pierde el espacio del gráfico.
  final int fullCapacity = ((pageHeight - 2 * margin - 30) / leading).floor();
  int firstCapacity = ((pageHeight - 2 * margin - 30 - chartHeight) / leading).floor();
  if (firstCapacity < 4) firstCapacity = 4;

  final List<List<String>> pages = [];
  int cursor = 0;
  while (cursor < wrapped.length || pages.isEmpty) {
    final int capacity = pages.isEmpty ? firstCapacity : fullCapacity;
    final int end = cursor + capacity > wrapped.length ? wrapped.length : cursor + capacity;
    pages.add(wrapped.sublist(cursor, end));
    cursor = end;
    if (cursor >= wrapped.length) break;
  }

  final List<List<int>> objects = [];
  List<int> bytes(String s) => latin1.encode(s);

  const int firstPageObj = 4;
  final List<String> kids = [for (int i = 0; i < pages.length; i++) '${firstPageObj + i * 2} 0 R'];

  objects.add(bytes('<< /Type /Catalog /Pages 2 0 R >>'));
  objects.add(bytes('<< /Type /Pages /Kids [${kids.join(' ')}] /Count ${pages.length} >>'));
  objects.add(bytes('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>'));

  for (int p = 0; p < pages.length; p++) {
    final int contentObj = firstPageObj + p * 2 + 1;
    objects.add(bytes(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $pageWidth $pageHeight] '
      '/Resources << /Font << /F1 3 0 R >> >> /Contents $contentObj 0 R >>',
    ));

    final StringBuffer content = StringBuffer();
    double y = pageHeight - margin;

    if (p == 0) {
      content.write('BT\n/F1 16 Tf\n${n2(margin)} ${n2(y)} Td\n(${escape(clean(title))}) Tj\nET\n');
      y -= 30;

      for (final chart in charts) {
        if (chart.title.isNotEmpty) {
          content.write('BT\n/F1 11 Tf\n${n2(margin)} ${n2(y)} Td\n(${escape(clean(chart.title))}) Tj\nET\n');
        }
        y -= 20;
        final double maxValue = chart.bars.map((e) => e.value).reduce((a, b) => a > b ? a : b);
        const double labelWidth = 150;
        const double maxBarWidth = 250;
        final String color = '${n2(chart.rgb[0])} ${n2(chart.rgb[1])} ${n2(chart.rgb[2])}';
        for (final bar in chart.bars) {
          final double width = (bar.value / maxValue * maxBarWidth).clamp(2.0, maxBarWidth).toDouble();
          String label = clean(bar.key);
          if (label.length > 26) label = '${label.substring(0, 25)}.';
          content.write('BT\n/F1 9 Tf\n${n2(margin)} ${n2(y)} Td\n(${escape(label)}) Tj\nET\n');
          content.write('q\n$color rg\n${n2(margin + labelWidth)} ${n2(y - 2)} ${n2(width)} 9 re f\nQ\n');
          content.write(
            'BT\n/F1 8 Tf\n${n2(margin + labelWidth + width + 6)} ${n2(y)} Td\n(${escape(bar.value.toStringAsFixed(0))}) Tj\nET\n',
          );
          y -= 15;
        }
        y -= 10;
      }
    }

    content.write('BT\n/F1 10 Tf\n${n2(leading)} TL\n${n2(margin)} ${n2(y)} Td\n');
    for (final line in pages[p]) {
      content.write('(${escape(line)}) Tj T*\n');
    }
    content.write('ET');

    final List<int> stream = bytes(content.toString());
    objects.add([
      ...bytes('<< /Length ${stream.length} >>\nstream\n'),
      ...stream,
      ...bytes('\nendstream'),
    ]);
  }

  final BytesBuilder out = BytesBuilder();
  final List<int> offsets = [];
  out.add(bytes('%PDF-1.4\n'));
  for (int i = 0; i < objects.length; i++) {
    offsets.add(out.length);
    out.add(bytes('${i + 1} 0 obj\n'));
    out.add(objects[i]);
    out.add(bytes('\nendobj\n'));
  }
  final int xrefOffset = out.length;
  out.add(bytes('xref\n0 ${objects.length + 1}\n'));
  out.add(bytes('0000000000 65535 f \n'));
  for (final off in offsets) {
    out.add(bytes('${off.toString().padLeft(10, '0')} 00000 n \n'));
  }
  out.add(bytes('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF\n'));
  return out.toBytes();
}
