import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BackupImportException implements Exception {
  final String message;
  BackupImportException(this.message);

  @override
  String toString() => message;
}

class BackupService {
  Future<void> exportAndShare(Map<String, dynamic> data) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final File file = File('${tempDir.path}/expense_tracker_backup_$timestamp.json');
    final String jsonString = const JsonEncoder.withIndent('  ').convert(data);
    await file.writeAsString(jsonString);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Expense Tracker - Respaldo de datos',
    );
  }

  Future<void> exportCsvAndShare(String csv) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final File file = File('${tempDir.path}/expense_tracker_gastos_$timestamp.csv');
    await file.writeAsString(csv);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Expense Tracker - Gastos (CSV)',
    );
  }

  /// Lee un CSV de gastos elegido por el usuario. Devuelve `null` si
  /// cancela.
  Future<String?> pickCsvContent() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );
    final String? path = result?.files.single.path;
    if (path == null) return null;
    try {
      return await File(path).readAsString();
    } catch (_) {
      throw BackupImportException('No se pudo leer el archivo seleccionado.');
    }
  }

  // ---------------------------------------------------------------------
  // Respaldos automáticos (en el almacenamiento interno de la app)
  // ---------------------------------------------------------------------

  static const int _maxAutoBackups = 5;

  Future<Directory> _autoBackupDir() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${docs.path}/auto_backups');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Guarda un respaldo automático del espacio [workspaceId] y conserva solo
  /// los últimos [_maxAutoBackups]. Los respaldos viven dentro de la app:
  /// si se desinstala, se pierden (por eso también existe "Exportar").
  Future<void> writeAutoBackup(String workspaceId, Map<String, dynamic> data) async {
    final Directory dir = await _autoBackupDir();
    final String stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final File file = File('${dir.path}/auto_${workspaceId}_$stamp.json');
    await file.writeAsString(json.encode(data));

    final List<File> mine = (await listAutoBackups(workspaceId));
    for (int i = _maxAutoBackups; i < mine.length; i++) {
      try {
        await mine[i].delete();
      } catch (_) {}
    }
  }

  /// Respaldos automáticos del espacio, del más reciente al más antiguo.
  Future<List<File>> listAutoBackups(String workspaceId) async {
    final Directory dir = await _autoBackupDir();
    final List<File> files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.split('/').last.startsWith('auto_${workspaceId}_'))
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<Map<String, dynamic>> readBackupFile(File file) async {
    try {
      final dynamic decoded = json.decode(await file.readAsString());
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    throw BackupImportException('No se pudo leer el respaldo automático.');
  }

  Future<Map<String, dynamic>?> pickAndParseBackup() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    final String? path = result?.files.single.path;
    if (path == null) return null;

    late final String content;
    try {
      content = await File(path).readAsString();
    } catch (_) {
      throw BackupImportException('No se pudo leer el archivo seleccionado.');
    }

    late final dynamic decoded;
    try {
      decoded = json.decode(content);
    } catch (_) {
      throw BackupImportException('El archivo no contiene un JSON válido.');
    }

    if (decoded is! Map<String, dynamic> || decoded['formatVersion'] == null) {
      throw BackupImportException('El archivo no es un respaldo válido de esta app.');
    }

    return decoded;
  }
}
