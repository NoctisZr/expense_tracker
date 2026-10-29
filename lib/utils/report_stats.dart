/// Variación porcentual de [current] respecto de [previous]. Null si no hay
/// base para comparar (el periodo anterior fue 0).
double? deltaPercent(double current, double previous) {
  if (previous <= 0) return null;
  return (current - previous) / previous * 100;
}

/// Texto corto con signo: "+12%" / "-5%". Null si no se puede calcular.
String? deltaLabel(double current, double previous) {
  final double? d = deltaPercent(current, previous);
  if (d == null) return null;
  final int rounded = d.round();
  return '${rounded > 0 ? '+' : ''}$rounded%';
}
