import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'mock_catalog.dart';

Map<String, dynamic> _decode(String raw) => jsonDecode(raw) as Map<String, dynamic>;

/// Загружает реальный каталог (≈5000 позиций) из assets/data/catalog.json.
/// При любой ошибке остаются встроенные демо-данные.
Future<void> loadCatalogAsset() async {
  try {
    final raw = await rootBundle.loadString('assets/data/catalog.json');
    final data = await compute(_decode, raw);
    MockCatalog.replace(data);
  } catch (e) {
    debugPrint('Каталог из assets не загружен: $e');
  }
}
