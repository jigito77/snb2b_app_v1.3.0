import '../../../core/network/api_client.dart';
import '../../../core/storage/local_cache.dart';
import '../../../core/utils/json_utils.dart';
import '../../auth/domain/entities/user.dart';
import '../domain/entities/address.dart';
import '../domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(ApiClient api, LocalCache cache)
      : _api = api,
        _cache = cache,
        _fetch = CachedFetcher(cache);

  final ApiClient _api;
  final LocalCache _cache;
  final CachedFetcher _fetch;

  @override
  Future<AppUser> updateProfile({String? name, String? phone, Company? company}) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (company != null) 'company': company.toJson(),
    };
    final json = await _api.put('/api/profile', body: body);
    final user = AppUser.fromJson(asJson(json));
    await _cache.putJson('user', user.toJson());
    return user;
  }

  @override
  Future<List<Address>> addresses() async {
    final result = await _fetch<List<Address>>(
      key: 'addresses',
      request: () => _api.get('/api/profile/addresses'),
      parse: (json) => asJson(json).list('items').map(Address.fromJson).toList(),
    );
    return result.value;
  }

  @override
  Future<Address> saveAddress(Address address) async {
    final dynamic json;
    if (address.id.isEmpty) {
      json = await _api.post('/api/profile/addresses', body: address.toJson());
    } else {
      json = await _api.put('/api/profile/addresses/${address.id}', body: address.toJson());
    }
    return Address.fromJson(asJson(json));
  }

  @override
  Future<void> deleteAddress(String id) async {
    await _api.delete('/api/profile/addresses/$id');
  }
}
