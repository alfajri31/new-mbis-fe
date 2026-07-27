import '../../domain/entities/customer.dart';

/// Kontrak repository nasabah (lapisan `data`). Implementasi nyata = [ApiCustomerRepository],
/// mock untuk test/dev = [MockCustomerRepository]. UI hanya bergantung ke interface ini.
abstract class CustomerRepository {
  Future<List<Customer>> list();
}
