import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../app_config.dart';
import '../services/apk_installer.dart';
import '../services/update_downloader.dart';
import '../services/update_service.dart';
import '../services/url_service.dart';

enum UpdateCheckResult { available, upToDate, failed, disabled }

/// En qué paso va la actualización dentro de la app.
enum UpdatePhase { idle, downloading, installing }

/// Qué salió mal (si algo salió mal).
enum UpdateProblem { none, network, invalid, noApk, permission, installer }

/// Comprueba si hay una versión nueva en GitHub Releases (máx. una vez al
/// día de forma automática) y recuerda si el usuario la pospuso u omitió.
class UpdateProvider extends ChangeNotifier {
  static const String _lastCheckKey = 'lastUpdateCheck';
  static const String _snoozeKey = 'updateSnoozedUntil';
  static const String _skipKey = 'updateSkippedBuild';
  static const String _cachedKey = 'cachedUpdate';

  final Box settingsBox;
  UpdateInfo? _available;
  bool _checking = false;

  UpdatePhase _phase = UpdatePhase.idle;
  double _progress = 0;
  UpdateProblem _problem = UpdateProblem.none;
  bool _installerOpened = false;
  bool _sessionDismissed = false;
  bool _promptedThisSession = false;
  String? _readyPath;
  UpdateDownloader? _downloader;

  UpdateProvider(this.settingsBox) {
    _loadCached();
    _cleanup();
  }

  UpdatePhase get phase => _phase;
  double get progress => _progress;
  UpdateProblem get problem => _problem;

  /// El instalador de Android ya se abrió: falta que el usuario confirme.
  bool get installerOpened => _installerOpened;

  /// La actualización se puede instalar sin salir de la app.
  bool get canInstallInApp => ApkInstaller.isAvailable;

  DateTime? get lastCheck => DateTime.tryParse((settingsBox.get(_lastCheckKey) as String?) ?? '');

  /// Hay una versión nueva (aunque se haya pospuesto el aviso).
  bool get hasUpdate => _available != null && _available!.build > kAppBuild;

  /// Conviene mostrar el aviso a pantalla completa al abrir la app: una vez
  /// por sesión, salvo que la versión se haya omitido.
  bool get promptPending => showBanner && !_sessionDismissed && !_promptedThisSession;

  void markPrompted() => _promptedThisSession = true;

  /// "Más tarde": cierra el aviso solo por esta sesión (el cartel del Resumen se queda).
  void dismissForSession() {
    _sessionDismissed = true;
    notifyListeners();
  }

  Future<Directory> _updateDir() async => Directory('${(await getTemporaryDirectory()).path}/update');

  /// Borra los APK descargados cuando ya no hay nada pendiente (p. ej. tras actualizar).
  Future<void> _cleanup() async {
    if (_available != null) return;
    try {
      final Directory dir = await _updateDir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  /// Descarga la actualización dentro de la app, la verifica y abre el
  /// instalador de Android. Sin instalador disponible, abre el navegador.
  Future<void> startUpdate() async {
    final UpdateInfo? info = _available;
    if (info == null || _phase != UpdatePhase.idle) return;
    _problem = UpdateProblem.none;
    _installerOpened = false;
    _progress = 0;

    if (!ApkInstaller.isAvailable || info.downloadUrl == null) {
      final bool opened = await UrlService().open(info.downloadUrl ?? info.pageUrl);
      if (!opened) _problem = UpdateProblem.installer;
      notifyListeners();
      return;
    }

    try {
      File? file;
      if (_readyPath != null && await File(_readyPath!).exists()) file = File(_readyPath!);
      if (file == null) {
        _phase = UpdatePhase.downloading;
        notifyListeners();
        _downloader = UpdateDownloader();
        file = await _downloader!.download(
          info,
          dir: await _updateDir(),
          onProgress: (double p) {
            _progress = p;
            notifyListeners();
          },
        );
        _readyPath = file.path;
      }
      _phase = UpdatePhase.installing;
      notifyListeners();
      switch (await ApkInstaller().install(file.path)) {
        case InstallOutcome.opened:
          _installerOpened = true;
          break;
        case InstallOutcome.permissionNeeded:
          _problem = UpdateProblem.permission;
          break;
        default:
          _problem = UpdateProblem.installer;
      }
    } on DownloadException catch (e) {
      switch (e.error) {
        case DownloadError.invalid:
          _problem = UpdateProblem.invalid;
          break;
        case DownloadError.noApk:
          _problem = UpdateProblem.noApk;
          break;
        case DownloadError.cancelled:
          _problem = UpdateProblem.none;
          break;
        case DownloadError.network:
          _problem = UpdateProblem.network;
          break;
      }
    } catch (_) {
      _problem = UpdateProblem.network;
    } finally {
      _phase = UpdatePhase.idle;
      _downloader = null;
      notifyListeners();
    }
  }

  void cancelDownload() => _downloader?.cancel();

  void clearProblem() {
    _problem = UpdateProblem.none;
    _installerOpened = false;
    notifyListeners();
  }

  /// Hay comprobación posible solo si se configuró el repositorio.
  bool get enabled => kGithubRepo.isNotEmpty;
  bool get isChecking => _checking;
  UpdateInfo? get available => _available;

  bool get showBanner {
    final UpdateInfo? info = _available;
    if (info == null || info.build <= kAppBuild) return false;
    if (settingsBox.get(_skipKey) == info.build) return false;
    final DateTime? snoozed = DateTime.tryParse((settingsBox.get(_snoozeKey) as String?) ?? '');
    return snoozed == null || DateTime.now().isAfter(snoozed);
  }

  void _loadCached() {
    final dynamic raw = settingsBox.get(_cachedKey);
    if (raw is String) {
      try {
        final UpdateInfo info = UpdateInfo.fromMap(json.decode(raw) as Map);
        if (info.build > kAppBuild) _available = info;
      } catch (_) {}
    }
  }

  /// Consulta GitHub. Una comprobación manual ignora "más tarde" y "omitir".
  Future<UpdateCheckResult> check({bool manual = false}) async {
    if (!enabled) return UpdateCheckResult.disabled;
    if (_checking) return UpdateCheckResult.failed;
    _checking = true;
    notifyListeners();
    UpdateCheckResult result;
    try {
      final UpdateInfo? latest =
          await UpdateService().fetchLatest(kGithubRepo, arm64: Platform.version.contains('arm64'));
      await settingsBox.put(_lastCheckKey, DateTime.now().toIso8601String());
      if (latest != null && UpdateService.isNewer(current: kAppBuild, latest: latest.build)) {
        _available = latest;
        await settingsBox.put(_cachedKey, json.encode(latest.toMap()));
        if (manual) {
          await settingsBox.delete(_snoozeKey);
          await settingsBox.delete(_skipKey);
        }
        result = UpdateCheckResult.available;
      } else {
        _available = null;
        await settingsBox.delete(_cachedKey);
        result = UpdateCheckResult.upToDate;
      }
    } catch (_) {
      result = UpdateCheckResult.failed;
    }
    _checking = false;
    notifyListeners();
    return result;
  }

  /// Comprobación automática: como máximo cada 24 horas.
  Future<void> checkIfDue() async {
    if (!enabled) return;
    final DateTime? last = DateTime.tryParse((settingsBox.get(_lastCheckKey) as String?) ?? '');
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 24)) return;
    await check();
  }

  /// "Más tarde": oculta el aviso 3 días.
  Future<void> snooze() async {
    await settingsBox.put(_snoozeKey, DateTime.now().add(const Duration(days: 3)).toIso8601String());
    notifyListeners();
  }

  /// "Omitir esta versión": no vuelve a avisar de ESTA versión.
  Future<void> skip() async {
    final UpdateInfo? info = _available;
    if (info != null) await settingsBox.put(_skipKey, info.build);
    notifyListeners();
  }
}
