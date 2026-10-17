import 'dart:convert';
import 'dart:io' show ZLibCodec;
import 'dart:typed_data';

/// Lector mínimo de archivos Excel .xlsx escrito solo con la librería
/// estándar de Dart (sin paquetes externos, para no añadir riesgo al
/// build). Un .xlsx es un ZIP con XML dentro: aquí se lee la primera hoja y
/// se devuelve como filas de texto. No admite el formato antiguo .xls.
class XlsxFormatException implements Exception {
  final String message;
  const XlsxFormatException(this.message);
  @override
  String toString() => message;
}

int _u16(Uint8List b, int o) => b[o] | (b[o + 1] << 8);
int _u32(Uint8List b, int o) => b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

/// Extrae del ZIP el archivo [name] (descomprimido) o `null` si no existe.
Uint8List? _readZipEntry(Uint8List zip, String name) {
  // Fin del directorio central (EOCD): se busca desde el final hacia atrás.
  int eocd = -1;
  final int minPos = zip.length - 22 - 65535 < 0 ? 0 : zip.length - 22 - 65535;
  for (int i = zip.length - 22; i >= minPos; i--) {
    if (_u32(zip, i) == 0x06054b50) {
      eocd = i;
      break;
    }
  }
  if (eocd == -1) throw const XlsxFormatException('El archivo no es un .xlsx válido.');

  final int entries = _u16(zip, eocd + 10);
  int pos = _u32(zip, eocd + 16);

  for (int n = 0; n < entries; n++) {
    if (pos + 46 > zip.length || _u32(zip, pos) != 0x02014b50) break;
    final int method = _u16(zip, pos + 10);
    final int compSize = _u32(zip, pos + 20);
    final int nameLen = _u16(zip, pos + 28);
    final int extraLen = _u16(zip, pos + 30);
    final int commentLen = _u16(zip, pos + 32);
    final int localOffset = _u32(zip, pos + 42);
    final String entryName = utf8.decode(zip.sublist(pos + 46, pos + 46 + nameLen), allowMalformed: true);

    if (entryName == name) {
      if (localOffset + 30 > zip.length || _u32(zip, localOffset) != 0x04034b50) {
        throw const XlsxFormatException('El archivo .xlsx está dañado.');
      }
      final int localNameLen = _u16(zip, localOffset + 26);
      final int localExtraLen = _u16(zip, localOffset + 28);
      final int start = localOffset + 30 + localNameLen + localExtraLen;
      final Uint8List raw = zip.sublist(start, start + compSize);
      if (method == 0) return raw;
      if (method == 8) {
        return Uint8List.fromList(ZLibCodec(raw: true).decode(raw));
      }
      throw const XlsxFormatException('Compresión de .xlsx no soportada.');
    }
    pos += 46 + nameLen + extraLen + commentLen;
  }
  return null;
}

/// Nombres de las hojas del libro (xl/worksheets/sheetN.xml), ordenados.
List<String> _worksheetNames(Uint8List zip) {
  final List<String> names = [];
  int eocd = -1;
  final int minPos = zip.length - 22 - 65535 < 0 ? 0 : zip.length - 22 - 65535;
  for (int i = zip.length - 22; i >= minPos; i--) {
    if (_u32(zip, i) == 0x06054b50) {
      eocd = i;
      break;
    }
  }
  if (eocd == -1) return names;
  final int entries = _u16(zip, eocd + 10);
  int pos = _u32(zip, eocd + 16);
  for (int n = 0; n < entries; n++) {
    if (pos + 46 > zip.length || _u32(zip, pos) != 0x02014b50) break;
    final int nameLen = _u16(zip, pos + 28);
    final int extraLen = _u16(zip, pos + 30);
    final int commentLen = _u16(zip, pos + 32);
    final String entryName = utf8.decode(zip.sublist(pos + 46, pos + 46 + nameLen), allowMalformed: true);
    if (RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(entryName)) names.add(entryName);
    pos += 46 + nameLen + extraLen + commentLen;
  }
  names.sort((a, b) {
    int num(String s) => int.parse(RegExp(r'sheet(\d+)\.xml').firstMatch(s)!.group(1)!);
    return num(a).compareTo(num(b));
  });
  return names;
}

String _decodeEntities(String s) {
  return s
      .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)))
      .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m.group(1)!)))
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}

/// Texto de todos los `<t>` dentro de un fragmento (soporta texto con formato).
String _textOf(String xmlFragment) {
  final StringBuffer buffer = StringBuffer();
  for (final m in RegExp(r'<t\b[^>]*>(.*?)</t>', dotAll: true).allMatches(xmlFragment)) {
    buffer.write(_decodeEntities(m.group(1)!));
  }
  return buffer.toString();
}

int _columnIndex(String cellRef) {
  final String letters = RegExp(r'^[A-Za-z]+').stringMatch(cellRef) ?? 'A';
  int index = 0;
  for (final unit in letters.toUpperCase().codeUnits) {
    index = index * 26 + (unit - 64);
  }
  return index - 1;
}

/// Lee la primera hoja de un .xlsx y la devuelve como filas de texto. Los
/// números y las fechas llegan "crudos" (las fechas de Excel son números de
/// serie; `parseFlexibleDate` sabe convertirlos).
List<List<String>> readXlsxRows(Uint8List bytes) {
  final List<String> sheets = _worksheetNames(bytes);
  if (sheets.isEmpty) {
    throw const XlsxFormatException('No se encontró ninguna hoja en el archivo.');
  }
  final Uint8List? sheetBytes = _readZipEntry(bytes, sheets.first);
  if (sheetBytes == null) throw const XlsxFormatException('No se pudo leer la hoja.');
  final String sheetXml = utf8.decode(sheetBytes, allowMalformed: true);

  // Textos compartidos (la mayoría de las celdas de texto apuntan aquí).
  final List<String> shared = [];
  final Uint8List? sharedBytes = _readZipEntry(bytes, 'xl/sharedStrings.xml');
  if (sharedBytes != null) {
    final String sharedXml = utf8.decode(sharedBytes, allowMalformed: true);
    for (final m in RegExp(r'<si\b[^>]*>(.*?)</si>', dotAll: true).allMatches(sharedXml)) {
      shared.add(_textOf(m.group(1)!));
    }
  }

  final List<List<String>> rows = [];
  for (final rowMatch in RegExp(r'<row\b[^>]*>(.*?)</row>', dotAll: true).allMatches(sheetXml)) {
    final String rowXml = rowMatch.group(1)!;
    final List<String> row = [];
    for (final cell in RegExp(r'<c\b([^>]*?)(?:/>|>(.*?)</c>)', dotAll: true).allMatches(rowXml)) {
      final String attrs = cell.group(1) ?? '';
      final String inner = cell.group(2) ?? '';
      final String ref = RegExp(r'\br="([A-Za-z]+\d+)"').firstMatch(attrs)?.group(1) ?? '';
      final String type = RegExp(r'\bt="(\w+)"').firstMatch(attrs)?.group(1) ?? 'n';

      String value = '';
      if (type == 'inlineStr') {
        value = _textOf(inner);
      } else {
        final String raw = RegExp(r'<v>(.*?)</v>', dotAll: true).firstMatch(inner)?.group(1) ?? '';
        if (type == 's') {
          final int? idx = int.tryParse(raw.trim());
          value = (idx != null && idx >= 0 && idx < shared.length) ? shared[idx] : '';
        } else {
          value = _decodeEntities(raw);
        }
      }

      if (ref.isNotEmpty) {
        final int col = _columnIndex(ref);
        while (row.length < col) {
          row.add('');
        }
      }
      row.add(value);
    }
    if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
  }
  return rows;
}
