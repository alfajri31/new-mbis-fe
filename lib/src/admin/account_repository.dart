import 'dart:convert';
import '../network/api_client.dart';

/// Hasil penghapusan akun. Mencerminkan `UserDeletionResponse` di backend.
///
/// Penghapusan berjalan dua mode karena catatan wajib arsip (pipeline, kunjungan,
/// serah terima RM) merujuk ke akun lewat foreign key NOT NULL:
///  - `HARD_DELETE` — akun tidak pernah dipakai, barisnya benar-benar dibuang;
///  - `ANONYMIZED`  — data pribadi dimusnahkan, catatan bisnis tetap ada tanpa
///    lagi menunjuk ke identitas siapa pun. [retainedBy] menyebut penahannya.
class AccountDeletionResult {
  final String mode;
  final List<String> retainedBy;
  final String message;

  const AccountDeletionResult({
    required this.mode,
    required this.retainedBy,
    required this.message,
  });

  bool get isHardDelete => mode == 'HARD_DELETE';

  factory AccountDeletionResult.fromJson(Map<String, dynamic> j) =>
      AccountDeletionResult(
        mode: j['mode']?.toString() ?? 'ANONYMIZED',
        retainedBy: (j['retainedBy'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        message: j['message']?.toString() ?? 'Akun dihapus.',
      );
}

/// A user/account row for the admin "Kelola Akun" screen.
/// Mirrors AdminUserSummaryResponse / AdminUserDetailResponse on the backend.
class AccountModel {
  final String id;
  final String nip;
  final String name;
  final String email;
  final String? officeId;
  final String? officeName;
  final List<String> roles;
  final bool active;
  final String? agentCif;
  final String authMethod; // 'LOCAL' or 'ENTRA'
  final String? lastLoginAt;
  final bool isConnect;

  AccountModel({
    required this.id,
    required this.nip,
    required this.name,
    required this.email,
    this.officeId,
    this.officeName,
    required this.roles,
    required this.active,
    this.agentCif,
    required this.authMethod,
    this.lastLoginAt,
    this.isConnect = false,
  });

  factory AccountModel.fromJson(Map<String, dynamic> j) => AccountModel(
        id: j['id']?.toString() ?? '',
        nip: j['nip']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        email: j['email']?.toString() ?? '',
        officeId: j['officeId'] as String?,
        officeName: j['officeName'] as String?,
        roles: (j['roles'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        active: (j['active'] ?? true) as bool,
        agentCif: j['agentCif'] as String?,
        authMethod: j['authMethod']?.toString() ?? 'LOCAL',
        lastLoginAt: j['lastLoginAt'] as String?,
        isConnect: j['isConnect'] == true,
      );
}

/// A first-time Microsoft SSO sign-in awaiting an admin decision.
/// Mirrors EntraPendingResponse on the backend.
class EntraPendingModel {
  final String id;
  final String entraObjectId;
  final String email;
  final String name;
  final String status;
  final String? createdAt;

  EntraPendingModel({
    required this.id,
    required this.entraObjectId,
    required this.email,
    required this.name,
    required this.status,
    this.createdAt,
  });

  factory EntraPendingModel.fromJson(Map<String, dynamic> j) => EntraPendingModel(
        id: j['id']?.toString() ?? '',
        entraObjectId: j['entraObjectId']?.toString() ?? '',
        email: j['email']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        status: j['status']?.toString() ?? 'PENDING',
        createdAt: j['createdAt'] as String?,
      );
}

/// An office option for the account form's dropdown (GET /api/offices).
class OfficeOption {
  final String id;
  final String name;
  final String? type;

  OfficeOption({required this.id, required this.name, this.type});

  factory OfficeOption.fromJson(Map<String, dynamic> j) => OfficeOption(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        type: j['type'] as String?,
      );

  String get label => type == null || type!.isEmpty ? name : '$name ($id)';
}

/// All assignable roles, with human labels for the account form.
///
/// Urutannya jadi urutan chip di form: peran operasional dulu, lalu divisi kantor
/// pusat. Kuncinya harus sama persis dengan enum `RoleName` di backend — peran yang
/// tidak dikenal backend ditolak saat menyimpan, dan (kalau lolos) akan jatuh ke
/// cakupan OWNER sehingga seluruh layar penggunanya kosong.
const Map<String, String> kRoleLabels = {
  'ADMIN': 'Admin',
  'RO': 'Regional Office (RO)',
  'BM': 'Branch Manager (BM)',
  'KUP': 'KUP',
  'RM': 'Relationship Manager (RM)',
  'AGENT': 'Agen',
  // Divisi kantor pusat: tanpa kantor, cakupan baca nasional, hak tulis terbatas
  // pada daftar master miliknya sendiri.
  'DIV_PRODUCT': 'Divisi Produk & Pengembangan',
  'DIV_SOE': 'Divisi Bisnis BUMN',
  'DIV_RETAIL': 'Divisi Bisnis Komersial & Ritel',
  'DIV_AGEN': 'Divisi Pengelolaan Agen',
  'DIV_AUDIT': 'Divisi Audit Internal (lihat saja)',
  'DIV_PROGRAM': 'Program Business (lihat saja)',
};

/// Admin account management. Backed by /api/auth/admin/users (+ /api/offices);
/// every write is ADMIN-gated server-side.
class AccountRepository {
  final ApiClient apiClient;

  AccountRepository({required this.apiClient});

  Future<List<AccountModel>> getAccounts() async {
    final res = await apiClient.get('/api/auth/admin/users');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((j) => AccountModel.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat akun'));
  }

  Future<List<OfficeOption>> getOffices() async {
    final res = await apiClient.get('/api/offices');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((j) => OfficeOption.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat kantor'));
  }

  Future<void> createAccount({
    required String nip,
    required String name,
    required String email,
    required String password,
    String? officeId,
    required List<String> roles,
    bool active = true,
  }) async {
    final body = {
      'nip': nip,
      'name': name,
      'email': email,
      'password': password,
      'officeId': (officeId != null && officeId.isEmpty) ? null : officeId,
      'roles': roles,
      'active': active,
    };
    final res = await apiClient.post('/api/auth/admin/users', body: body);
    if (res.statusCode != 200) {
      throw Exception(_message(res.body, 'Gagal membuat akun'));
    }
  }

  /// Update an existing account. Only non-null fields are changed server-side;
  /// pass [password] only when resetting it.
  ///
  /// [nip] adalah identitas login, jadi menggantinya memindahkan pintu masuk
  /// pemiliknya — server menolak bila NIP itu sudah dipakai akun lain. Sesi yang
  /// sedang berjalan tidak ikut dicabut, sehingga yang bersangkutan tetap masuk
  /// sampai tokennya kedaluwarsa lalu login berikutnya memakai NIP baru.
  Future<void> updateAccount(
    String id, {
    String? nip,
    String? name,
    String? email,
    String? officeId, // "" detaches the office, null leaves it unchanged
    String? password,
    List<String>? roles,
    bool? active,
    bool? isConnect,
  }) async {
    final body = <String, dynamic>{};
    if (nip != null) body['nip'] = nip;
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    if (officeId != null) body['officeId'] = officeId;
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (roles != null) body['roles'] = roles;
    if (active != null) body['active'] = active;
    if (isConnect != null) body['isConnect'] = isConnect;

    final res = await apiClient.put('/api/auth/admin/users/$id', body: body);
    if (res.statusCode != 200) {
      throw Exception(_message(res.body, 'Gagal menyimpan akun'));
    }
  }

  /// Toggle an account on/off (the "Nonaktifkan"/"Aktifkan" action) without
  /// touching its other fields.
  Future<void> setActive(String id, bool active) =>
      updateAccount(id, active: active);

  /// Menghapus akun — langkah ketiga setelah edit dan nonaktifkan, dan pelaksana
  /// permintaan penghapusan akun (kewajiban Google Play).
  ///
  /// Server menolak bila akun masih aktif, masih memegang portofolio, atau merupakan
  /// ADMIN terakhir. Hasilnya dikembalikan apa adanya supaya admin tahu apakah baris
  /// benar-benar dibuang (`HARD_DELETE`) atau data pribadinya dimusnahkan sementara
  /// catatan wajib arsip dipertahankan (`ANONYMIZED`) — lihat `UserDeletionService`
  /// di backend.
  Future<AccountDeletionResult> deleteAccount(String id) async {
    final res = await apiClient.delete('/api/auth/admin/users/$id');
    if (res.statusCode != 200) {
      throw Exception(_message(res.body, 'Gagal menghapus akun'));
    }
    return AccountDeletionResult.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  // ── Pending Microsoft SSO requests ──────────────────────────────────────────

  /// First-time SSO sign-ins whose Microsoft account isn't mapped to an MBIS user.
  Future<List<EntraPendingModel>> getEntraPending() async {
    final res = await apiClient.get('/api/auth/admin/entra/pending');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list
          .map((j) => EntraPendingModel.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat permintaan SSO'));
  }

  /// Link a pending SSO sign-in to an existing MBIS user (by NIP).
  Future<void> linkEntraPending(String id, String nip) async {
    final res = await apiClient
        .post('/api/auth/admin/entra/pending/$id/link', body: {'nip': nip});
    if (res.statusCode != 200) {
      throw Exception(_message(res.body, 'Gagal menghubungkan akun'));
    }
  }

  /// Approve a pending SSO sign-in by creating a new (SSO-only) MBIS user. Email and
  /// the Microsoft identity are taken from the pending request server-side.
  Future<void> createFromEntraPending(
    String id, {
    required String nip,
    required String name,
    String? officeId,
    required List<String> roles,
    bool active = true,
  }) async {
    final body = {
      'nip': nip,
      'name': name,
      'officeId': (officeId != null && officeId.isEmpty) ? null : officeId,
      'roles': roles,
      'active': active,
    };
    final res = await apiClient
        .post('/api/auth/admin/entra/pending/$id/create', body: body);
    if (res.statusCode != 200) {
      throw Exception(_message(res.body, 'Gagal membuat akun'));
    }
  }

  /// Deny a pending SSO sign-in; future sign-ins from that identity are blocked.
  Future<void> denyEntraPending(String id) async {
    final res = await apiClient.post('/api/auth/admin/entra/pending/$id/deny');
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(_message(res.body, 'Gagal menolak permintaan'));
    }
  }

  String _message(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {}
    return fallback;
  }
}
