import '../models/expense.dart';
import 'id_generator.dart';

/// Resultado de leer un CSV de gastos.
class CsvImportResult {
  final List<Expense> expenses;
  final int skipped;
  final bool headerRecognized;

  const CsvImportResult({
    required this.expenses,
    required this.skipped,
    required this.headerRecognized,
  });
}

/// Separa un texto CSV en filas y celdas. Soporta comillas dobles, comillas
/// escapadas (`""`), saltos de línea dentro de una celda y BOM UTF-8.
/// El separador (coma o punto y coma) se detecta en la primera línea.
List<List<String>> parseCsv(String input) {
  String text = input;
  if (text.startsWith('\uFEFF')) text = text.substring(1);

  final int firstLineEnd = text.indexOf('\n');
  final String firstLine = firstLineEnd == -1 ? text : text.substring(0, firstLineEnd);
  final String delimiter =
      (firstLine.contains(';') && !firstLine.contains(',')) ? ';' : ',';

  final List<List<String>> rows = [];
  List<String> row = [];
  final StringBuffer cell = StringBuffer();
  bool inQuotes = false;

  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    if (!(row.length == 1 && row.first.trim().isEmpty)) rows.add(row);
    row = [];
  }

  for (int i = 0; i < text.length; i++) {
    final String ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      inQuotes = true;
    } else if (ch == delimiter) {
      endCell();
    } else if (ch == '\n') {
      endRow();
    } else if (ch == '\r') {
      // se ignora; el \n siguiente cierra la fila
    } else {
      cell.write(ch);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

/// Convierte "1.234,56", "1,234.56", "$12.50" o "-45" en un número.
/// Devuelve `null` si no se puede interpretar.
double? parseFlexibleAmount(String raw) {
  String s = raw.trim().replaceAll(RegExp(r'[^0-9,.\-]'), '');
  if (s.isEmpty) return null;
  final int lastComma = s.lastIndexOf(',');
  final int lastDot = s.lastIndexOf('.');

  if (lastComma != -1 && lastDot != -1) {
    // El último separador es el decimal; el otro son miles.
    if (lastComma > lastDot) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  } else if (lastComma != -1) {
    final int digitsAfter = s.length - lastComma - 1;
    if (s.indexOf(',') == lastComma && digitsAfter != 3) {
      s = s.replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  }
  return double.tryParse(s);
}

/// Interpreta fechas ISO (2026-10-16), dd/MM/yyyy, dd-MM-yyyy y yyyy/MM/dd.
DateTime? parseFlexibleDate(String raw) {
  final String s = raw.trim();
  if (s.isEmpty) return null;
  final DateTime? iso = DateTime.tryParse(s);
  if (iso != null) return iso;

  // Número de serie de Excel (días desde el 30/12/1899), p. ej. 46037 o 46037.5.
  final double? serial = double.tryParse(s);
  if (serial != null) {
    if (serial >= 20000 && serial <= 80000) {
      return DateTime(1899, 12, 30).add(Duration(days: serial.floor(), hours: 12));
    }
    return null;
  }

  final RegExpMatch? dmy = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})').firstMatch(s);
  if (dmy != null) {
    final int day = int.parse(dmy.group(1)!);
    final int month = int.parse(dmy.group(2)!);
    final int year = int.parse(dmy.group(3)!);
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      return DateTime(year, month, day, 12);
    }
  }
  final RegExpMatch? ymd = RegExp(r'^(\d{4})[/.](\d{1,2})[/.](\d{1,2})').firstMatch(s);
  if (ymd != null) {
    final int year = int.parse(ymd.group(1)!);
    final int month = int.parse(ymd.group(2)!);
    final int day = int.parse(ymd.group(3)!);
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      return DateTime(year, month, day, 12);
    }
  }
  return null;
}

const Map<String, List<String>> _headerSynonyms = {
  'date': ['date', 'fecha', 'data'],
  'name': ['name', 'nombre', 'descripcion', 'descripción', 'description', 'concepto', 'detalle', 'nome'],
  'category': ['category', 'categoria', 'categoría'],
  'amount': ['amount', 'monto', 'importe', 'valor', 'cantidad', 'total'],
  'currency': ['currency', 'moneda', 'divisa', 'moeda'],
};

/// Lee un CSV de gastos (el que exporta la app u otro similar) a partir de
/// los nombres de columna. Los importes negativos se toman como gastos
/// (valor absoluto); las filas sin nombre o sin importe se omiten.
CsvImportResult parseExpensesCsv(
  String text, {
  required String defaultCurrency,
  required List<String> knownCategories,
  required Set<String> supportedCurrencies,
}) {
  return parseExpensesRows(
    parseCsv(text),
    defaultCurrency: defaultCurrency,
    knownCategories: knownCategories,
    supportedCurrencies: supportedCurrencies,
  );
}

/// Igual que [parseExpensesCsv] pero a partir de filas ya separadas (sirve
/// tanto para CSV como para hojas de Excel leídas con `readXlsxRows`).
CsvImportResult parseExpensesRows(
  List<List<String>> rows, {
  required String defaultCurrency,
  required List<String> knownCategories,
  required Set<String> supportedCurrencies,
}) {
  if (rows.isEmpty) {
    return const CsvImportResult(expenses: [], skipped: 0, headerRecognized: false);
  }

  final List<String> header = rows.first.map((h) => h.trim().toLowerCase()).toList();
  final Map<String, int> columns = {};
  _headerSynonyms.forEach((field, names) {
    final int index = header.indexWhere((h) => names.contains(h));
    if (index != -1) columns[field] = index;
  });

  if (!columns.containsKey('name') || !columns.containsKey('amount')) {
    return const CsvImportResult(expenses: [], skipped: 0, headerRecognized: false);
  }

  String cellAt(List<String> row, String field) {
    final int? index = columns[field];
    if (index == null || index >= row.length) return '';
    return row[index].trim();
  }

  final Map<String, String> categoryLookup = {
    for (final c in knownCategories) c.toLowerCase(): c,
  };

  final List<Expense> expenses = [];
  int skipped = 0;
  final String idBase = generateId();

  for (int i = 1; i < rows.length; i++) {
    final List<String> row = rows[i];
    final String name = cellAt(row, 'name');
    final double? parsedAmount = parseFlexibleAmount(cellAt(row, 'amount'));
    if (name.isEmpty || parsedAmount == null || parsedAmount == 0) {
      skipped++;
      continue;
    }

    final String currencyRaw = cellAt(row, 'currency').toUpperCase();
    final String currency =
        supportedCurrencies.contains(currencyRaw) ? currencyRaw : defaultCurrency;

    final String categoryRaw = cellAt(row, 'category').toLowerCase();
    final String category = categoryLookup[categoryRaw] ?? ExpenseCategory.otros;

    expenses.add(Expense(
      id: '${idBase}_$i',
      name: name,
      amount: parsedAmount.abs(),
      currency: currency,
      category: category,
      date: parseFlexibleDate(cellAt(row, 'date')) ?? DateTime.now(),
    ));
  }

  return CsvImportResult(expenses: expenses, skipped: skipped, headerRecognized: true);
}
