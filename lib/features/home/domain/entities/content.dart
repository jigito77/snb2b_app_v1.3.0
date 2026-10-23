import '../../../../core/utils/json_utils.dart';

class PromoBanner {
  const PromoBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    this.badge = '',
    this.color = 'navy',
    this.action = '/products',
  });

  final String id;
  final String title;
  final String subtitle;
  final String badge;

  /// navy | orange | teal
  final String color;

  /// Внутренний маршрут приложения, например `/products?isSpecial=true`.
  final String action;

  factory PromoBanner.fromJson(Json j) => PromoBanner(
        id: j.str('id'),
        title: j.str('title'),
        subtitle: j.str('subtitle'),
        badge: j.str('badge'),
        color: j.str('color', 'navy'),
        action: j.str('action', '/products'),
      );
}

class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    required this.date,
    required this.summary,
    this.body = '',
  });

  final String id;
  final String title;
  final DateTime date;
  final String summary;
  final String body;

  factory NewsItem.fromJson(Json j) => NewsItem(
        id: j.str('id'),
        title: j.str('title'),
        date: DateTime.tryParse(j.str('date'))?.toLocal() ?? DateTime.now(),
        summary: j.str('summary'),
        body: j.str('body'),
      );
}
