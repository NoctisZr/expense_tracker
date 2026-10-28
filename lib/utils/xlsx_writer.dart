import 'dart:convert';
import 'dart:typed_data';

/// Escritor mínimo de archivos Excel .xlsx con la librería estándar de Dart
/// (sin paquetes externos). Genera un ZIP "sin comprimir" con una sola hoja:
/// números como números y el resto como texto. Lo abren Excel, Google Sheets
/// y LibreOffice, y también lo lee `readXlsxRows`.

final List<int> _crcTable = () {
  final List<int> table = List<int>.filled(256, 0);
  for (int n = 0; n < 256; n++) {
    int c = n;
    for (int k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
    }
    table[n] = c;
  }
  return table;
}();

int _crc32(List<int> data) {
  int c = 0xFFFFFFFF;
  for (final int b in data) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

void _w16(BytesBuilder out, int v) {
  out.addByte(v & 0xFF);
  out.addByte((v >> 8) & 0xFF);
}

void _w32(BytesBuilder out, int v) {
  out.addByte(v & 0xFF);
  out.addByte((v >> 8) & 0xFF);
  out.addByte((v >> 16) & 0xFF);
  out.addByte((v >> 24) & 0xFF);
}

String _escapeXml(String s) {
  final StringBuffer b = StringBuffer();
  for (final int unit in s.runes) {
    // Se descartan los caracteres de control que XML no admite.
    if (unit < 0x20 && unit != 0x09 && unit != 0x0A && unit != 0x0D) continue;
    switch (unit) {
      case 0x26:
        b.write('&amp;');
        break;
      case 0x3C:
        b.write('&lt;');
        break;
      case 0x3E:
        b.write('&gt;');
        break;
      case 0x22:
        b.write('&quot;');
        break;
      default:
        b.writeCharCode(unit);
    }
  }
  return b.toString();
}

String _columnLetters(int index) {
  int n = index + 1;
  String result = '';
  while (n > 0) {
    final int rem = (n - 1) % 26;
    result = String.fromCharCode(65 + rem) + result;
    n = (n - 1) ~/ 26;
  }
  return result;
}

String _sheetXml(List<List<Object?>> rows) {
  final StringBuffer b = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
  );
  for (int r = 0; r < rows.length; r++) {
    b.write('<row r="${r + 1}">');
    for (int c = 0; c < rows[r].length; c++) {
      final Object? value = rows[r][c];
      if (value == null) continue;
      final String ref = '${_columnLetters(c)}${r + 1}';
      if (value is num && value.isFinite) {
        b.write('<c r="$ref"><v>$value</v></c>');
      } else {
        b.write('<c r="$ref" t="inlineStr"><is><t xml:space="preserve">${_escapeXml(value.toString())}</t></is></c>');
      }
    }
    b.write('</row>');
  }
  b.write('</sheetData></worksheet>');
  return b.toString();
}

/// Construye un .xlsx con [rows] en una sola hoja llamada [sheetName].
Uint8List buildXlsx(List<List<Object?>> rows, {String sheetName = 'Sheet1'}) {
  String safeName = sheetName.replaceAll(RegExp(r'[\[\]\*\?/\\:]'), ' ').trim();
  if (safeName.isEmpty) safeName = 'Sheet1';
  if (safeName.length > 31) safeName = safeName.substring(0, 31);

  final Map<String, String> files = {
    '[Content_Types].xml':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            '<Default Extension="xml" ContentType="application/xml"/>'
            '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
            '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
            '</Types>',
    '_rels/.rels':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
            '</Relationships>',
    'xl/workbook.xml':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            '<sheets><sheet name="${_escapeXml(safeName)}" sheetId="1" r:id="rId1"/></sheets></workbook>',
    'xl/_rels/workbook.xml.rels':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
            '</Relationships>',
    'xl/worksheets/sheet1.xml': _sheetXml(rows),
  };

  final BytesBuilder out = BytesBuilder();
  final BytesBuilder central = BytesBuilder();
  int entries = 0;

  files.forEach((String name, String content) {
    final List<int> nameBytes = utf8.encode(name);
    final List<int> data = utf8.encode(content);
    final int crc = _crc32(data);
    final int offset = out.length;

    // Cabecera local + datos (método 0 = sin comprimir).
    _w32(out, 0x04034b50);
    _w16(out, 20);
    _w16(out, 0x0800);
    _w16(out, 0);
    _w16(out, 0);
    _w16(out, 0x21);
    _w32(out, crc);
    _w32(out, data.length);
    _w32(out, data.length);
    _w16(out, nameBytes.length);
    _w16(out, 0);
    out.add(nameBytes);
    out.add(data);

    // Entrada del directorio central.
    _w32(central, 0x02014b50);
    _w16(central, 20);
    _w16(central, 20);
    _w16(central, 0x0800);
    _w16(central, 0);
    _w16(central, 0);
    _w16(central, 0x21);
    _w32(central, crc);
    _w32(central, data.length);
    _w32(central, data.length);
    _w16(central, nameBytes.length);
    _w16(central, 0);
    _w16(central, 0);
    _w16(central, 0);
    _w16(central, 0);
    _w32(central, 0);
    _w32(central, offset);
    central.add(nameBytes);
    entries++;
  });

  final int centralOffset = out.length;
  final Uint8List centralBytes = central.toBytes();
  out.add(centralBytes);

  // Fin del directorio central.
  _w32(out, 0x06054b50);
  _w16(out, 0);
  _w16(out, 0);
  _w16(out, entries);
  _w16(out, entries);
  _w32(out, centralBytes.length);
  _w32(out, centralOffset);
  _w16(out, 0);
  return out.toBytes();
}
