import '../../../core/network/api_client.dart';
import '../../../core/storage/local_cache.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/entities/content.dart';
import '../domain/repositories/content_repository.dart';

class ContentRepositoryImpl implements ContentRepository {
  ContentRepositoryImpl(ApiClient api, LocalCache cache)
      : _api = api,
        _fetch = CachedFetcher(cache);

  final ApiClient _api;
  final CachedFetcher _fetch;

  @override
  Future<List<PromoBanner>> banners() async {
    final result = await _fetch<List<PromoBanner>>(
      key: 'banners',
      request: () => _api.get('/api/banners'),
      parse: (json) => asJson(json).list('items').map(PromoBanner.fromJson).toList(),
    );
    return result.value;
  }

  @override
  Future<List<NewsItem>> news() async {
    final result = await _fetch<List<NewsItem>>(
      key: 'news',
      request: () => _api.get('/api/news'),
      parse: (json) => asJson(json).list('items').map(NewsItem.fromJson).toList(),
    );
    return result.value;
  }

  @override
  Future<NewsItem> newsItem(String id) async {
    final result = await _fetch<NewsItem>(
      key: 'news:$id',
      group: 'news_item',
      max: 20,
      request: () => _api.get('/api/news/$id'),
      parse: (json) => NewsItem.fromJson(asJson(json)),
    );
    return result.value;
  }
}
