import 'dart:convert';

import '../network/api_client.dart';

/// Satu RM yang akan/sudah ditulisi oleh unggahan.
class RealisasiImportRm {
  /// Alamat baris untuk menyunting pencocokannya. Dipakai apa adanya seperti
  /// dikirim server — jangan disusun ulang di klien.
  final String sourceKey;

  /// Pencocokan baris ini ditetapkan admin, bukan hasil pencocokan otomatis.
  final bool overridden;
  final String? sourceNip;
  final String? sourceName;
  final String? userNip;
  final String? userName;
  final bool viaAlias;
  final int cellCount;

  /// Total realisasi kategori dashboard (Non Program Non Askred) dari berkas,
  /// dalam rupiah penuh — angka yang paling cepat membongkar salah satuan.
  final double totalRealisasiYtd;

  RealisasiImportRm({
    required this.sourceKey,
    required this.overridden,
    required this.sourceNip,
    required this.sourceName,
    required this.userNip,
    required this.userName,
    required this.viaAlias,
    required this.cellCount,
    required this.totalRealisasiYtd,
  });

  factory RealisasiImportRm.fromJson(Map<String, dynamic> j) => RealisasiImportRm(
        sourceKey: j['sourceKey'] as String? ?? '',
        overridden: j['overridden'] == true,
        sourceNip: j['sourceNip'] as String?,
        sourceName: j['sourceName'] as String?,
        userNip: j['userNip'] as String?,
        userName: j['userName'] as String?,
        viaAlias: j['viaAlias'] == true,
        cellCount: j['cellCount'] ?? 0,
        totalRealisasiYtd: (j['totalRealisasiYtd'] ?? 0).toDouble(),
      );
}

/// Penyuntingan pencocokan satu baris oleh admin, dikirim bersama berkasnya.
///
/// [userId] null berarti **lewati** baris ini: tidak ditulis ke siapa pun dan
/// tidak masuk antrean.
///
/// [saveAlias] null menyerahkan keputusan ke server, yang mengingat pemetaan
/// hanya untuk baris yang memang tidak cocok sendiri — supaya koreksi sesaat
/// pada baris yang NIP-nya sudah benar tidak jadi permanen tanpa disadari.
class RealisasiMatchOverride {
  final String sourceKey;
  final String? userId;
  final String? targetName;
  final bool? saveAlias;

  const RealisasiMatchOverride({
    required this.sourceKey,
    required this.userId,
    this.targetName,
    this.saveAlias,
  });

  bool get skip => userId == null || userId!.isEmpty;

  Map<String, dynamic> toJson() => {
        'sourceKey': sourceKey,
        'userId': userId ?? '',
        if (saveAlias != null) 'saveAlias': saveAlias,
      };
}

/// Baris berkas yang belum ketemu akun RM-nya (versi pratinjau, belum tersimpan).
class RealisasiImportPendingPreview {
  /// Alamat baris — supaya baris ini pun bisa dipetakan langsung di pratinjau,
  /// tanpa menunggu diterapkan dulu.
  final String sourceKey;
  final String? nip;
  final String? nama;
  final String? jabatan;
  final String? kanwil;
  final String? kc;
  final int cellCount;

  RealisasiImportPendingPreview({
    required this.sourceKey,
    required this.nip,
    required this.nama,
    required this.jabatan,
    required this.kanwil,
    required this.kc,
    required this.cellCount,
  });

  String get asal => [
        if (kanwil != null && kanwil!.isNotEmpty) kanwil,
        if (kc != null && kc!.isNotEmpty) kc,
        if (jabatan != null && jabatan!.isNotEmpty) jabatan,
      ].join(' • ');

  factory RealisasiImportPendingPreview.fromJson(Map<String, dynamic> j) =>
      RealisasiImportPendingPreview(
        sourceKey: j['sourceKey'] as String? ?? '',
        nip: j['sourceNip'] as String?,
        nama: j['sourceName'] as String?,
        jabatan: j['sourceJabatan'] as String?,
        kanwil: j['sourceKanwil'] as String?,
        kc: j['sourceKc'] as String?,
        cellCount: j['cellCount'] ?? 0,
      );
}

/// Hasil satu unggahan — dipakai untuk dua fase.
///
/// [applied] false berarti ini PRATINJAU: berkas sudah dibaca & dicocokkan, tapi
/// belum ada satu baris pun yang ditulis. Angka di bawahnya adalah rencana, bukan
/// hasil.
class RealisasiImportResult {
  final int year;
  final bool applied;
  final int rowsRead;
  final int rmMatched;
  final int cellsSaved;

  /// Sel TARGET dari berkas yang sama. Berkas pusat memuat kolom Target dan
  /// Realisasi berdampingan, jadi satu unggahan mengisi keduanya.
  final int targetCellsSaved;
  final int pendingRows;
  final int matchedByAlias;

  /// Baris yang sengaja dilewati admin lewat penyuntingan pencocokan.
  final int rowsSkipped;
  final List<RealisasiImportRm> perRm;
  final List<RealisasiImportPendingPreview> pendingPreview;
  final List<String> warnings;

  RealisasiImportResult({
    required this.year,
    required this.applied,
    required this.rowsRead,
    required this.rmMatched,
    required this.cellsSaved,
    required this.targetCellsSaved,
    required this.pendingRows,
    required this.matchedByAlias,
    required this.rowsSkipped,
    required this.perRm,
    required this.pendingPreview,
    required this.warnings,
  });

  factory RealisasiImportResult.fromJson(Map<String, dynamic> j) =>
      RealisasiImportResult(
        year: j['year'] ?? 0,
        applied: j['applied'] == true,
        rowsRead: j['rowsRead'] ?? 0,
        rmMatched: j['rmMatched'] ?? 0,
        cellsSaved: j['cellsSaved'] ?? 0,
        targetCellsSaved: j['targetCellsSaved'] ?? 0,
        pendingRows: j['pendingRows'] ?? 0,
        matchedByAlias: j['matchedByAlias'] ?? 0,
        rowsSkipped: j['rowsSkipped'] ?? 0,
        perRm: (j['perRm'] as List?)
                ?.map((e) => RealisasiImportRm.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        pendingPreview: (j['pendingPreview'] as List?)
                ?.map((e) => RealisasiImportPendingPreview.fromJson(
                    e as Map<String, dynamic>))
                .toList() ??
            const [],
        warnings:
            (j['warnings'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}

/// Satu baris berkas yang belum ketemu akun RM-nya.
class RealisasiPendingRow {
  final String id;
  final int year;
  final String? nip;
  final String? nama;
  final String? jabatan;
  final String? kanwil;
  final String? kc;
  final int valueCount;

  RealisasiPendingRow({
    required this.id,
    required this.year,
    required this.nip,
    required this.nama,
    required this.jabatan,
    required this.kanwil,
    required this.kc,
    required this.valueCount,
  });

  /// Baris identitas untuk membedakan nama yang kembar antar cabang.
  String get asal => [
        if (kanwil != null && kanwil!.isNotEmpty) kanwil,
        if (kc != null && kc!.isNotEmpty) kc,
        if (jabatan != null && jabatan!.isNotEmpty) jabatan,
      ].join(' • ');

  factory RealisasiPendingRow.fromJson(Map<String, dynamic> j) =>
      RealisasiPendingRow(
        id: j['id'] ?? '',
        year: j['year'] ?? 0,
        nip: j['sourceNip'] as String?,
        nama: j['sourceName'] as String?,
        jabatan: j['sourceJabatan'] as String?,
        kanwil: j['sourceKanwil'] as String?,
        kc: j['sourceKc'] as String?,
        valueCount: j['valueCount'] ?? 0,
      );
}

/// Pemetaan tersimpan "baris berkas → akun RM".
class RealisasiAlias {
  final String id;
  final String? sourceNip;
  final String? sourceName;
  final String? userNip;
  final String? userName;

  RealisasiAlias({
    required this.id,
    required this.sourceNip,
    required this.sourceName,
    required this.userNip,
    required this.userName,
  });

  factory RealisasiAlias.fromJson(Map<String, dynamic> j) => RealisasiAlias(
        id: j['id'] ?? '',
        sourceNip: j['sourceNip'] as String?,
        sourceName: j['sourceName'] as String?,
        userNip: j['userNip'] as String?,
        userName: j['userName'] as String?,
      );
}

/// Unggahan rekap realisasi resmi dari pusat. Seluruh endpoint ADMIN-only di server.
class RealisasiImportRepository {
  final ApiClient apiClient;

  RealisasiImportRepository({required this.apiClient});

  static const _base = '/api/admin/import/realisasi';

  /// Kirim berkas rekap apa adanya (header tiga tingkat, ±380 kolom).
  ///
  /// [year] dikirim terpisah karena berkas pusat tidak memuat tahun di mana pun —
  /// kolomnya hanya Jan..Des.
  ///
  /// [apply] false (default) = PRATINJAU: server membaca & mencocokkan tapi tidak
  /// menulis apa pun. Berkas yang sama dikirim ulang dengan `apply: true` untuk
  /// menerapkannya. Berkasnya dipegang klien di antara dua fase, jadi yang
  /// ditinjau dan yang diterapkan dijamin isi yang sama.
  ///
  /// [overrides] penyuntingan pencocokan oleh admin. Dikirim di KEDUA fase —
  /// pada pratinjau supaya admin melihat akibat suntingannya sebelum menerapkan,
  /// dan pada penerapan karena server tidak menyimpan apa pun di antara keduanya.
  Future<RealisasiImportResult> upload({
    required List<int> bytes,
    required String filename,
    required int year,
    bool apply = false,
    List<RealisasiMatchOverride> overrides = const [],
  }) async {
    final res = await apiClient.postMultipart(
      '$_base?year=$year&apply=$apply',
      fields: overrides.isEmpty
          ? const {}
          : {'overrides': jsonEncode(overrides.map((o) => o.toJson()).toList())},
      fileField: 'file',
      fileBytes: bytes,
      fileName: filename,
    );
    if (res.statusCode == 200) {
      return RealisasiImportResult.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_errorMessage(res.body));
  }

  Future<List<RealisasiPendingRow>> pending({int? year}) async {
    final path = year == null ? '$_base/pending' : '$_base/pending?year=$year';
    final res = await apiClient.get(path);
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((e) => RealisasiPendingRow.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_errorMessage(res.body));
  }

  /// Petakan satu baris ke akun RM. [saveAlias] false = koreksi sekali jalan,
  /// tidak diingat untuk unggahan berikutnya.
  Future<int> assign(String pendingId, String userId,
      {bool saveAlias = true}) async {
    final res = await apiClient.put('$_base/pending/$pendingId',
        body: {'userId': userId, 'saveAlias': saveAlias});
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as Map<String, dynamic>)['cellsSaved'] ?? 0;
    }
    throw Exception(_errorMessage(res.body));
  }

  Future<void> dismiss(String pendingId) async {
    final res = await apiClient.delete('$_base/pending/$pendingId');
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception(_errorMessage(res.body));
    }
  }

  Future<List<RealisasiAlias>> aliases() async {
    final res = await apiClient.get('$_base/alias');
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as List)
          .map((e) => RealisasiAlias.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_errorMessage(res.body));
  }

  Future<void> deleteAlias(String id) async {
    final res = await apiClient.delete('$_base/alias/$id');
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception(_errorMessage(res.body));
    }
  }

  /// Pesan penolakan server diteruskan apa adanya: penolakan di sini menjelaskan
  /// hal yang tidak bisa ditebak klien (struktur berkas berubah, tahun tak valid).
  String _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {
      // biarkan; jatuh ke pesan umum
    }
    return 'Gagal memproses berkas realisasi';
  }
}
