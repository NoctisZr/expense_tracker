import 'dart:convert';
import 'package:http/http.dart' as http;

/// Una versión nueva publicada en GitHub Releases.
class UpdateInfo {
  final String version;
  final int build;
  final String notes;
  final String pageUrl;
  final String? downloadUrl;

  const UpdateInfo({
    required this.version,
    required this.build,
    required this.notes,
    required this.pageUrl,
    required this.downloadUrl,
  });

  Map<String, dynamic> toMap() => {
        'version': version,
        'build': build,
        'notes': notes,
        'pageUrl': pageUrl,
        if (downloadUrl != null) 'downloadUrl': downloadUrl,
      };

  factory UpdateInfo.fromMap(Map<dynamic, dynamic> map) => UpdateInfo(
        version: map['version'].toString(),
        build: (map['build'] as num).toInt(),
        notes: map['notes']?.toString() ?? '',
        pageUrl: map['pageUrl'].toString(),
        downloadUrl: map['downloadUrl']?.toString(),
      );
}

class UpdateException implements Exception {
  final String message;
  const UpdateException(this.message);
  @override
  String toString() => message;
}

/// Consulta el último release publicado en GitHub (repositorio público).
/// Las etiquetas del release tienen la forma `v1.5.0-10` (versión-build) y el
/// número de build es lo que se compara con el de la app instalada.
class UpdateService {
  static final RegExp _tagPattern = RegExp(r'^v?(\d+\.\d+\.\d+)-(\d+)$');

  static int? buildFromTag(String tag) {
    final RegExpMatch? m = _tagPattern.firstMatch(tag.trim());
    return m == null ? null : int.parse(m.group(2)!);
  }

  static String? versionFromTag(String tag) => _tagPattern.firstMatch(tag.trim())?.group(1);

  /// Elige el APK adecuado a la arquitectura del teléfono entre los archivos
  /// del release; si no hay uno específico, el primer APK.
  static String? pickAssetUrl(List<dynamic> assets, {required bool arm64}) {
    String? fallback;
    for (final a in assets) {
      if (a is! Map) continue;
      final String name = (a['name'] ?? '').toString().toLowerCase();
      final String? url = a['browser_download_url']?.toString();
      if (url == null || !name.endsWith('.apk')) continue;
      fallback ??= url;
      if (arm64 && name.contains('arm64')) return url;
      if (!arm64 && (name.contains('armeabi') || name.contains('v7a'))) return url;
    }
    return fallback;
  }

  /// Convierte la respuesta de la API en [UpdateInfo]. Ignora borradores,
  /// prelanzamientos y etiquetas con otro formato.
  static UpdateInfo? parseRelease(Map<String, dynamic> json, {required bool arm64}) {
    if (json['draft'] == true || json['prerelease'] == true) return null;
    final String tag = json['tag_name']?.toString() ?? '';
    final int? build = buildFromTag(tag);
    final String? version = versionFromTag(tag);
    if (build == null || version == null) return null;
    final List<dynamic> assets = json['assets'] is List ? json['assets'] as List<dynamic> : const [];
    return UpdateInfo(
      version: version,
      build: build,
      notes: (json['body'] ?? '').toString().trim(),
      pageUrl: (json['html_url'] ?? '').toString(),
      downloadUrl: pickAssetUrl(assets, arm64: arm64),
    );
  }

  static bool isNewer({required int current, required int latest}) => latest > current;

  /// Devuelve el último release o `null` si no hay (o el repositorio es privado).
  Future<UpdateInfo?> fetchLatest(String repo, {required bool arm64}) async {
    final Uri uri = Uri.https('api.github.com', '/repos/$repo/releases/latest');
    late final http.Response response;
    try {
      response = await http.get(uri, headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      }).timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const UpdateException('No se pudo conectar con GitHub.');
    }
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw UpdateException('GitHub respondió con un error (${response.statusCode}).');
    }
    try {
      final dynamic decoded = json.decode(response.body);
      if (decoded is Map) return parseRelease(Map<String, dynamic>.from(decoded), arm64: arm64);
    } catch (_) {}
    throw const UpdateException('La respuesta de GitHub no es válida.');
  }
}
