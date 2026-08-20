import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/presentation/providers/kalkulator_premi_provider.dart';
import 'package:mbis/src/network/api_client.dart';
import 'package:mbis/src/premi/premi_rate_repository.dart';

/// Rate default Kalkulator Premi (MTR-2) di sisi state.
///
/// Yang dikunci di sini adalah tiga sifat yang menentukan apakah fitur ini aman
/// dipakai bersama-sama: peta rate ikut berubah tanpa perlu memuat ulang, kegagalan
/// memuat TIDAK mematikan kalkulator, dan kegagalan menyimpan TIDAK boleh senyap.
class _FakePremiRateRepository extends PremiRateRepository {
  _FakePremiRateRepository({
    this.gagalMuat = false,
    this.gagalTulis = false,
    Map<String, PremiRateDefault>? awal,
  })  : isi = {...?awal},
        super(apiClient: ApiClient());

  final bool gagalMuat;
  final bool gagalTulis;
  final Map<String, PremiRateDefault> isi;

  /// Berapa kali server benar-benar ditembak — inti pengujian penahan permintaan.
  int fetchCount = 0;

  /// Bila diisi, fetchAll menggantung sampai completer ini diselesaikan test.
  Completer<void>? tahan;

  @override
  Future<Map<String, PremiRateDefault>> fetchAll() async {
    fetchCount++;
    if (tahan != null) await tahan!.future;
    if (gagalMuat) throw Exception('jaringan mati');
    return {...isi};
  }

  @override
  Future<PremiRateDefault> save({
    required String slotKey,
    required double ratePercent,
    double? minRatePercent,
    String? productName,
    String? riskTier,
    String? jaminan,
    String? tenor,
  }) async {
    if (gagalTulis) throw Exception('403 bukan admin');
    final saved = PremiRateDefault(
      slotKey: slotKey,
      ratePercent: ratePercent,
      minRatePercent: minRatePercent,
      updatedByName: 'Admin Uji',
    );
    isi[slotKey] = saved;
    return saved;
  }

  @override
  Future<void> clear(String slotKey) async {
    if (gagalTulis) throw Exception('404 tidak ditemukan');
    isi.remove(slotKey);
  }
}

PremiRateDefault _rate(String slotKey, double persen, {double? min}) =>
    PremiRateDefault(slotKey: slotKey, ratePercent: persen, minRatePercent: min);

void main() {
  const slot = 'UMUM|Erection All Risk|-';

  test('Muat mengisi peta rate; defaultFor mengembalikan slot yang diminta', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = _FakePremiRateRepository(awal: {slot: _rate(slot, 3.5)});

    await container
        .read(kalkulatorPremiProvider.notifier)
        .loadRateDefaults(repo);

    final state = container.read(kalkulatorPremiProvider);
    expect(state.rateDefaultsLoading, isFalse);
    expect(state.defaultFor(slot)?.ratePercent, 3.5);
    expect(state.defaultFor('UMUM|Produk Lain|-'), isNull);
  });

  test('Gagal memuat tidak melempar — kalkulator tetap bisa dipakai manual', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(kalkulatorPremiProvider.notifier)
          .loadRateDefaults(_FakePremiRateRepository(gagalMuat: true)),
      completes,
    );

    final state = container.read(kalkulatorPremiProvider);
    expect(state.rateDefaultsLoading, isFalse);
    // Peta kosong = slot dianggap belum punya default → isian rate dikosongkan,
    // persis perilaku sebelum MTR-2.
    expect(state.rateDefaults, isEmpty);
    expect(state.defaultFor(slot), isNull);
  });

  test('Simpan memperbarui peta tanpa memuat ulang dari server', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(kalkulatorPremiProvider.notifier);
    final repo = _FakePremiRateRepository();

    await notifier.loadRateDefaults(repo);
    expect(container.read(kalkulatorPremiProvider).defaultFor(slot), isNull);

    await notifier.saveRateDefault(repo, slotKey: slot, ratePercent: 4.25);

    final saved = container.read(kalkulatorPremiProvider).defaultFor(slot);
    expect(saved?.ratePercent, 4.25);
    expect(saved?.updatedByName, 'Admin Uji');
  });

  test('Hapus mengeluarkan slot dari peta', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(kalkulatorPremiProvider.notifier);
    final repo = _FakePremiRateRepository(awal: {slot: _rate(slot, 3.5)});

    await notifier.loadRateDefaults(repo);
    await notifier.clearRateDefault(repo, slot);

    expect(container.read(kalkulatorPremiProvider).defaultFor(slot), isNull);
  });

  test('Gagal menyimpan/menghapus DILEMPARKAN — admin harus tahu', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(kalkulatorPremiProvider.notifier);
    final repo = _FakePremiRateRepository(
      gagalTulis: true,
      awal: {slot: _rate(slot, 3.5)},
    );
    await notifier.loadRateDefaults(repo);

    await expectLater(
      notifier.saveRateDefault(repo, slotKey: slot, ratePercent: 9),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      notifier.clearRateDefault(repo, slot),
      throwsA(isA<Exception>()),
    );

    // Peta tidak boleh ikut berubah saat servernya menolak.
    expect(container.read(kalkulatorPremiProvider).defaultFor(slot)?.ratePercent, 3.5);
  });

  group('Batas bawah rate', () {
    // Kolom "Selected Rate" pada sheet Rate Produk = rate minimum yang boleh
    // ditawarkan. Aturan ini yang mematikan ekspor dokumen di kalkulator, jadi
    // salah tanda pembanding di sini berarti proforma di bawah batas bisa terbit.
    test('Di bawah batas = melanggar; tepat di batas & di atasnya = boleh', () {
      final def = _rate(slot, 0.30, min: 0.25);

      expect(def.melanggarBatasBawah(0.24), isTrue);
      expect(def.melanggarBatasBawah(0.2499), isTrue);
      expect(def.melanggarBatasBawah(0.25), isFalse, reason: 'tepat di batas boleh');
      expect(def.melanggarBatasBawah(0.30), isFalse);
      expect(def.melanggarBatasBawah(9), isFalse);
    });

    test('Slot tanpa batas bawah tidak pernah melanggar', () {
      final def = _rate(slot, 0.30);
      expect(def.melanggarBatasBawah(0.0001), isFalse);
      expect(def.melanggarBatasBawah(0), isFalse);
    });

    test('Rate kosong (belum diketik) bukan pelanggaran', () {
      // Isian kosong berarti user belum memutuskan apa-apa; menandainya merah
      // sejak awal hanya membuat layar terlihat rusak saat baru dibuka.
      expect(_rate(slot, 0.30, min: 0.25).melanggarBatasBawah(null), isFalse);
    });

    test('Batas bawah ikut terbaca dari JSON backend', () {
      final item = PremiRateDefault.fromJson({
        'slotKey': slot,
        'ratePercent': 0.30,
        'minRatePercent': 0.25,
      });
      expect(item.minRatePercent, 0.25);
      // minRatePercent tidak dikirim = slot tanpa batas bawah, BUKAN nol persen.
      final tanpa = PremiRateDefault.fromJson({
        'slotKey': slot,
        'ratePercent': 0.30,
      });
      expect(tanpa.minRatePercent, isNull);
      expect(tanpa.melanggarBatasBawah(0.0001), isFalse);
    });

    test('Batas bawah tersimpan lewat provider', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(kalkulatorPremiProvider.notifier);
      final repo = _FakePremiRateRepository();
      await notifier.loadRateDefaults(repo);

      await notifier.saveRateDefault(repo,
          slotKey: slot, ratePercent: 0.30, minRatePercent: 0.25);

      expect(container.read(kalkulatorPremiProvider).defaultFor(slot)?.minRatePercent,
          0.25);
    });
  });

  group('Penahan permintaan ke server', () {
    // Layar kalkulator memanggil loadRateDefaults tiap kali dibuka. Tanpa penahan,
    // buka-tutup layar N kali = N request untuk data yang berubah beberapa kali
    // setahun. Pemeriksaan batas bawah sendiri TIDAK menyentuh server sama sekali —
    // ia membaca peta yang sudah dimuat ini.
    test('Pemanggilan berikutnya dalam masa segar tidak menembak server lagi', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(kalkulatorPremiProvider.notifier);
      final repo = _FakePremiRateRepository(awal: {slot: _rate(slot, 3.5)});

      await notifier.loadRateDefaults(repo);
      await notifier.loadRateDefaults(repo);
      await notifier.loadRateDefaults(repo);

      expect(repo.fetchCount, 1);
      // Datanya tetap ada — dilewati bukan berarti kosong.
      expect(container.read(kalkulatorPremiProvider).defaultFor(slot)?.ratePercent, 3.5);
    });

    test('force melewati penahan', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(kalkulatorPremiProvider.notifier);
      final repo = _FakePremiRateRepository();

      await notifier.loadRateDefaults(repo);
      await notifier.loadRateDefaults(repo, force: true);

      expect(repo.fetchCount, 2);
    });

    test('Setelah masa segar lewat, diambil ulang', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(kalkulatorPremiProvider.notifier);
      final repo = _FakePremiRateRepository();

      var sekarang = DateTime(2026, 8, 20, 10);
      notifier.now = () => sekarang;

      await notifier.loadRateDefaults(repo);
      sekarang = sekarang.add(KalkulatorPremiNotifier.rateDefaultsTtl -
          const Duration(seconds: 1));
      await notifier.loadRateDefaults(repo);
      expect(repo.fetchCount, 1, reason: 'masih dalam masa segar');

      sekarang = sekarang.add(const Duration(seconds: 2));
      await notifier.loadRateDefaults(repo);
      expect(repo.fetchCount, 2, reason: 'masa segar sudah lewat');
    });

    test('Dua pemicu berdekatan hanya menghasilkan satu request', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(kalkulatorPremiProvider.notifier);
      final repo = _FakePremiRateRepository()..tahan = Completer<void>();

      final a = notifier.loadRateDefaults(repo);
      final b = notifier.loadRateDefaults(repo);
      expect(repo.fetchCount, 1, reason: 'yang kedua ikut menumpang yang berjalan');

      repo.tahan!.complete();
      await Future.wait([a, b]);
      expect(repo.fetchCount, 1);
    });

    test('Gagal memuat tidak menyegel penahan — pembukaan berikutnya mencoba lagi',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(kalkulatorPremiProvider.notifier);
      final repo = _FakePremiRateRepository(gagalMuat: true);

      await notifier.loadRateDefaults(repo);
      await notifier.loadRateDefaults(repo);

      // Kalau kegagalan ikut mencatat "baru saja dimuat", kalkulator akan tetap
      // kosong selama TTL walaupun jaringan sudah pulih.
      expect(repo.fetchCount, 2);
      expect(container.read(kalkulatorPremiProvider).rateDefaultsLoadedAt, isNull);
    });
  });

  test('Waktu UTC tanpa penanda zona dibaca sebagai UTC, bukan waktu lokal', () {
    // Backend mengirim LocalDateTime UTC tanpa 'Z'; tanpa penanganan khusus,
    // "diperbarui" tampil mundur sebesar offset zona perangkat.
    final item = PremiRateDefault.fromJson({
      'slotKey': slot,
      'ratePercent': 3.5,
      'updatedAt': '2026-08-20T09:02:30.535744',
    });

    expect(item.updatedAt, isNotNull);
    expect(
      item.updatedAt!.toUtc(),
      DateTime.utc(2026, 8, 20, 9, 2, 30, 535, 744),
    );
  });
}
