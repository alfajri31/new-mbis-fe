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

/// Regresi BUG RM: menekan "Simpan Pipeline" dengan isian wajib kosong dulu
/// hanya memunculkan snackbar umum ("Validation failed"-style) tanpa memberi
/// tahu APA yang kurang, sehingga user menekan berkali-kali sambil menebak.
///
/// Sekarang munculnya pop-up bawah yang MENYEBUT setiap isian wajib yang masih
/// kosong sekaligus — pola yang sama dengan notifikasi proses tender.
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
  Future<List<ParamRef>> parameters(String category) async => const [];

  @override
  Future<List<AgentRef>> agents() async => const [];
}

AuthSession _rmSession() => AuthSession.fromJson({
  'accessToken': 'access-123',
  'refreshToken': 'refresh-456',
  'user': {
    'id': 'U-1',
    'nip': '12345',
    'name': 'Budi',
    'email': 'budi@mbis.local',
    'roles': ['RM'],
  },
});

Future<void> _pumpScreen(WidgetTester tester) async {
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
}

void main() {
  testWidgets('pop-up bawah menyebut isian wajib yang masih kosong', (
    tester,
  ) async {
    await _pumpScreen(tester);

    final simpan = find.text('Simpan Pipeline');
    await tester.ensureVisible(simpan);
    await tester.pumpAndSettle();
    await tester.tap(simpan);
    await tester.pumpAndSettle();

    expect(find.textContaining('isian wajib belum lengkap'), findsOneWidget);
    // Nama isiannya disebut, bukan sekadar "ada yang kurang".
    expect(find.text('• Sumber Bisnis'), findsOneWidget);
  });

  testWidgets('status Tender: Nama Tender bertanda wajib & ikut dihitung', (
    tester,
  ) async {
    await _pumpScreen(tester);

    final tenderToggle = find.text('Tender');
    await tester.ensureVisible(tenderToggle);
    await tester.pumpAndSettle();
    await tester.tap(tenderToggle);
    await tester.pumpAndSettle();

    // BUG RM #1: label Nama Tender dulu tanpa bintang, padahal wajib diisi.
    // fieldLabel() mewarnai bintang di akhir label jadi merah.
    expect(find.text('Nama Tender *'), findsOneWidget);

    final simpan = find.text('Simpan Pipeline');
    await tester.ensureVisible(simpan);
    await tester.pumpAndSettle();
    await tester.tap(simpan);
    await tester.pumpAndSettle();

    // Sumber Bisnis, COB, TSI, Rate Premi, Nama Tender, 3 proses tender wajib
    // (tanggal kosong), dan Estimasi Closing = 9 isian.
    expect(find.text('9 isian wajib belum lengkap'), findsOneWidget);
    // Yang tak muat diringkas, bukan dibuang diam-diam.
    expect(find.text('• +5 lainnya'), findsOneWidget);
  });
}
