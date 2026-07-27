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

const Object _keep = Object();

/// State layar profil — hanya memegang future load (pola FutureBuilder lama).
class ProfilState {
  final Future<ProfileData>? future;

  const ProfilState({this.future});

  ProfilState copyWith({Object? future = _keep}) {
    return ProfilState(
      future: future == _keep ? this.future : future as Future<ProfileData>?,
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

  /// Dipicu sekali dari `didChangeDependencies` layar. Hanya memulai load bila
  /// future belum ada — mirror perilaku `_future ??= _load()`.
  void start() {
    if (state.future != null) return;
    state = state.copyWith(future: _load());
  }

  /// Tombol "Coba lagi" — pengganti `setState(() => _future = _load())`.
  void reload() {
    state = state.copyWith(future: _load());
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
      office: me['officeId']?.toString() ?? '-',
      role: roles.isNotEmpty ? roles.first.toString() : 'Relationship Manager',
      jabatan: me['jabatan']?.toString() ?? '',
      isConnect: me['isConnect'] == true,
    );
  }
}
