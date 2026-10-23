/// Абстракция транспортного слоя. Репозитории знают только про этот интерфейс,
/// поэтому Mock API и реальный backend взаимозаменяемы (см. app/di.dart).
///
/// Пути указываются полностью, например `/api/products`.
abstract class ApiClient {
  Future<dynamic> get(String path, {Map<String, dynamic>? query});

  Future<dynamic> post(String path, {dynamic body, bool skipAuth = false});

  Future<dynamic> put(String path, {dynamic body});

  Future<dynamic> delete(String path);

  /// Загрузка одного файла «сырым» телом (как на сайте и в админке: один файл — один запрос).
  /// [uploadId] делает повтор запроса безопасным: сервер не создаёт дубликат.
  Future<dynamic> upload(
    String path, {
    required Stream<List<int>> data,
    required int length,
    required String contentType,
    required String fileName,
    required String uploadId,
    void Function(int sent, int total)? onProgress,
  });
}
