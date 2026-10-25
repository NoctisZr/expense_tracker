import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/services/update_service.dart';

const List<Map<String, String>> _assets = [
  {'name': 'ExpenseTracker-1.5.0-armeabi-v7a.apk', 'browser_download_url': 'https://x/v7a.apk'},
  {'name': 'ExpenseTracker-1.5.0-arm64-v8a.apk', 'browser_download_url': 'https://x/arm64.apk'},
  {'name': 'notas.txt', 'browser_download_url': 'https://x/notas.txt'},
];

void main() {
  group('etiquetas', () {
    test('lee versión y build de v1.5.0-10', () {
      expect(UpdateService.buildFromTag('v1.5.0-10'), 10);
      expect(UpdateService.versionFromTag('v1.5.0-10'), '1.5.0');
      expect(UpdateService.buildFromTag('1.4.2-9'), 9);
    });

    test('formatos desconocidos devuelven null', () {
      expect(UpdateService.buildFromTag('build-12'), isNull);
      expect(UpdateService.versionFromTag('latest'), isNull);
      expect(UpdateService.buildFromTag('v1.5-3'), isNull);
    });
  });

  group('elegir APK', () {
    test('arm64 elige el de arm64', () {
      expect(UpdateService.pickAssetUrl(_assets, arm64: true), 'https://x/arm64.apk');
    });

    test('32 bits elige el armeabi', () {
      expect(UpdateService.pickAssetUrl(_assets, arm64: false), 'https://x/v7a.apk');
    });

    test('si no hay el específico, usa el primer APK; ignora lo que no es APK', () {
      final only = [
        {'name': 'otro.txt', 'browser_download_url': 'https://x/otro.txt'},
        {'name': 'App-universal.apk', 'browser_download_url': 'https://x/uni.apk'},
      ];
      expect(UpdateService.pickAssetUrl(only, arm64: true), 'https://x/uni.apk');
      expect(UpdateService.pickAssetUrl(const [], arm64: true), isNull);
    });
  });

  group('parseRelease', () {
    final base = <String, dynamic>{
      'tag_name': 'v1.5.0-10',
      'html_url': 'https://github.com/o/r/releases/tag/v1.5.0-10',
      'body': '## Expense Tracker 1.5.0\n\nNovedades',
      'assets': _assets,
    };

    test('release normal', () {
      final info = UpdateService.parseRelease(base, arm64: true)!;
      expect(info.version, '1.5.0');
      expect(info.build, 10);
      expect(info.downloadUrl, 'https://x/arm64.apk');
      expect(info.pageUrl, contains('releases/tag'));
      expect(info.notes, contains('Novedades'));
    });

    test('borradores, prelanzamientos y etiquetas raras se ignoran', () {
      expect(UpdateService.parseRelease({...base, 'draft': true}, arm64: true), isNull);
      expect(UpdateService.parseRelease({...base, 'prerelease': true}, arm64: true), isNull);
      expect(UpdateService.parseRelease({...base, 'tag_name': 'nightly'}, arm64: true), isNull);
    });

    test('ida y vuelta toMap / fromMap', () {
      final info = UpdateService.parseRelease(base, arm64: false)!;
      final copy = UpdateInfo.fromMap(info.toMap());
      expect(copy.build, info.build);
      expect(copy.downloadUrl, info.downloadUrl);
    });
  });

  test('isNewer compara el número de build', () {
    expect(UpdateService.isNewer(current: 9, latest: 10), isTrue);
    expect(UpdateService.isNewer(current: 10, latest: 10), isFalse);
    expect(UpdateService.isNewer(current: 11, latest: 10), isFalse);
  });
}
