import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/couple_models.dart';
import 'package:expense_tracker/utils/couple_crypto.dart';

void main() {
  group('código de invitación', () {
    test('se genera de 12 caracteres válidos y distintos cada vez', () {
      final a = generateInviteCode();
      final b = generateInviteCode();
      expect(a.length, 12);
      expect(isValidInviteCode(a), isTrue);
      expect(a == b, isFalse);
    });
    test('formato con guiones y normalización', () {
      expect(formatInviteCode('K7M29QXA4TBD'), 'K7M2-9QXA-4TBD');
      expect(normalizeInviteCode(' k7m2-9qxa 4tbd '), 'K7M29QXA4TBD');
      expect(isValidInviteCode('k7m2-9qxa-4tbd'), isTrue);
    });
    test('rechaza códigos cortos, largos y con letras que no existen (0, O, 1, I)', () {
      expect(isValidInviteCode('K7M29QXA4TB'), isFalse);
      expect(isValidInviteCode('K7M29QXA4TBDD'), isFalse);
      expect(isValidInviteCode('O0O0O0O0O0O0'), isFalse);
      expect(isValidInviteCode('I1I1I1I1I1I1'), isFalse);
    });
  });

  group('huella y clave', () {
    test('la huella es estable y no depende del formato', () async {
      final a = await inviteHash('K7M29QXA4TBD');
      final b = await inviteHash('k7m2-9qxa-4tbd');
      final c = await inviteHash('K7M29QXA4TBE');
      expect(a, b);
      expect(a == c, isFalse);
      expect(a.length, 64);
    });
    test('la clave es de 32 bytes y depende del código', () async {
      final k1 = await deriveCoupleKey('K7M29QXA4TBD', iterations: 1000);
      final k2 = await deriveCoupleKey('k7m2-9qxa-4tbd', iterations: 1000);
      final k3 = await deriveCoupleKey('K7M29QXA4TBE', iterations: 1000);
      expect(k1.length, 32);
      expect(k1, k2);
      expect(k1 == k3, isFalse);
    });
  });

  group('cifrado', () {
    test('lo cifrado se descifra igual (con acentos y símbolos)', () async {
      final key = await deriveCoupleKey('K7M29QXA4TBD', iterations: 1000);
      final sealed = await encryptJson({'n': 'Café & Té ñandú', 'a': 12.5, 'k': 'expense:1'}, key);
      final back = await decryptJson(sealed.payload, sealed.nonce, key);
      expect(back, isNotNull);
      expect(back!['n'], 'Café & Té ñandú');
      expect(back['a'], 12.5);
      expect(back['k'], 'expense:1');
    });
    test('con otra clave no se puede leer', () async {
      final k1 = await deriveCoupleKey('K7M29QXA4TBD', iterations: 1000);
      final k2 = await deriveCoupleKey('K7M29QXA4TBE', iterations: 1000);
      final sealed = await encryptJson({'n': 'secreto'}, k1);
      expect(await decryptJson(sealed.payload, sealed.nonce, k2), isNull);
    });
    test('si alguien altera el dato, se rechaza', () async {
      final key = await deriveCoupleKey('K7M29QXA4TBD', iterations: 1000);
      final sealed = await encryptJson({'n': 'secreto'}, key);
      final tampered = (sealed.payload.startsWith('A') ? 'B' : 'A') + sealed.payload.substring(1);
      expect(await decryptJson(tampered, sealed.nonce, key), isNull);
    });
    test('el texto cifrado no contiene el dato en claro y cada cifrado es distinto', () async {
      final key = await deriveCoupleKey('K7M29QXA4TBD', iterations: 1000);
      final a = await encryptJson({'n': 'secreto'}, key);
      final b = await encryptJson({'n': 'secreto'}, key);
      expect(a.payload.contains('secreto'), isFalse);
      expect(a.payload == b.payload, isFalse);
    });
  });

  test('changeHash es estable y detecta cambios', () {
    expect(changeHash('{"a":1}'), changeHash('{"a":1}'));
    expect(changeHash('{"a":1}') == changeHash('{"a":2}'), isFalse);
    expect(changeHash('x').length, 16);
  });

  group('modelos de lo compartido', () {
    test('ajustes de compartir: por defecto nada y ida y vuelta', () {
      expect(const CouplePrefs().any, isFalse);
      final p = const CouplePrefs().copyWith(vaults: true, debts: true);
      final back = CouplePrefs.fromMap(Map<dynamic, dynamic>.from(p.toMap()));
      expect(back.vaults && back.debts, isTrue);
      expect(back.expenses || back.incomes, isFalse);
      expect(CouplePrefs.fromMap(null).any, isFalse);
    });
    test('gasto de la pareja se lee tolerando campos faltantes', () {
      final e = PExpense.fromData({'n': 'Cena', 'a': 30, 'c': 'USD', 'd': '2026-10-16T12:00:00.000'}, split: false);
      expect(e.name, 'Cena');
      expect(e.amount, 30.0);
      expect(e.category, 'otros');
      expect(e.date.month, 10);
    });
    test('meta con progreso acotado', () {
      expect(const PVault(name: 'Viaje', target: 100, current: 250, currency: 'USD').progress, 1);
      expect(const PVault(name: 'Viaje', target: 0, current: 5, currency: 'USD').progress, 0);
    });
  });
}
