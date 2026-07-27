import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/features/customer/data/repositories/customer_repository.dart';
import 'package:mbis/features/customer/domain/entities/customer.dart';
import 'package:mbis/features/customer/presentation/pages/customer_list_page.dart';
import 'package:mbis/features/customer/presentation/providers/customer_provider.dart';

/// Fake repository — membuktikan lapisan presentation bisa dites terisolasi dari
/// jaringan lewat override provider (jaring test pertama untuk App).
class _FakeCustomerRepository implements CustomerRepository {
  @override
  Future<List<Customer>> list() async => const [
        Customer(
            id: 'X1',
            name: 'PT Uji Widget',
            entityCategory: 'Swasta',
            state: 'ACTIVE',
            pipelineCount: 5),
      ];
}

void main() {
  testWidgets('CustomerListPage menampilkan data dari repository (mock)',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        customerRepositoryProvider.overrideWithValue(_FakeCustomerRepository()),
      ],
      child: const MaterialApp(home: CustomerListPage()),
    ));

    // Awal: loading (AsyncNotifier belum resolve).
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle(); // tunggu future repository selesai

    expect(find.text('PT Uji Widget'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Swasta · ACTIVE'), findsOneWidget);
  });
}
