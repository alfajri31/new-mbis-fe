import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/presentation/screens/kelola_akun_screen.dart';
import 'package:mbis/core/providers/app_providers.dart';
import 'package:mbis/src/admin/account_repository.dart';
import 'package:mbis/src/auth/auth_session.dart';
import 'package:mbis/src/network/api_client.dart';

/// Penghapusan akun adalah aksi ketiga di Kelola Akun, setelah edit dan
/// nonaktifkan — fitur admin biasa, tapi tidak bisa dibatalkan.
///
/// Yang dikunci tes ini adalah pagar-pagarnya, bukan tampilannya:
///  - "Hapus akun" hanya muncul untuk akun yang SUDAH nonaktif (server pun
///    menolak akun aktif, jadi menampilkannya hanya akan memancing galat);
///  - akun sendiri tidak bisa dihapus;
///  - konfirmasi menuntut pengetikan ulang nama, bukan sekadar tombol "Ya".
///
/// Berlaku untuk mobile DAN web sekaligus: `kelola_akun_screen.dart` tidak punya
/// satu pun cabang `kIsWeb`, dan pemilihan chrome navigasi di MainScreen
/// digerakkan lebar layar (`Responsive.isWide`), bukan platform. Satu codebase,
/// satu perilaku.
class _FakeAccountRepository extends AccountRepository {
  _FakeAccountRepository(this.accounts) : super(apiClient: ApiClient());

  final List<AccountModel> accounts;
  final List<String> deleted = [];

  @override
  Future<List<AccountModel>> getAccounts() async => accounts;

  @override
  Future<List<OfficeOption>> getOffices() async => const [];

  @override
  Future<AccountDeletionResult> deleteAccount(String id) async {
    deleted.add(id);
    return const AccountDeletionResult(
      mode: 'ANONYMIZED',
      retainedBy: ['kunjungan'],
      message: 'Data pribadi akun dihapus permanen.',
    );
  }
}

/// Sesi admin yang sedang login. `id` dipakai layar untuk mengenali "akun Anda".
AuthSession _sesiAdmin(String userId) => AuthSession.fromJson({
      'accessToken': 'access-demo',
      'refreshToken': 'refresh-demo',
      'user': {
        'id': userId,
        'nip': 'ADMIN',
        'name': 'Admin Uji',
        'email': 'admin@mbis.local',
        'roles': ['ADMIN'],
      },
    });

AccountModel _akun({
  required String id,
  required String nama,
  required bool aktif,
}) =>
    AccountModel(
      id: id,
      nip: id,
      name: nama,
      email: '$id@contoh.invalid',
      roles: const ['RM'],
      active: aktif,
      authMethod: 'LOCAL',
    );

void main() {
  late _FakeAccountRepository repo;

  /// Merender layar lewat alur muat yang SEBENARNYA (initState -> start() ->
  /// fetch() -> repository), bukan dengan menyuntik state langsung — supaya yang
  /// diuji adalah jalur yang benar-benar dipakai aplikasi.
  Future<void> render(WidgetTester tester, List<AccountModel> accounts,
      {String currentUserId = 'ADMIN-LAIN'}) async {
    repo = _FakeAccountRepository(accounts);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        accountRepoProvider.overrideWithValue(repo),
        sessionProvider.overrideWith(() => SessionNotifier(_sesiAdmin(currentUserId))),
      ],
      child: const MaterialApp(home: KelolaAkunScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> bukaMenu(WidgetTester tester) async {
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
  }

  testWidgets('akun aktif tidak menawarkan Hapus — nonaktifkan dulu',
      (tester) async {
    await render(tester, [_akun(id: 'U1', nama: 'Budi Aktif', aktif: true)]);
    await bukaMenu(tester);

    expect(find.text('Nonaktifkan'), findsOneWidget);
    expect(find.text('Hapus akun'), findsNothing);
  });

  testWidgets('akun nonaktif menawarkan Hapus', (tester) async {
    await render(tester, [_akun(id: 'U2', nama: 'Siti Nonaktif', aktif: false)]);
    await bukaMenu(tester);

    expect(find.text('Aktifkan'), findsOneWidget);
    expect(find.text('Hapus akun'), findsOneWidget);
  });

  testWidgets('akun sendiri tidak bisa dihapus', (tester) async {
    await render(
      tester,
      [_akun(id: 'ME', nama: 'Admin Sendiri', aktif: false)],
      currentUserId: 'ME',
    );
    await bukaMenu(tester);

    // Entri tetap tampil (supaya admin paham kenapa), tapi dimatikan.
    final item = tester.widget<PopupMenuItem<String>>(
      find.widgetWithText(PopupMenuItem<String>, 'Hapus (akun Anda)'),
    );
    expect(item.enabled, isFalse);
  });

  testWidgets('konfirmasi menuntut ketik ulang nama sebelum menghapus',
      (tester) async {
    await render(tester, [_akun(id: 'U3', nama: 'Rina Hapus', aktif: false)]);
    await bukaMenu(tester);
    await tester.tap(find.text('Hapus akun'));
    await tester.pumpAndSettle();

    // Tombol mati sebelum nama diketik: penghapusan tidak bisa dibatalkan, dan
    // daftar akun kerap memuat nama yang mirip.
    final sebelum = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Hapus permanen'),
    );
    expect(sebelum.onPressed, isNull);

    // Nama yang salah pun tidak membuka tombolnya.
    await tester.enterText(find.byType(TextField).last, 'Rina');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Hapus permanen'))
          .onPressed,
      isNull,
    );
    expect(repo.deleted, isEmpty);

    // Nama persis → tombol hidup, dan repository benar-benar dipanggil.
    await tester.enterText(find.byType(TextField).last, 'Rina Hapus');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Hapus permanen'));
    await tester.pumpAndSettle();

    expect(repo.deleted, equals(['U3']));
  });
}
