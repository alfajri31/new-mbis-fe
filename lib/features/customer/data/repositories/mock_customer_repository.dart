import '../../domain/entities/customer.dart';
import 'customer_repository.dart';

/// Mock untuk test/dev offline — dipakai lewat override provider (tanpa backend).
class MockCustomerRepository implements CustomerRepository {
  @override
  Future<List<Customer>> list() async => const [
        Customer(
            id: 'C1',
            name: 'PT Contoh Satu',
            entityCategory: 'Swasta',
            state: 'ACTIVE',
            pipelineCount: 3),
        Customer(
            id: 'C2',
            name: 'PT Contoh Dua',
            entityCategory: 'BUMN',
            state: 'ACTIVE',
            pipelineCount: 1),
      ];
}
