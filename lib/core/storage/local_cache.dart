import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../errors/app_exception.dart';

/// Лёгкий JSON-кэш поверх SharedPreferences: каталог, избранное, корзина,
/// последние просмотренные товары, история поиска. Токены здесь НЕ хранятся.
class LocalCache {
  LocalCache(this._prefs);

  final SharedPreferences _prefs;

  static const String _prefix = 'cache.';

  Future<void> putJson(String key, Object? value) async {
    await _prefs.setString('$_prefix$key', jsonEncode(value));
  }

  dynamic getJson(String key) {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String key) async {
    await _prefs.remove('$_prefix$key');
  }

  Future<void> clearPrefix(String keyPrefix) async {
    final keys = _prefs.getKeys().where((k) => k.startsWith('$_prefix$keyPrefix')).toList();
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }

  Future<void> clearAll() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }

  bool getBool(String key, {bool fallback = false}) =>
      _prefs.getBool('$_prefix$key') ?? fallback;

  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool('$_prefix$key', value);
  }

  /// Записывает значение в кэш группы, храня не более [max] ключей (вытесняются самые старые).
  Future<void> putBounded(String group, String key, Object? value, {int max = 40}) async {
    final indexKey = 'index.$group';
    final raw = getJson(indexKey);
    final index = raw is List ? raw.map((e) => e.toString()).toList() : <String>[];
    index.remove(key);
    index.add(key);
    while (index.length > max) {
      await remove(index.removeAt(0));
    }
    await putJson(key, value);
    await putJson(indexKey, index);
  }
}

class Cached<T> {
  const Cached(this.value, this.fromCache);

  final T value;
  final bool fromCache;
}

/// «Сеть → кэш»: пробует запрос, при отсутствии сети/ошибке сервера отдаёт последнюю
/// сохранённую версию. Кэшируется сырой JSON, поэтому форматы совпадают с API.
class CachedFetcher {
  CachedFetcher(this._cache);

  final LocalCache _cache;

  Future<Cached<T>> call<T>({
    required String key,
    required Future<dynamic> Function() request,
    required T Function(dynamic json) parse,
    String? group,
    int max = 40,
  }) async {
    dynamic json;
    try {
      json = await request();
    } on AppException catch (e) {
      if (e.isConnectivity) {
        final cached = _cache.getJson(key);
        if (cached != null) return Cached<T>(parse(cached), true);
      }
      rethrow;
    }
    if (group != null) {
      await _cache.putBounded(group, key, json, max: max);
    } else {
      await _cache.putJson(key, json);
    }
    return Cached<T>(parse(json), false);
  }
}
