/// Alerta de tasa: avisa cuando 1 [from] llega a [target] [to] (por encima o
/// por debajo). Se guarda como mapa simple en la caja de ajustes.
class RateAlert {
  final String id;
  final String from;
  final String to;
  final bool above;
  final double target;
  final DateTime? lastTriggered;

  const RateAlert({
    required this.id,
    required this.from,
    required this.to,
    required this.above,
    required this.target,
    this.lastTriggered,
  });

  RateAlert copyWith({DateTime? lastTriggered}) => RateAlert(
        id: id,
        from: from,
        to: to,
        above: above,
        target: target,
        lastTriggered: lastTriggered ?? this.lastTriggered,
      );

  /// ¿La tasa actual [rate] cumple la condición de la alerta?
  bool isReachedBy(double rate) => above ? rate >= target : rate <= target;

  Map<String, dynamic> toMap() => {
        'id': id,
        'from': from,
        'to': to,
        'above': above,
        'target': target,
        if (lastTriggered != null) 'lastTriggered': lastTriggered!.toIso8601String(),
      };

  factory RateAlert.fromMap(Map<dynamic, dynamic> map) => RateAlert(
        id: map['id'].toString(),
        from: map['from'].toString(),
        to: map['to'].toString(),
        above: map['above'] == true,
        target: (map['target'] as num).toDouble(),
        lastTriggered: map['lastTriggered'] == null ? null : DateTime.tryParse(map['lastTriggered'].toString()),
      );
}
