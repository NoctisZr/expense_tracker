/// Lógica PURA de los sobres: repartes tus ingresos del mes en sobres con un
/// porcentaje y cada sobre cubre unas categorías de gasto.

class Envelope {
  final String id;
  final String name;

  /// Porcentaje de los ingresos del mes que recibe este sobre (0–100).
  final double percent;

  /// Categorías de gasto que se descuentan de este sobre. Vacío = reserva
  /// (por ejemplo, el sobre de ahorro: no se gasta).
  final List<String> categories;

  const Envelope({
    required this.id,
    required this.name,
    required this.percent,
    this.categories = const [],
  });

  Envelope copyWith({String? name, double? percent, List<String>? categories}) => Envelope(
        id: id,
        name: name ?? this.name,
        percent: percent ?? this.percent,
        categories: categories ?? this.categories,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'percent': percent,
        'categories': categories,
      };

  factory Envelope.fromMap(Map<dynamic, dynamic> map) => Envelope(
        id: map['id'].toString(),
        name: map['name'].toString(),
        percent: (map['percent'] as num?)?.toDouble() ?? 0,
        categories: (map['categories'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}

class EnvelopeStatus {
  final Envelope envelope;

  /// Lo que le toca al sobre este mes (ingresos × porcentaje).
  final double allocated;

  /// Lo gastado en las categorías del sobre.
  final double spent;

  const EnvelopeStatus({required this.envelope, required this.allocated, required this.spent});

  double get remaining => allocated - spent;
  bool get isReserve => envelope.categories.isEmpty;
  bool get over => !isReserve && spent > allocated + 0.004;
  double get progress => allocated <= 0 ? (spent > 0 ? 1 : 0) : (spent / allocated).clamp(0.0, 1.0).toDouble();
}

/// Reparto inicial 50/30/20 sobre las categorías integradas.
List<Envelope> defaultEnvelopes() => const [
      Envelope(id: 'env_needs', name: 'Necesidades', percent: 50, categories: ['servicios', 'comida']),
      Envelope(id: 'env_wants', name: 'Deseos', percent: 30, categories: ['compras', 'otros']),
      Envelope(id: 'env_save', name: 'Ahorro', percent: 20),
    ];

/// Estado de cada sobre dados los ingresos del mes y el gasto por categoría.
List<EnvelopeStatus> envelopeStatuses(
  List<Envelope> envelopes,
  double income,
  Map<String, double> spentByCategory,
) {
  return [
    for (final e in envelopes)
      EnvelopeStatus(
        envelope: e,
        allocated: (income * e.percent / 100 * 100).roundToDouble() / 100,
        spent: e.categories.fold<double>(0, (sum, c) => sum + (spentByCategory[c] ?? 0)),
      ),
  ];
}

/// Gasto de las categorías que no pertenecen a ningún sobre.
double unassignedSpend(List<Envelope> envelopes, Map<String, double> spentByCategory) {
  final Set<String> assigned = {for (final e in envelopes) ...e.categories};
  double total = 0;
  spentByCategory.forEach((cat, value) {
    if (!assigned.contains(cat)) total += value;
  });
  return total;
}

/// Suma de los porcentajes (lo ideal es 100).
double totalPercent(List<Envelope> envelopes) => envelopes.fold<double>(0, (sum, e) => sum + e.percent);
