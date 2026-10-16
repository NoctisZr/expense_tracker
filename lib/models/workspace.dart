/// Un "espacio de trabajo": un conjunto independiente de gastos, ingresos,
/// bóvedas, presupuestos y gastos recurrentes (por ejemplo Personal,
/// Negocio, Viaje). El espacio 'personal' usa las cajas de Hive originales
/// de la app, así que los datos existentes siguen ahí sin migración.
class Workspace {
  final String id;
  final String name;

  const Workspace({required this.id, required this.name});

  Workspace copyWith({String? name}) => Workspace(id: id, name: name ?? this.name);

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  factory Workspace.fromMap(Map<dynamic, dynamic> map) => Workspace(
        id: map['id'].toString(),
        name: map['name'].toString(),
      );
}
