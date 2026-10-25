import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../app_config.dart';
import '../services/update_service.dart';

enum UpdateCheckResult { available, upToDate, failed, disabled }

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

  UpdateProvider(this.settingsBox) {
    _loadCached();
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
