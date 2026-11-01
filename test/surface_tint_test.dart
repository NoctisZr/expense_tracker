import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/utils/app_theme.dart';

void main() {
  const Color darkCard = Color(0xFF252530);
  const Color orange = Color(0xFFF08A4B);

  test('tinte 0 deja el color tal cual (fondos neutros)', () {
    expect(tintedSurface(darkCard, orange, 0), darkCard);
  });

  test('con tinte el color toma el tono del acento y conserva la luminosidad', () {
    final Color tinted = tintedSurface(darkCard, orange, 1);
    final HSLColor t = HSLColor.fromColor(tinted);
    final HSLColor a = HSLColor.fromColor(orange);
    final HSLColor b = HSLColor.fromColor(darkCard);
    expect((t.hue - a.hue).abs() < 3, isTrue);
    expect((t.lightness - b.lightness).abs() < 0.01, isTrue);
    expect(t.saturation > b.saturation, isTrue);
  });

  test('distintos acentos dan distintos fondos', () {
    final Color a = tintedSurface(darkCard, orange, 0.6);
    final Color b = tintedSurface(darkCard, const Color(0xFF4A9BF0), 0.6);
    expect(a == b, isFalse);
  });

  test('el blanco de las tarjetas claras también se tiñe', () {
    final Color tinted = tintedSurface(Colors.white, orange, 1);
    expect(tinted == Colors.white, isFalse);
    expect(HSLColor.fromColor(tinted).lightness > 0.95, isTrue);
  });

  test('el tinte se limita a 1', () {
    expect(tintedSurface(darkCard, orange, 5), tintedSurface(darkCard, orange, 1));
  });
}
