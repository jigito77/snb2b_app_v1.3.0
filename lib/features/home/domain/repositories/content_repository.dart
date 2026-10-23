import '../entities/content.dart';

abstract class ContentRepository {
  Future<List<PromoBanner>> banners();

  Future<List<NewsItem>> news();

  Future<NewsItem> newsItem(String id);
}
