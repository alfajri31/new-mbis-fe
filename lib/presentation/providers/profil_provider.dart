import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/app_providers.dart';

/// Data profil RM — dipindah APA ADANYA dari `_ProfileData` privat di
/// `profil_screen.dart`. Dipublikkan agar bisa dipakai bersama notifier + layar.
class ProfileData {
  final String name;
  final String nip;
  final String email;
  final String office;
  final String role;
  final String jabatan;
  final bool isConnect;

  ProfileData({
    required this.name,
    required this.nip,
    required this.email,
    required this.office,
    required this.role,
    this.jabatan = '',
    this.isConnect = false,
  });

  /// Titel yang ditampilkan sebagai identitas utama: pakai jabatan asli bila ada
  /// (mis. "Business Head"), jika tidak jatuh ke role.
  String get displayTitle => jabatan.isNotEmpty ? jabatan : role;

  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

/// Nilai pertama yang bukan null/kosong, sebagai String. Null bila semuanya kosong.
String? _firstNonEmpty(Object? a, Object? b) {
  for (final v in [a, b]) {
    final s = v?.toString().trim();
    if (s != null && s.isNotEmpty) return s;
  }
  return null;
}

const Object _keep = Object();

/// State layar profil — memegang future load (pola FutureBuilder lama) beserta
/// pemilik sesi saat future itu dibuat.
class ProfilState {
  final Future<ProfileData>? future;

  /// Id pengguna yang sedang dimuat/termuat oleh [future]. Dipakai mendeteksi
  /// pergantian sesi; lihat [ProfilNotifier.start].
  final String? untukUserId;

  const ProfilState({this.future, this.untukUserId});

  ProfilState copyWith({Object? future = _keep, Object? untukUserId = _keep}) {
    return ProfilState(
      future: future == _keep ? this.future : future as Future<ProfileData>?,
      untukUserId:
          untukUserId == _keep ? this.untukUserId : untukUserId as String?,
    );
  }
}

final profilProvider =
    NotifierProvider<ProfilNotifier, ProfilState>(ProfilNotifier.new);

/// Menggantikan logika `setState` (data/loading) di `_ProfilScreenState`.
/// `_load` dipindah apa adanya; ApiClient kini dari [apiClientProvider]
/// (membawa sesi aktif, ekuivalen `ApiClient(session: MbisApp.of(context)...)`).
class ProfilNotifier extends Notifier<ProfilState> {
  @override
  ProfilState build() => const ProfilState();

  /// Dipicu dari `didChangeDependencies` layar. Memuat bila belum ada future,
  /// ATAU bila sesi sudah berganti pengguna sejak future itu dibuat.
  ///
  /// Pemeriksaan pengguna itu wajib: provider ini hidup selama proses aplikasi
  /// dan tidak pernah di-invalidate saat logout, jadi versi lama yang hanya
  /// menguji `future != null` membuat layar Profil terkunci pada pengguna
  /// PERTAMA yang login. Setelah berganti akun tanpa menutup aplikasi, Profil
  /// masih menampilkan nama, NIP, dan email pemilik sesi sebelumnya — sementara
  /// beranda sudah benar karena membaca sesi langsung.
  void start() {
    final userId = ref.read(sessionProvider)?.user.id;
    if (state.future != null && state.untukUserId == userId) return;
    state = ProfilState(future: _load(), untukUserId: userId);
  }

  /// Tombol "Coba lagi" — pengganti `setState(() => _future = _load())`.
  void reload() {
    state = ProfilState(
      future: _load(),
      untukUserId: ref.read(sessionProvider)?.user.id,
    );
  }

  Future<ProfileData> _load() async {
    final api = ref.read(apiClientProvider);
    final meRes = await api.get('/api/auth/me');
    if (meRes.statusCode != 200) {
      throw Exception('Gagal memuat profil');
    }
    final me = jsonDecode(meRes.body) as Map<String, dynamic>;

    final roles = (me['roles'] as List?)?.cast<dynamic>() ?? const [];

    return ProfileData(
      name: me['name'] ?? '-',
      nip: me['nip'] ?? '-',
      email: me['email'] ?? '-',
      // Nama kantornya, bukan kodenya: "KC-01" tidak berarti apa-apa bagi yang
      // membacanya. officeId hanya dipakai sebagai cadangan bila server lama
      // belum mengirim officeName, supaya kolomnya tidak mendadak kosong.
      office: _firstNonEmpty(me['officeName'], me['officeId']) ?? '-',
      role: roles.isNotEmpty ? roles.first.toString() : 'Relationship Manager',
      jabatan: me['jabatan']?.toString() ?? '',
      isConnect: me['isConnect'] == true,
    );
  }
}
