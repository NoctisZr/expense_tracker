import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'update_service.dart';

enum DownloadError { noApk, network, invalid, cancelled }

class DownloadException implements Exception {
  final DownloadError error;
  const DownloadException(this.error);

  @override
  String toString() => 'DownloadException($error)';
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

/// Descarga el APK de una actualización desde GitHub dentro de la propia app,
/// con progreso, y lo verifica (tamaño y SHA-256 cuando GitHub lo informa)
/// antes de entregarlo para instalar.
class UpdateDownloader {
  final http.Client _client;
  bool _cancelled = false;

  UpdateDownloader({http.Client? client}) : _client = client ?? http.Client();

  void cancel() {
    _cancelled = true;
    _client.close();
  }

  /// Descarga el APK a [dir] y devuelve el archivo listo. [onProgress] recibe
  /// un valor de 0 a 1 (si se conoce el tamaño total).
  Future<File> download(
    UpdateInfo info, {
    required Directory dir,
    required void Function(double progress) onProgress,
  }) async {
    final String? url = info.downloadUrl;
    if (url == null) throw const DownloadException(DownloadError.noApk);
    await dir.create(recursive: true);
    final File part = File('${dir.path}/update.part');
    final File target = File('${dir.path}/Nuvio-${info.version}-${info.build}.apk');
    if (await part.exists()) await part.delete();

    IOSink? sink;
    try {
      final http.StreamedResponse response =
          await _client.send(http.Request('GET', Uri.parse(url))).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) throw const DownloadException(DownloadError.network);

      final int total = (response.contentLength != null && response.contentLength! > 0)
          ? response.contentLength!
          : (info.downloadSize ?? 0);
      final _DigestSink digestSink = _DigestSink();
      final ByteConversionSink hasher = sha256.startChunkedConversion(digestSink);
      sink = part.openWrite();
      int received = 0;
      await for (final List<int> chunk in response.stream) {
        if (_cancelled) throw const DownloadException(DownloadError.cancelled);
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress((received / total).clamp(0.0, 1.0).toDouble());
      }
      hasher.close();
      await sink.flush();
      await sink.close();
      sink = null;

      final int? expectedSize = info.downloadSize;
      final String? expectedHash = info.downloadSha256;
      if ((expectedSize != null && received != expectedSize) ||
          (expectedHash != null && digestSink.value?.toString() != expectedHash) ||
          received == 0) {
        throw const DownloadException(DownloadError.invalid);
      }
      if (await target.exists()) await target.delete();
      await part.rename(target.path);
      onProgress(1);
      return target;
    } on DownloadException {
      await _discard(sink, part);
      rethrow;
    } catch (_) {
      await _discard(sink, part);
      throw DownloadException(_cancelled ? DownloadError.cancelled : DownloadError.network);
    }
  }

  Future<void> _discard(IOSink? sink, File part) async {
    try {
      await sink?.close();
      if (await part.exists()) await part.delete();
    } catch (_) {}
  }
}
