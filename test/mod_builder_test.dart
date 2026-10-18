import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/mod_theme.dart';
import 'package:expense_tracker/utils/contrast_utils.dart';
import 'package:expense_tracker/utils/mod_builder.dart';

void main() {
  test('colorToHex y parseHexColor son inversos', () {
    expect(colorToHex(const Color(0xFFFF8FB3)), '#FF8FB3');
    expect(parseHexColor('#ff8fb3'), const Color(0xFFFF8FB3));
    expect(parseHexColor('ff8fb3'), const Color(0xFFFF8FB3));
    expect(parseHexColor('#f0a'), const Color(0xFFFF00AA));
    expect(parseHexColor('xyz'), isNull);
    expect(parseHexColor('#12345'), isNull);
  });

  test('toJson produce un mod válido que ModTheme.fromJson entiende', () {
    final draft = ModDraft.fromAccent(
      accent: const Color(0xFF4DB6AC),
      dark: true,
      name: 'Mi mod',
      author: 'Yo',
      cardShape: 'stadium',
      outlined: false,
    );
    final mod = ModTheme.fromJson(draft.toJson());
    expect(mod.name, 'Mi mod');
    expect(mod.author, 'Yo');
    expect(mod.preferredBrightness, Brightness.dark);
    expect(mod.cardShape, 'stadium');
    expect(mod.cardStyle, 'filled');
    expect(mod.accent, const Color(0xFF4DB6AC));
  });

  test('las paletas generadas siempre cumplen el contraste, con cualquier acento', () {
    const accents = [
      Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00), Color(0xFF0000FF),
      Color(0xFFFFFFFF), Color(0xFF000000), Color(0xFF808080), Color(0xFFFF8FB3),
    ];
    for (final accent in accents) {
      for (final dark in [true, false]) {
        final draft = ModDraft.fromAccent(accent: accent, dark: dark, name: 'T');
        final mod = ModTheme.fromJson(draft.toJson());
        expect(modContrastWarnings(mod), isEmpty, reason: '${colorToHex(accent)} dark=$dark');
      }
    }
  });

  test('editar un mod existente conserva sus colores', () {
    final original = ModDraft.fromAccent(accent: const Color(0xFFE57373), dark: false, name: 'Rojo');
    original.background = const Color(0xFFFFF0F0);
    final copy = ModDraft.fromModTheme(ModTheme.fromJson(original.toJson()));
    expect(copy.background, const Color(0xFFFFF0F0));
    expect(copy.dark, isFalse);
    expect(copy.name, 'Rojo');
  });
}
