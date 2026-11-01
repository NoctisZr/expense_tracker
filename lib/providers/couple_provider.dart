import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import '../app_config.dart';
import '../models/couple_models.dart';
import '../services/supabase_rest.dart';
import '../utils/couple_balance.dart';
import '../utils/couple_crypto.dart';
import '../utils/id_generator.dart';
import 'currency_provider.dart';
import 'finance_provider.dart';

enum CoupleError { notConfigured, invalidCode, notFound, full, network, other }

class CoupleException implements Exception {
  final CoupleError error;
  const CoupleException(this.error);

  @override
  String toString() => 'CoupleException($error)';
}

class _Item {
  final String kind;
  final Map<String, dynamic> data;
  const _Item(this.kind, this.data);
}

/// Finanzas en pareja: cada persona conserva sus datos y comparte solo lo que
/// decide. Los datos viajan cifrados de extremo a extremo por Supabase y lo
/// de tu pareja se guarda aparte (solo lectura), sin mezclarse con lo tuyo.
class CoupleProvider extends ChangeNotifier {
  CoupleProvider(this._box) {
    if (isConfigured) _api = SupabaseRest(url: kSupabaseUrl, key: kSupabaseKey);
  }

  final Box _box;
  SupabaseRest? _api;
  bool _syncing = false;
  CoupleError? _lastError;
  PartnerData? _partnerMemo;

  static const String _kId = 'couple_id';
  static const String _kKey = 'couple_key';
  static const String _kCode = 'couple_code';
  static const String _kName = 'couple_name';
  static const String _kWorkspace = 'couple_ws';
  static const String _kPrefs = 'couple_prefs';
  static const String _kPushed = 'couple_pushed';
  static const String _kPushedUser = 'couple_pushed_user';
  static const String _kCache = 'couple_cache';
  static const String _kLastPull = 'couple_last_pull';
  static const String _kLastSync = 'couple_last_sync';
  static const String _kSession = 'couple_session';
  static const String _kTutorial = 'couple_tutorial_done';
  static const String _kSettlements = 'couple_settlements';
  static const String _kMembers = 'couple_members';

  // ------------------------------------------------------------- estado
  bool get isConfigured => kSupabaseUrl.isNotEmpty && kSupabaseKey.isNotEmpty;
  String? get coupleId => _box.get(_kId) as String?;
  List<int>? get _keyBytes {
    final dynamic k = _box.get(_kKey);
    return k is String ? base64Decode(k) : null;
  }

  bool get isLinked => coupleId != null && _keyBytes != null;
  String? get workspaceId => _box.get(_kWorkspace) as String?;
  String get displayName => (_box.get(_kName) as String?) ?? '';
  String? get inviteCode => _box.get(_kCode) as String?;
  CouplePrefs get prefs => CouplePrefs.fromMap(_box.get(_kPrefs));
  bool get tutorialDone => _box.get(_kTutorial) == true;
  bool get syncing => _syncing;
  CoupleError? get lastError => _lastError;
  int get memberCount => (_box.get(_kMembers) as num?)?.toInt() ?? 1;
  DateTime? get lastSync => DateTime.tryParse((_box.get(_kLastSync) as String?) ?? '');

  /// Tu pareja ya se unió o ya compartió algo.
  bool get hasPartner => memberCount >= 2 || partner.name != null || partner.hasAnything;

  void markTutorialDone() {
    _box.put(_kTutorial, true);
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  // ------------------------------------------------- datos de tu pareja
  Map<String, Map<String, dynamic>> _readCache() {
    final dynamic raw = _box.get(_kCache);
    final Map<String, Map<String, dynamic>> out = {};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map) out[k.toString()] = Map<String, dynamic>.from(v);
      });
    }
    return out;
  }

  PartnerData get partner => _partnerMemo ??= _buildPartner();

  PartnerData _buildPartner() {
    String? name;
    String? currency;
    final List<PExpense> expenses = [];
    final List<PExpense> splits = [];
    final List<PIncome> incomes = [];
    final List<PVault> vaults = [];
    final List<PDebt> debts = [];
    final List<PSettle> settlements = [];
    for (final entry in _readCache().values) {
      final String kind = (entry['kind'] ?? '').toString();
      final dynamic raw = entry['data'];
      if (raw is! Map) continue;
      final Map<String, dynamic> d = Map<String, dynamic>.from(raw);
      switch (kind) {
        case 'profile':
          name = (d['n'] ?? '').toString();
          currency = (d['c'] ?? '').toString();
          break;
        case 'expense':
          expenses.add(PExpense.fromData(d, split: false));
          break;
        case 'split':
          splits.add(PExpense.fromData(d, split: true));
          break;
        case 'income':
          incomes.add(PIncome.fromData(d));
          break;
        case 'vault':
          vaults.add(PVault.fromData(d));
          break;
        case 'debt':
          debts.add(PDebt.fromData(d));
          break;
        case 'settle':
          settlements.add(PSettle.fromData(d));
          break;
      }
    }
    expenses.sort((a, b) => b.date.compareTo(a.date));
    splits.sort((a, b) => b.date.compareTo(a.date));
    incomes.sort((a, b) => b.date.compareTo(a.date));
    debts.sort((a, b) => b.date.compareTo(a.date));
    settlements.sort((a, b) => b.date.compareTo(a.date));
    return PartnerData(
      name: (name == null || name.isEmpty) ? null : name,
      currency: (currency == null || currency.isEmpty) ? null : currency,
      expenses: expenses,
      splits: splits,
      incomes: incomes,
      vaults: vaults,
      debts: debts,
      settlements: settlements,
    );
  }

  // ------------------------------------------------------ pagos y saldo
  List<Map<String, dynamic>> get mySettlements {
    final dynamic raw = _box.get(_kSettlements);
    if (raw is! List) return [];
    return raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  /// Saldo en tu moneda local: positivo = tu pareja te debe; negativo = le debes.
  double balanceLocal(FinanceProvider finance, CurrencyProvider currency) {
    final String local = finance.localCurrency;
    double conv(double v, String c) => (c.isEmpty || c == local) ? v : currency.convert(v, c, local);
    final PartnerData p = partner;
    return coupleNetBalance(
      [
        for (final e in finance.sharedExpenses)
          SharedEntry(
            total: conv(e.sharedTotal ?? e.amount, e.currency),
            authorPart: conv(e.amount, e.currency),
            paidByAuthor: e.paidByCreator,
          ),
        for (final e in p.splits)
          SharedEntry(
            total: conv(e.total, e.currency),
            authorPart: conv(e.amount, e.currency),
            paidByAuthor: e.paidByAuthor,
            byMe: false,
          ),
      ],
      settlements: [
        for (final s in mySettlements)
          SettlementEntry(
            amount: conv((s['a'] as num).toDouble(), s['c'].toString()),
            paidByAuthor: s['pp'] == true,
          ),
        for (final s in p.settlements)
          SettlementEntry(amount: conv(s.amount, s.currency), paidByAuthor: s.paidByAuthor, byMe: false),
      ],
    );
  }

  Future<void> recordSettlement({
    required double amount,
    required String currency,
    required bool iPaid,
    required FinanceProvider finance,
  }) async {
    final List<Map<String, dynamic>> list = mySettlements
      ..add({
        'id': generateId(),
        'a': amount,
        'c': currency,
        'pp': iPaid,
        'd': DateTime.now().toIso8601String(),
      });
    await _box.put(_kSettlements, list);
    _partnerMemo = null;
    notifyListeners();
    await syncNow(finance);
  }

  // --------------------------------------------------------- conexión
  CoupleException _map(Object e) {
    if (e is CoupleException) return e;
    if (e is SupabaseException) {
      final String m = e.message.toLowerCase();
      if (m.contains('invalid code')) return const CoupleException(CoupleError.notFound);
      if (m.contains('couple is full')) return const CoupleException(CoupleError.full);
      return const CoupleException(CoupleError.other);
    }
    if (e is SocketException || e is TimeoutException || e is http.ClientException) {
      return const CoupleException(CoupleError.network);
    }
    return const CoupleException(CoupleError.other);
  }

  SupabaseSession? get _session => SupabaseSession.fromMap(_box.get(_kSession));

  Future<SupabaseSession> _ensureSession() async {
    final SupabaseRest api = _api!;
    SupabaseSession? s = _session;
    if (s != null && !s.expiresSoon) return s;
    if (s != null) {
      try {
        s = await api.refresh(s.refreshToken);
        await _box.put(_kSession, s.toMap());
        return s;
      } catch (_) {}
    }
    final SupabaseSession fresh = await api.signInAnonymously();
    await _box.put(_kSession, fresh.toMap());
    // Identidad nueva (p. ej. tras borrar los datos de la app): volver a unirse
    // a la pareja con el código guardado.
    final String? code = inviteCode;
    if (coupleId != null && code != null) {
      try {
        await api.rpc('join_couple', {'p_invite_hash': await inviteHash(code)}, fresh.accessToken);
      } catch (_) {}
    }
    return fresh;
  }

  Future<void> _saveLink({
    required String id,
    required String code,
    required List<int> key,
    required String name,
    required String workspace,
  }) async {
    await _box.put(_kId, id);
    await _box.put(_kCode, normalizeInviteCode(code));
    await _box.put(_kKey, base64Encode(key));
    await _box.put(_kName, name.trim());
    await _box.put(_kWorkspace, workspace);
    await _box.put(_kPrefs, const CouplePrefs().toMap());
    await _box.delete(_kPushed);
    await _box.delete(_kPushedUser);
    await _box.delete(_kCache);
    await _box.delete(_kLastPull);
    await _box.delete(_kLastSync);
    await _box.delete(_kMembers);
    _partnerMemo = null;
    _lastError = null;
    notifyListeners();
  }

  Future<void> createCouple({required String name, required FinanceProvider finance}) async {
    if (!isConfigured) throw const CoupleException(CoupleError.notConfigured);
    try {
      final String code = generateInviteCode();
      final SupabaseSession s = await _ensureSession();
      final dynamic id = await _api!.rpc('create_couple', {'p_invite_hash': await inviteHash(code)}, s.accessToken);
      final List<int> key = await deriveCoupleKey(code);
      await _saveLink(id: id.toString(), code: code, key: key, name: name, workspace: finance.activeWorkspaceId);
    } catch (e) {
      throw _map(e);
    }
    await syncNow(finance);
  }

  Future<void> joinCouple({required String code, required String name, required FinanceProvider finance}) async {
    if (!isConfigured) throw const CoupleException(CoupleError.notConfigured);
    if (!isValidInviteCode(code)) throw const CoupleException(CoupleError.invalidCode);
    try {
      final String normalized = normalizeInviteCode(code);
      final SupabaseSession s = await _ensureSession();
      final dynamic id = await _api!.rpc('join_couple', {'p_invite_hash': await inviteHash(normalized)}, s.accessToken);
      final List<int> key = await deriveCoupleKey(normalized);
      await _saveLink(id: id.toString(), code: normalized, key: key, name: name, workspace: finance.activeWorkspaceId);
    } catch (e) {
      throw _map(e);
    }
    await syncNow(finance);
  }

  /// Sincroniza si hay pareja vinculada y pasó al menos [minGap] desde la última vez.
  Future<void> syncIfLinked(FinanceProvider finance, {Duration minGap = const Duration(seconds: 60)}) async {
    final DateTime? last = lastSync;
    if (last != null && DateTime.now().difference(last) < minGap) return;
    await syncNow(finance);
  }

  Future<void> syncNow(FinanceProvider finance) async {
    if (!isLinked || _syncing || _api == null) return;
    if (workspaceId != finance.activeWorkspaceId) {
      notifyListeners();
      return;
    }
    _syncing = true;
    _lastError = null;
    notifyListeners();
    try {
      final SupabaseSession s = await _ensureSession();
      await _push(finance, s);
      await _pull(s);
      await _refreshMembers(s);
      await _box.put(_kLastSync, DateTime.now().toIso8601String());
    } catch (e) {
      _lastError = _map(e).error;
    } finally {
      _syncing = false;
      _partnerMemo = null;
      notifyListeners();
    }
  }

  // ----------------------------------------------------- qué se comparte
  Map<String, _Item> _desired(FinanceProvider finance) {
    final Map<String, _Item> out = {};
    final CouplePrefs p = prefs;
    out['profile:me'] = _Item('profile', {'n': displayName, 'c': finance.localCurrency});
    final DateTime since = DateTime.now().subtract(const Duration(days: 365));

    int count = 0;
    for (final e in finance.expenses) {
      if (e.sharedTotal != null) {
        // Gastos para dividir: siempre se comparten (así se marcaron).
        out['split:${e.id}'] = _Item('split', {
          'n': e.name,
          'a': e.amount,
          't': e.sharedTotal,
          'c': e.currency,
          'cat': e.category,
          'd': e.date.toIso8601String(),
          'pp': e.paidByCreator,
        });
      } else if (p.expenses && e.date.isAfter(since) && count < 2000) {
        count++;
        out['expense:${e.id}'] = _Item('expense', {
          'n': e.name,
          'a': e.amount,
          'c': e.currency,
          'cat': e.category,
          'd': e.date.toIso8601String(),
        });
      }
    }
    if (p.incomes) {
      for (final i in finance.incomes) {
        if (!i.date.isAfter(since)) continue;
        out['income:${i.id}'] = _Item('income', {
          'n': i.label,
          'a': i.amount,
          'c': i.currency,
          'd': i.date.toIso8601String(),
        });
      }
    }
    if (p.vaults) {
      for (final v in finance.vaults) {
        out['vault:${v.id}'] = _Item('vault', {
          'n': v.name,
          't': v.targetAmount,
          'cur': v.currentAmount,
          'c': v.currency,
        });
      }
    }
    if (p.debts) {
      for (final d in finance.debts) {
        out['debt:${d.id}'] = _Item('debt', {
          'p': d.person,
          'a': d.amount,
          'c': d.currency,
          'o': d.owedToMe,
          'd': d.date.toIso8601String(),
          'paid': d.paid,
          if (d.note != null && d.note!.isNotEmpty) 'note': d.note,
        });
      }
    }
    for (final s in mySettlements) {
      out['settle:${s['id']}'] = _Item('settle', {'a': s['a'], 'c': s['c'], 'pp': s['pp'], 'd': s['d']});
    }
    return out;
  }

  Map<String, String> _readPushed() {
    final dynamic raw = _box.get(_kPushed);
    final Map<String, String> out = {};
    if (raw is Map) raw.forEach((k, v) => out[k.toString()] = v.toString());
    return out;
  }

  Future<void> _push(FinanceProvider finance, SupabaseSession s, {bool removeAll = false}) async {
    final List<int> key = _keyBytes!;
    final String cid = coupleId!;
    Map<String, String> pushed = _readPushed();
    if (_box.get(_kPushedUser) != s.userId) pushed = {}; // identidad nueva: se vuelve a subir todo
    final Map<String, _Item> desired = removeAll ? {} : _desired(finance);

    final List<Map<String, dynamic>> rows = [];
    final Map<String, String> next = Map<String, String>.from(pushed);

    for (final e in desired.entries) {
      final String hash = changeHash(jsonEncode(e.value.data));
      if (pushed[e.key] == hash) continue;
      final SealedData sealed = await encryptJson({...e.value.data, 'k': e.key}, key);
      rows.add({
        'couple_id': cid,
        'id': '${s.userId}:${e.key}',
        'kind': e.value.kind,
        'payload': sealed.payload,
        'nonce': sealed.nonce,
        'deleted': false,
      });
      next[e.key] = hash;
    }
    // Lo que ya no se comparte (o se borró) se marca como borrado.
    for (final k in pushed.keys) {
      if (desired.containsKey(k)) continue;
      final SealedData sealed = await encryptJson({'k': k}, key);
      rows.add({
        'couple_id': cid,
        'id': '${s.userId}:$k',
        'kind': k.split(':').first,
        'payload': sealed.payload,
        'nonce': sealed.nonce,
        'deleted': true,
      });
      next.remove(k);
    }
    for (int i = 0; i < rows.length; i += 100) {
      await _api!.upsert('shared_items', rows.sublist(i, min(i + 100, rows.length)), 'couple_id,id', s.accessToken);
    }
    await _box.put(_kPushed, next);
    await _box.put(_kPushedUser, s.userId);
  }

  Future<void> _pull(SupabaseSession s) async {
    final List<int> key = _keyBytes!;
    final String cid = coupleId!;
    final Map<String, Map<String, dynamic>> cache = _readCache();
    final String? since = _box.get(_kLastPull) as String?;
    String? maxUpdated = since;
    int offset = 0;
    const int page = 500;
    while (offset < 20000) {
      final List<dynamic> rows = await _api!.select(
        'shared_items',
        {
          'select': 'id,kind,payload,nonce,deleted,updated_at',
          'couple_id': 'eq.$cid',
          'author_id': 'neq.${s.userId}',
          if (since != null) 'updated_at': 'gte.$since',
          'order': 'updated_at.asc,id.asc',
          'limit': '$page',
          'offset': '$offset',
        },
        s.accessToken,
      );
      for (final dynamic r in rows) {
        if (r is! Map) continue;
        final String updated = (r['updated_at'] ?? '').toString();
        if (updated.isNotEmpty && (maxUpdated == null || updated.compareTo(maxUpdated) > 0)) maxUpdated = updated;
        final Map<String, dynamic>? data =
            await decryptJson((r['payload'] ?? '').toString(), (r['nonce'] ?? '').toString(), key);
        final String? k = data?['k']?.toString();
        if (data == null || k == null) continue;
        if (r['deleted'] == true) {
          cache.remove(k);
        } else {
          cache[k] = {'kind': (r['kind'] ?? '').toString(), 'data': data, 'u': updated};
        }
      }
      if (rows.length < page) break;
      offset += page;
    }
    await _box.put(_kCache, cache);
    if (maxUpdated != null) await _box.put(_kLastPull, maxUpdated);
  }

  Future<void> _refreshMembers(SupabaseSession s) async {
    final List<dynamic> rows = await _api!.select(
      'couple_members',
      {'select': 'user_id', 'couple_id': 'eq.${coupleId!}'},
      s.accessToken,
    );
    await _box.put(_kMembers, rows.length);
  }

  // --------------------------------------------------------- ajustes
  Future<void> setShare(String what, bool value, FinanceProvider finance) async {
    final CouplePrefs p = prefs;
    final CouplePrefs next = switch (what) {
      'expenses' => p.copyWith(expenses: value),
      'incomes' => p.copyWith(incomes: value),
      'vaults' => p.copyWith(vaults: value),
      _ => p.copyWith(debts: value),
    };
    await _box.put(_kPrefs, next.toMap());
    notifyListeners();
    await syncNow(finance);
  }

  Future<void> setDisplayName(String name, FinanceProvider finance) async {
    await _box.put(_kName, name.trim());
    notifyListeners();
    await syncNow(finance);
  }

  /// Sale de la pareja: borra lo que compartías, deja de ser miembro y limpia
  /// los datos de tu pareja de este teléfono. Tus gastos no se tocan.
  Future<void> leave(FinanceProvider finance) async {
    if (!isLinked) return;
    try {
      final SupabaseSession s = await _ensureSession();
      if (workspaceId == finance.activeWorkspaceId) await _push(finance, s, removeAll: true);
      await _api!.delete(
        'couple_members',
        {'couple_id': 'eq.${coupleId!}', 'user_id': 'eq.${s.userId}'},
        s.accessToken,
      );
    } catch (e) {
      throw _map(e);
    }
    for (final k in [
      _kId, _kKey, _kCode, _kWorkspace, _kPrefs, _kPushed, _kPushedUser, _kCache,
      _kLastPull, _kLastSync, _kSettlements, _kMembers,
    ]) {
      await _box.delete(k);
    }
    _partnerMemo = null;
    _lastError = null;
    notifyListeners();
  }
}
