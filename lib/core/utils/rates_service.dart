import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'currency.dart';

/// Курсы валют ЦБ РФ (JSON, без ключа API): https://www.cbr-xml-daily.ru/daily_json.js
class RatesService {
  RatesService._();

  static const String _urlMain = 'https://www.cbr-xml-daily.ru/daily_json.js';
  static const String _urlMirror = 'https://www.cbr-xml-daily.ru/latest.js';
  static const String _prefsKey = 'app.rates.v1';

  /// Загружает сохранённые курсы (мгновенно, без сети).
  static void loadCached(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _apply((j['rates'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble())), j['date'] as String?);
    } catch (_) {}
  }

  /// Скачивает свежие курсы. Возвращает true, если курсы обновились.
  static Future<bool> refresh(SharedPreferences prefs) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      responseType: ResponseType.plain,
    ));
    for (final url in <String>[_urlMain, _urlMirror]) {
      try {
        final res = await dio.get<String>(url);
        final j = jsonDecode(res.data ?? '') as Map<String, dynamic>;
        final valute = j['Valute'] as Map<String, dynamic>;
        final rates = <String, double>{};
        for (final c in AppCurrency.all) {
          if (c.code == 'RUB') continue;
          final v = valute[c.code] as Map<String, dynamic>?;
          if (v == null) continue;
          final value = (v['Value'] as num).toDouble();
          final nominal = (v['Nominal'] as num).toDouble();
          if (value > 0) rates[c.code] = nominal / value;
        }
        if (rates.length < 3) continue;
        final date = (j['Date'] as String?) ?? DateTime.now().toIso8601String();
        _apply(rates, date);
        await prefs.setString(_prefsKey, jsonEncode(<String, dynamic>{'rates': rates, 'date': date}));
        return true;
      } catch (e) {
        debugPrint('Курсы не загружены ($url): $e');
      }
    }
    return false;
  }

  static void _apply(Map<String, double> rates, String? date) {
    AppCurrency.rates
      ..clear()
      ..addAll(rates);
    AppCurrency.ratesDate = date;
  }
}
