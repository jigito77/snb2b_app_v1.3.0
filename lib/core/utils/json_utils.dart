typedef Json = Map<String, dynamic>;

/// Безопасное приведение произвольного decoded-JSON к Map<String, dynamic>.
Json asJson(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('Ожидался JSON-объект');
}

/// Список объектов из decoded-JSON (null → пустой список).
List<Json> asJsonList(dynamic value) {
  if (value is! List) return <Json>[];
  return value.map<Json>((dynamic e) => asJson(e)).toList();
}

extension JsonReader on Map<String, dynamic> {
  String str(String key, [String fallback = '']) {
    final v = this[key];
    return v == null ? fallback : v.toString();
  }

  String? strOrNull(String key) {
    final v = this[key];
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  int integer(String key, [int fallback = 0]) {
    final v = this[key];
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  double dbl(String key, [double fallback = 0]) {
    final v = this[key];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? fallback;
  }

  double? dblOrNull(String key) {
    final v = this[key];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  bool flag(String key) => this[key] == true;

  List<Json> list(String key) => asJsonList(this[key]);

  List<String> strings(String key) {
    final v = this[key];
    if (v is! List) return <String>[];
    return v.map<String>((dynamic e) => e.toString()).toList();
  }

  Json? obj(String key) {
    final v = this[key];
    return v is Map ? Map<String, dynamic>.from(v) : null;
  }
}
