import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/presentation/screens/customer_detail_screen.dart';
import 'package:mbis/src/assistant/assistant_repository.dart';
import 'package:mbis/src/bumn/bumn_repository.dart';
import 'package:mbis/src/customer/customer_repository.dart';
import 'package:mbis/src/network/api_client.dart';
import 'package:mbis/src/pipeline/pipeline_repository.dart';
import 'package:mbis/src/reference/reference_repository.dart';
import 'package:mbis/src/visit/visit_repository.dart';

/// Edit customer memakai layar formulir yang SAMA dengan alur tambah
/// (AddCustomerScreen dalam mode edit), menggantikan bottom-sheet lama yang
/// hanya memuat identitas & PIC.
///
/// Yang dijaga di sini: formulirnya benar-benar terisi dari data tersimpan, dan
/// yang dikirim saat Simpan adalah payload LENGKAP — termasuk field yang dulu
/// tidak ada di sheet (badan hukum, entitas, kategori, HVC). Kalau payloadnya
/// menyusut lagi, pemakai akan melihat field yang bisa diisi tapi diam-diam
/// tidak tersimpan, persis keluhan yang memicu perubahan ini.
class _FakeCustomerRepository extends CustomerRepository {
  _FakeCustomerRepository({this.canEdit = true}) : super(apiClient: ApiClient());

  /// Server yang menentukan boleh-tidaknya menyunting (pembuat / RM pemegang).
  final bool canEdit;

  int updateCalls = 0;
  Map<String, dynamic>? lastPayload;

  @override
  Future<CustomerDetailModel> getCustomerDetail(String id) async =>
      CustomerDetailModel(
        id: id,
        canEdit: canEdit,
        name: 'PT Uji Coba',
        legalEntity: 'PT',
        entityCategory: 'SWASTA',
        category: 'NON_PERBANKAN',
        isHvc: true,
        npwp: '012345678901234',
        nib: '1234567890123',
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

  @override
  Future<void> updateCustomer(String id, Map<String, dynamic> data) async {
    updateCalls++;
    lastPayload = data;
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

/// Opsi dropdown formulir. Tanpa ini layar edit memanggil backend sungguhan.
class _FakeReferenceRepository extends ReferenceRepository {
  _FakeReferenceRepository() : super(apiClient: ApiClient());

  @override
  Future<List<ParamRef>> parameters(String category) async {
    switch (category) {
      case 'BADAN_HUKUM':
        return [ParamRef('PT', 'PT'), ParamRef('CV', 'CV')];
      case 'ENTITY_CATEGORY':
        return [
          ParamRef('SWASTA', 'Swasta'),
          ParamRef('PERSEORANGAN', 'Perseorangan'),
        ];
      case 'PIC_TITLE':
        return [ParamRef('BAPAK', 'Bapak')];
      default:
        return const [];
    }
  }

  @override
  Future<List<BankRef>> banks({String? type}) async => const [];
}

class _FakeBumnRepository extends BumnRepository {
  _FakeBumnRepository() : super(apiClient: ApiClient());

  @override
  Future<List<BumnOption>> getBumnOptions() async => const [];
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
          referenceRepoProvider.overrideWithValue(_FakeReferenceRepository()),
          bumnRepoProvider.overrideWithValue(_FakeBumnRepository()),
        ],
        child: const MaterialApp(
          home: CustomerDetailScreen(customerId: 'C-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Edit membuka formulir penuh yang sudah terisi', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Edit Customer'));
    await tester.pumpAndSettle();

    // Judul layar, bukan judul sheet.
    expect(find.widgetWithText(AppBar, 'Edit Customer'), findsOneWidget);
    // Field yang dulu ada di sheet…
    expect(find.text('PT Uji Coba'), findsWidgets);
    expect(find.text('Budi'), findsWidgets);
    // …dan yang dulu TIDAK ada sama sekali. Label wajib dirender Text.rich
    // (bintangnya merah), jadi pencariannya harus menyertakan rich text.
    expect(
      find.textContaining('Entitas Customer', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Badan Hukum', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Status HVC'), findsOneWidget);
    // Dokumen dikelola di layar detail, jadi tidak ikut di mode edit.
    expect(find.text('Dokumen'), findsNothing);
  });

  testWidgets('Simpan mengirim payload lengkap, bukan sebagian field', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Edit Customer'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'PT Uji Coba'),
      'PT Uji Coba Ganti',
    );
    await tester.pumpAndSettle();

    final simpan = find.widgetWithText(ElevatedButton, 'Simpan Perubahan');
    await tester.ensureVisible(simpan); // tombol ada di dasar formulir panjang
    await tester.pumpAndSettle();
    await tester.tap(simpan);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(customerRepo.updateCalls, 1);
    final payload = customerRepo.lastPayload!;
    expect(payload['name'], 'PT Uji Coba Ganti');
    // Field-field inilah yang dulu tidak pernah terkirim dari sheet edit.
    expect(payload['legalEntity'], 'PT');
    expect(payload['entityCategory'], 'SWASTA');
    expect(payload['category'], 'NON_PERBANKAN');
    expect(payload['isHvc'], true);
    expect(payload['picName'], 'Budi');
  });

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
