import 'dart:convert';
import 'dart:typed_data';

/// Generador mínimo de PDF de solo texto (Helvetica, A4), escrito sin
/// paquetes externos. Admite caracteres Latin-1 (acentos y ñ); el resto se
/// sustituye por "?".
Uint8List buildSimplePdf({required String title, required List<String> lines}) {
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

  final int linesPerPage = ((pageHeight - 2 * margin - 30) / leading).floor();
  final List<List<String>> pages = [];
  for (int i = 0; i < wrapped.length; i += linesPerPage) {
    pages.add(wrapped.sublist(i, i + linesPerPage > wrapped.length ? wrapped.length : i + linesPerPage));
  }
  if (pages.isEmpty) pages.add(<String>[]);

  // Objetos: 1 catálogo, 2 páginas, 3 fuente, luego (página, contenido) por página.
  final List<List<int>> objects = [];
  List<int> bytes(String s) => latin1.encode(s);

  final int firstPageObj = 4;
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

    final StringBuffer content = StringBuffer('BT\n');
    double y = pageHeight - margin;
    if (p == 0) {
      content.write('/F1 16 Tf\n$margin $y Td\n(${escape(clean(title))}) Tj\n');
      y = -26; // desplazamiento relativo bajo el título
      content.write('/F1 10 Tf\n$leading TL\n0 $y Td\n');
    } else {
      content.write('/F1 10 Tf\n$leading TL\n$margin $y Td\n');
    }
    for (final line in pages[p]) {
      content.write('(${escape(line)}) Tj T*\n');
    }
    content.write('ET');
    final List<int> stream = bytes(content.toString());
    final List<int> obj = [
      ...bytes('<< /Length ${stream.length} >>\nstream\n'),
      ...stream,
      ...bytes('\nendstream'),
    ];
    objects.add(obj);
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
