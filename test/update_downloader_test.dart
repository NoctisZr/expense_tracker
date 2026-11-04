import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:expense_tracker/services/update_downloader.dart';
import 'package:expense_tracker/services/update_service.dart';

void main() {
  late Directory dir;
  final List<int> bytes = List<int>.generate(5000, (i) => i % 251);
  final String hash = sha256.convert(bytes).toString();

  setUp(() async => dir = await Directory.systemTemp.createTemp('upd_test'));
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  UpdateInfo info({int? size, String? sha, String? url = 'https://x/a.apk'}) => UpdateInfo(
        version: '2.3.0',
        build: 21,
        notes: '',
        pageUrl: 'https://x',
        downloadUrl: url,
        downloadSize: size,
        downloadSha256: sha,
      );

  http.Client client({int status = 200, List<int>? body}) => MockClient.streaming((request, _) async {
        final List<int> data = body ?? bytes;
        return http.StreamedResponse(
          Stream.fromIterable([data.sublist(0, 2000), data.sublist(2000)]),
          status,
          contentLength: data.length,
        );
      });

  test('descarga, informa el progreso y verifica tamaño y huella', () async {
    final List<double> progress = [];
    final File file = await UpdateDownloader(client: client())
        .download(info(size: bytes.length, sha: hash), dir: dir, onProgress: progress.add);
    expect(await file.readAsBytes(), bytes);
    expect(file.path.endsWith('Nuvio-2.3.0-21.apk'), isTrue);
    expect(progress.isNotEmpty, isTrue);
    expect(progress.last, 1.0);
    expect(progress.first <= progress.last, isTrue);
    expect(await File('${dir.path}/update.part').exists(), isFalse);
  });

  test('sin tamaño ni huella informados, igual descarga', () async {
    final File file = await UpdateDownloader(client: client()).download(info(), dir: dir, onProgress: (_) {});
    expect(await file.length(), bytes.length);
  });

  test('si la huella no coincide, rechaza y no deja archivos', () async {
    final bad = '0' * 64;
    await expectLater(
      UpdateDownloader(client: client()).download(info(size: bytes.length, sha: bad), dir: dir, onProgress: (_) {}),
      throwsA(isA<DownloadException>().having((e) => e.error, 'error', DownloadError.invalid)),
    );
    expect(dir.listSync().where((e) => e.path.endsWith('.apk') || e.path.endsWith('.part')), isEmpty);
  });

  test('si el tamaño no coincide, rechaza', () async {
    await expectLater(
      UpdateDownloader(client: client()).download(info(size: bytes.length + 1), dir: dir, onProgress: (_) {}),
      throwsA(isA<DownloadException>().having((e) => e.error, 'error', DownloadError.invalid)),
    );
  });

  test('error de servidor', () async {
    await expectLater(
      UpdateDownloader(client: client(status: 404)).download(info(), dir: dir, onProgress: (_) {}),
      throwsA(isA<DownloadException>().having((e) => e.error, 'error', DownloadError.network)),
    );
  });

  test('sin enlace al APK', () async {
    await expectLater(
      UpdateDownloader(client: client()).download(info(url: null), dir: dir, onProgress: (_) {}),
      throwsA(isA<DownloadException>().having((e) => e.error, 'error', DownloadError.noApk)),
    );
  });

  test('la huella de GitHub se lee de "sha256:…"', () {
    expect(UpdateService.sha256FromDigest('sha256:$hash'), hash);
    expect(UpdateService.sha256FromDigest('SHA256:${hash.toUpperCase()}'), hash);
    expect(UpdateService.sha256FromDigest('sha1:abc'), isNull);
    expect(UpdateService.sha256FromDigest(null), isNull);
    expect(UpdateService.sha256FromDigest('sha256:123'), isNull);
  });

  test('el release trae tamaño y huella del APK elegido', () {
    final r = UpdateService.parseRelease({
      'tag_name': 'v2.3.0-21',
      'html_url': 'https://x',
      'body': '',
      'assets': [
        {'name': 'Nuvio-2.3.0-armeabi-v7a.apk', 'browser_download_url': 'https://x/v7a.apk', 'size': 111, 'digest': 'sha256:${'a' * 64}'},
        {'name': 'Nuvio-2.3.0-arm64-v8a.apk', 'browser_download_url': 'https://x/arm64.apk', 'size': 222, 'digest': 'sha256:$hash'},
      ],
    }, arm64: true)!;
    expect(r.downloadUrl, 'https://x/arm64.apk');
    expect(r.downloadSize, 222);
    expect(r.downloadSha256, hash);
    final back = UpdateInfo.fromMap(r.toMap());
    expect(back.downloadSize, 222);
    expect(back.downloadSha256, hash);
  });
}
