enum ErrorKind { network, server, unauthorized, notFound, validation, outOfStock, unknown }

/// Единый тип ошибок приложения. Все слои выше data работают только с ним.
class AppException implements Exception {
  const AppException(this.kind, this.message, {this.statusCode});

  const AppException.network()
      : this(ErrorKind.network, 'Проверьте подключение к интернету.');

  const AppException.server({int? statusCode})
      : this(ErrorKind.server, 'Не удалось загрузить данные. Попробуйте позже.',
            statusCode: statusCode);

  const AppException.unauthorized()
      : this(ErrorKind.unauthorized, 'Сессия истекла. Войдите снова.', statusCode: 401);

  const AppException.notFound()
      : this(ErrorKind.notFound, 'Данные не найдены.', statusCode: 404);

  const AppException.outOfStock()
      : this(ErrorKind.outOfStock, 'Товар временно отсутствует.');

  const AppException.validation(String message, {int? statusCode})
      : this(ErrorKind.validation, message, statusCode: statusCode);

  const AppException.unknown()
      : this(ErrorKind.unknown, 'Не удалось загрузить данные. Попробуйте позже.');

  final ErrorKind kind;
  final String message;
  final int? statusCode;

  bool get isConnectivity => kind == ErrorKind.network || kind == ErrorKind.server;

  @override
  String toString() => message;
}

/// Человекочитаемое сообщение для любой ошибки.
String errorMessage(Object error) {
  if (error is AppException) return error.message;
  return const AppException.unknown().message;
}

bool isNetworkError(Object error) => error is AppException && error.kind == ErrorKind.network;
