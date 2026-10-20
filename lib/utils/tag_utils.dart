/// Convierte texto libre ("comida, #viaje  trabajo") en etiquetas limpias:
/// minúsculas, sin "#", sin repetir y sin vacías.
List<String> parseTags(String text) {
  final List<String> result = [];
  for (final raw in text.split(RegExp(r'[,\s]+'))) {
    final String tag = raw.replaceAll('#', '').trim().toLowerCase();
    if (tag.isNotEmpty && tag.length <= 24 && !result.contains(tag)) result.add(tag);
  }
  return result.take(8).toList();
}

/// "#comida #viaje" a partir de una lista (para mostrar o editar).
String tagsToText(List<String>? tags) {
  if (tags == null || tags.isEmpty) return '';
  return tags.map((t) => '#$t').join(' ');
}
