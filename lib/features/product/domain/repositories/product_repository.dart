import '../entities/product.dart';

abstract class ProductRepository {
  Future<Product> product(String id);

  Future<List<Product>> analogs(String id);
}
