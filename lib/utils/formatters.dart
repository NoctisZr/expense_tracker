/// Formatea un número con separador de miles (coma) y 2 decimales fijos,
/// sin depender del paquete `intl`.
String formatAmount(double value) {
  final bool isNegative = value < 0;
  final double absValue = value.abs();

  final String fixed = absValue.toStringAsFixed(2);
  final List<String> parts = fixed.split('.');
  final String integerPart = parts[0];
  final String decimalPart = parts[1];

  final StringBuffer buffer = StringBuffer();
  final int len = integerPart.length;
  for (int i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(integerPart[i]);
  }

  return '${isNegative ? '-' : ''}${buffer.toString()}.$decimalPart';
}

/// Formatea un monto seguido del código de divisa, ej: "1,234.50 USD".
String formatCurrency(double value, String currencyCode) {
  return '${formatAmount(value)} $currencyCode';
}

/// Formatea un porcentaje con un decimal, ej: "33.3%".
String formatPercent(double value) {
  return '${value.toStringAsFixed(1)}%';
}

/// Formatea una fecha/hora como "dd/MM/yyyy HH:mm", ej: "05/09/2026 20:34".
String formatDateTime(DateTime dateTime) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dateTime.day)}/${two(dateTime.month)}/${dateTime.year} '
      '${two(dateTime.hour)}:${two(dateTime.minute)}';
}

/// Formatea solo la fecha como "dd/MM/yyyy", ej: "05/09/2026".
String formatDateShort(DateTime dateTime) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dateTime.day)}/${two(dateTime.month)}/${dateTime.year}';
}

/// Expresa una cantidad de días como "≈ N días (≈ M meses)" cuando pasa de
/// un mes, o solo "≈ N días" si es menos de un mes.
String formatDaysApprox(int days, String diasLabel, String mesesLabel) {
  if (days < 30) {
    return '$days $diasLabel';
  }
  final double months = days / 30;
  return '$days $diasLabel (≈ ${months.toStringAsFixed(1)} $mesesLabel)';
}
