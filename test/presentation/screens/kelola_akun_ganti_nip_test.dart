import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/core/providers/app_providers.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/presentation/screens/kelola_akun_screen.dart';
import 'package:mbis/src/admin/account_repository.dart';
import 'package:mbis/src/auth/auth_session.dart';
import 'package:mbis/src/network/api_client.dart';

/// NIP adalah identitas login, dan sebelumnya field-nya dikunci saat edit
/// sehingga NIP yang salah ketik hanya bisa dibetulkan lewat migrasi basis data.
/// Sekarang boleh diubah dari Kelola Akun.
///
/// Yang dikunci tes ini bukan tampilannya, melainkan bahwa nilainya benar-benar
/// SAMPAI ke repository: field yang terbuka tapi tidak ikut terkirim pada
/// panggilan simpan akan terlihat berhasil di layar padahal tidak mengubah apa
/// pun — kegagalan yang paling mahal untuk disadari belakangan.
class _FakeAccountRepository extends AccountRepository {
  _FakeAccountRepository(this.accounts) : super(apiClient: ApiClient());

  final List<AccountModel> accounts;

  /// Argumen panggilan updateAccount terakhir.
  String? updatedId;
  String? updatedNip;
  String? updatedName;

  @override
  Future<List<AccountModel>> getAccounts() async => accounts;

  @override
  Future<List<OfficeOption>> getOffices() async => const [];

  @override
  Future<void> updateAccount(
    String id, {
    String? nip,
    String? name,
    String? email,
    String? officeId,
    String? password,
    List<String>? roles,
    bool? active,
    bool? isConnect,
  }) async {
    updatedId = id;
    updatedNip = nip;
    updatedName = name;
  }
}

AuthSession _sesiAdmin() => AuthSession.fromJson({
      'accessToken': 'access-demo',
      'refreshToken': 'refresh-demo',
      'user': {
        'id': 'ADMIN-LAIN',
        'nip': 'ADMIN',
        'name': 'Admin Uji',
        'email': 'admin@mbis.local',
        'roles': ['ADMIN'],
      },
    });

AccountModel _akun() => AccountModel(
      id: 'U1',
      nip: '1351',
      name: 'Aven Deselfino M',
      email: 'aven@contoh.invalid',
      roles: ['RM'],
      active: true,
      authMethod: 'LOCAL',
    );

void main() {
  late _FakeAccountRepository repo;

  Future<void> bukaFormEdit(WidgetTester tester) async {
    repo = _FakeAccountRepository([_akun()]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        accountRepoProvider.overrideWithValue(repo),
        sessionProvider.overrideWith(() => SessionNotifier(_sesiAdmin())),
      ],
      child: const MaterialApp(home: KelolaAkunScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
  }

  /// Field NIP adalah isian pertama di dalam Form milik sheet edit. Dicari lewat
  /// Form supaya kotak pencarian di layar belakangnya tidak ikut terjaring.
  Finder fieldNip() => find
      .descendant(of: find.byType(Form), matching: find.byType(TextFormField))
      .first;

  /// Tombol Simpan ada di ujung bawah sheet dan di luar area terlihat pada
  /// ukuran layar tes; tanpa digulirkan dulu, tap-nya tidak mengenai apa pun dan
  /// tes gagal seolah-olah simpannya yang rusak.
  Future<void> tekanSimpan(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Simpan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
  }

  testWidgets('field NIP bisa diisi saat edit, tidak lagi dikunci',
      (tester) async {
    await bukaFormEdit(tester);

    expect(find.text('Edit Akun'), findsOneWidget);
    expect(tester.widget<TextFormField>(fieldNip()).enabled, isNot(false));
    // Nilai sekarang ditampilkan supaya admin tahu apa yang sedang diubah.
    expect(find.text('1351'), findsOneWidget);
  });

  testWidgets('NIP baru ikut terkirim ke repository saat disimpan',
      (tester) async {
    await bukaFormEdit(tester);

    await tester.enterText(fieldNip(), '1350');
    await tester.pumpAndSettle();
    await tekanSimpan(tester);

    expect(repo.updatedId, equals('U1'));
    expect(repo.updatedNip, equals('1350'));
    // Field lain tetap terkirim seperti sebelumnya.
    expect(repo.updatedName, equals('Aven Deselfino M'));
  });

  testWidgets('NIP dikosongkan ditolak sebelum menyentuh repository',
      (tester) async {
    await bukaFormEdit(tester);

    await tester.enterText(fieldNip(), '   ');
    await tester.pumpAndSettle();
    await tekanSimpan(tester);

    expect(find.text('Wajib diisi'), findsOneWidget);
    expect(repo.updatedId, isNull);
  });
}
