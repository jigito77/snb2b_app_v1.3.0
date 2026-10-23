import '../../../auth/domain/entities/user.dart';
import '../entities/address.dart';

abstract class ProfileRepository {
  Future<AppUser> updateProfile({String? name, String? phone, Company? company});

  Future<List<Address>> addresses();

  Future<Address> saveAddress(Address address);

  Future<void> deleteAddress(String id);
}
