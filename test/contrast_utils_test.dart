import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/mod_theme.dart';
import 'package:expense_tracker/utils/contrast_utils.dart';

void main() {
  test('contraste máximo y mínimo', () {
    expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(contrastRatio(Colors.white, Colors.white), closeTo(1, 0.01));
  });

  test('un mod con texto poco legible genera aviso', () {
    const mod = ModTheme(
      name: 'Malo',
      background: Color(0xFFFFFFFF),
      card: Color(0xFFFFFFFF),
      textPrimary: Color(0xFFEEEEEE),
      textSecondary: Color(0xFFDDDDDD),
    );
    final warnings = modContrastWarnings(mod);
    expect(warnings, contains('contraste_texto_principal'));
    expect(warnings, contains('contraste_texto_secundario'));
  });

  test('los mods incluidos en la app no generan avisos de contraste', () {
    final dir = Directory('mods');
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    expect(files, isNotEmpty);
    for (final file in files) {
      final mod = ModTheme.fromJson(json.decode(file.readAsStringSync()) as Map<String, dynamic>);
      expect(modContrastWarnings(mod), isEmpty, reason: file.path);
    }
  });
}
