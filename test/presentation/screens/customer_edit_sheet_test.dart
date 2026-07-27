import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/presentation/screens/customer_detail_screen.dart';
import 'package:mbis/src/assistant/assistant_repository.dart';
import 'package:mbis/src/customer/customer_repository.dart';
import 'package:mbis/src/network/api_client.dart';
import 'package:mbis/src/pipeline/pipeline_repository.dart';
import 'package:mbis/src/visit/visit_repository.dart';

/// BUG RM: membuka "Edit Customer" lalu menutupnya memunculkan layar merah
/// `'_dependents.isEmpty': is not true`. Penyebab kelas ini selalu sama —
/// sesuatu di dalam sheet dipakai setelah lepas dari widget tree (paling sering
/// TextEditingController yang dibuang tepat setelah `await`, sementara route
/// masih dianimasikan keluar dan masih di-rebuild beberapa frame).
///
/// Test ini menjalankan siklus buka → ubah → tutup dengan rebuild ekstra selama
/// animasi keluar (rotasi layar), yaitu kondisi yang memicunya di perangkat.
class _FakeCustomerRepository extends CustomerRepository {
  _FakeCustomerRepository({this.canEdit = true}) : super(apiClient: ApiClient());

  /// Server yang menentukan boleh-tidaknya menyunting (pembuat / RM pemegang).
  final bool canEdit;

  int updateCalls = 0;

  @override
  Future<CustomerDetailModel> getCustomerDetail(String id) async =>
      CustomerDetailModel(
        id: id,
        canEdit: canEdit,
        name: 'PT Uji Coba',
        npwp: '012345678901234',
        companyEmail: 'uji@contoh.id',
        companyPhone: '0211234567',
        address: 'Jl. Uji No. 1',
        picName: 'Budi',
        picPhone: '08123456789',
        picJabatan: 'Direktur',
        p3Count: 0,
        p2Count: 0,
        p1Count: 0,
        potential: 0,
        realization: 0,
      );

  /// Latensi jaringan nyata: di perangkat, `.then(...)` baru jalan setelah sheet
  /// benar-benar hilang — bukan pada frame berikutnya seperti fake instan.
  Duration updateDelay = Duration.zero;

  @override
  Future<void> updateCustomer(String id, Map<String, dynamic> data) async {
    updateCalls++;
    if (updateDelay > Duration.zero) await Future<void>.delayed(updateDelay);
  }
}

class _FakePipelineRepository extends PipelineRepository {
  _FakePipelineRepository() : super(apiClient: ApiClient());

  @override
  Future<List<PipelineListModel>> getPipelines({String? customerId}) async =>
      const [];
}

class _FakeAssistantRepository extends AssistantRepository {
  _FakeAssistantRepository() : super(apiClient: ApiClient());

  @override
  Future<List<SavedAiResult>> getSavedResults(String customerId) async =>
      const [];
}

class _FakeVisitRepository extends VisitRepository {
  _FakeVisitRepository() : super(apiClient: ApiClient());

  @override
  Future<List<VisitModel>> getCustomerVisits(
    String customerId, {
    bool ytd = true,
  }) async => const [];
}

void main() {
  late _FakeCustomerRepository customerRepo;

  Future<void> pumpScreen(WidgetTester tester, {bool canEdit = true}) async {
    customerRepo = _FakeCustomerRepository(canEdit: canEdit);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerRepoProvider.overrideWithValue(customerRepo),
          pipelineRepoProvider.overrideWithValue(_FakePipelineRepository()),
          assistantRepoProvider.overrideWithValue(_FakeAssistantRepository()),
          visitRepoProvider.overrideWithValue(_FakeVisitRepository()),
        ],
        child: const MaterialApp(
          home: CustomerDetailScreen(customerId: 'C-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('buka lalu batalkan Edit Customer — tanpa layar merah', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Edit Customer'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Customer'), findsOneWidget);

    // Tutup lewat tombol back (jalur yang dipakai user), lalu biarkan animasi
    // keluar berjalan sambil layar di-rebuild.
    Navigator.of(tester.element(find.text('Edit Customer'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('rotasi layar saat sheet menutup tidak memicu layar merah', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Edit Customer'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'PT Uji Coba'),
      'PT Uji Coba Ganti',
    );
    await tester.pump();

    // Simpan menutup sheet lalu memanggil update di belakang layar.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
    await tester.pump(); // mulai animasi keluar

    // Rotasi di tengah animasi keluar: memaksa rebuild pada subtree sheet yang
    // sedang dilepas — inilah pemicu yang dilaporkan di perangkat.
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(customerRepo.updateCalls, 1);
  });

  testWidgets(
    'Simpan dengan keyboard terbuka + latensi jaringan (alur di perangkat)',
    (tester) async {
      // Ukuran ponsel nyata, bukan 800x600 bawaan test.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await pumpScreen(tester);
      customerRepo.updateDelay = const Duration(milliseconds: 400);

      await tester.tap(find.byTooltip('Edit Customer'));
      await tester.pumpAndSettle();

      // Keyboard naik saat user mengetik di field.
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'PT Uji Coba'),
        'PT Uji Coba Ganti',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await tester.pump();

      // Keyboard turun BERSAMAAN dengan sheet menutup: sheet yang sedang dilepas
      // masih di-rebuild beberapa frame karena viewInsets berubah. Inilah kondisi
      // yang dilaporkan memunculkan layar merah.
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Tunggu update jaringan selesai + refresh diam-diam sesudahnya.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(customerRepo.updateCalls, 1);
      expect(find.text('Customer diperbarui'), findsOneWidget);
    },
  );

  testWidgets('tombol edit DISEMBUNYIKAN bila bukan pemilik customer', (
    tester,
  ) async {
    // Aturan: customer hanya bisa disunting oleh yang membuatnya / RM pemegang.
    // Atasan & admin tetap bisa MELIHAT, jadi layarnya terbuka normal — hanya
    // pensilnya yang tidak ada. Flag-nya dari server agar tombol dan gerbang
    // otorisasi tak bisa berbeda.
    await pumpScreen(tester, canEdit: false);

    expect(find.text('PT Uji Coba'), findsWidgets);
    expect(find.byTooltip('Edit Customer'), findsNothing);
  });
}
