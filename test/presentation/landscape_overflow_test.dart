import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/core/providers/app_providers.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/presentation/screens/add_pipeline_screen.dart';
import 'package:mbis/src/auth/auth_session.dart';
import 'package:mbis/src/broker/broker_repository.dart';
import 'package:mbis/src/customer/customer_repository.dart';
import 'package:mbis/src/network/api_client.dart';
import 'package:mbis/src/reference/reference_repository.dart';
import 'package:mbis/src/referral/referral_repository.dart';

/// BUG RM: masih ada overflow saat layar landscape.
///
/// Landscape memangkas TINGGI layar (mis. 360dp), bukan lebarnya. Test ini
/// memasang ukuran landscape lalu memastikan tidak ada RenderFlex overflow —
/// pesan overflow Flutter otomatis menggagalkan widget test.
class _FakeCustomerRepository extends CustomerRepository {
  _FakeCustomerRepository() : super(apiClient: ApiClient());

  @override
  Future<List<CustomerListModel>> getCustomers() async => const [];
}

class _FakeBrokerRepository extends BrokerRepository {
  _FakeBrokerRepository() : super(apiClient: ApiClient());

  @override
  Future<List<BrokerModel>> getBrokerOptions() async => const [];
}

class _FakeReferralRepository extends ReferralRepository {
  _FakeReferralRepository() : super(apiClient: ApiClient());

  @override
  Future<List<BranchOffice>> branchOffices() async => const [];
}

class _FakeReferenceRepository extends ReferenceRepository {
  _FakeReferenceRepository() : super(apiClient: ApiClient());

  @override
  Future<List<ProductRef>> products() async => const [];

  @override
  Future<List<ParamRef>> parameters(String category) async => switch (category) {
    // INDIVIDU wajib ada: nilai default layar. Kalau tidak, dropdown-nya
    // memilih nilai di luar daftar opsi.
    'KERJA_SAMA' => [ParamRef('INDIVIDU', 'Individu'), ParamRef('KSO', 'KSO')],
    'BADAN_HUKUM' => [ParamRef('PT', 'PT')],
    'PROSES_TENDER' => [
      ParamRef('PENDAFTARAN_TENDER', 'Pendaftaran Tender'),
      ParamRef('SCORING_PENGUMUMAN', 'Scoring/Pengumuman'),
      ParamRef('WON_TENDER', 'Won'),
    ],
    _ => const <ParamRef>[],
  };

  @override
  Future<List<AgentRef>> agents() async => const [];
}

AuthSession _rmSession() => AuthSession.fromJson({
  'accessToken': 'a',
  'refreshToken': 'r',
  'user': {
    'id': 'U-1',
    'nip': '1',
    'name': 'Budi',
    'email': 'b@x.id',
    'roles': ['RM'],
  },
});

void main() {
  /// Ukuran khas ponsel dalam posisi landscape.
  const landscape = Size(800, 360);

  Future<void> setLandscape(WidgetTester tester) async {
    tester.view.physicalSize = landscape;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('Tambah Pipeline tidak overflow di landscape', (tester) async {
    await setLandscape(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => SessionNotifier(_rmSession())),
          customerRepoProvider.overrideWithValue(_FakeCustomerRepository()),
          brokerRepoProvider.overrideWithValue(_FakeBrokerRepository()),
          referralRepoProvider.overrideWithValue(_FakeReferralRepository()),
          referenceRepoProvider.overrideWithValue(_FakeReferenceRepository()),
        ],
        child: const MaterialApp(
          home: AddPipelineScreen(customerId: 'C-1', customerName: 'PT Uji'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Nyalakan Tender: menambah kartu proses tender — bagian paling padat.
    await tester.ensureVisible(find.text('Tender'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tender'));
    await tester.pumpAndSettle();

    // Gulir sampai bawah; overflow apa pun akan terlempar saat layout.
    await tester.ensureVisible(find.text('Simpan Pipeline'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('notifikasi isian wajib tidak overflow di landscape', (
    tester,
  ) async {
    await setLandscape(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => SessionNotifier(_rmSession())),
          customerRepoProvider.overrideWithValue(_FakeCustomerRepository()),
          brokerRepoProvider.overrideWithValue(_FakeBrokerRepository()),
          referralRepoProvider.overrideWithValue(_FakeReferralRepository()),
          referenceRepoProvider.overrideWithValue(_FakeReferenceRepository()),
        ],
        child: const MaterialApp(
          home: AddPipelineScreen(customerId: 'C-1', customerName: 'PT Uji'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Simpan Pipeline'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan Pipeline'));
    await tester.pumpAndSettle();

    expect(find.textContaining('isian wajib belum lengkap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
