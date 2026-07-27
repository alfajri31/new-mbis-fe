import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mbis/core/providers/app_providers.dart';

import '../../data/repositories/api_customer_repository.dart';
import '../../data/repositories/customer_repository.dart';
import '../../domain/entities/customer.dart';

/// Repository nasabah — kini memakai API asli backend lewat [apiClientProvider]
/// (Fase 0 wiring). Di test di-override dengan mock (lihat widget test), sehingga
/// lapisan presentation tetap bisa dites tanpa jaringan.
final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => ApiCustomerRepository(ref.watch(apiClientProvider)),
);

/// State daftar nasabah (loading/error/data dibungkus [AsyncValue]) — ganti `setState`.
final customerListProvider =
    AsyncNotifierProvider<CustomerListNotifier, List<Customer>>(
        CustomerListNotifier.new);

class CustomerListNotifier extends AsyncNotifier<List<Customer>> {
  @override
  Future<List<Customer>> build() =>
      ref.read(customerRepositoryProvider).list();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(customerRepositoryProvider).list());
  }
}
