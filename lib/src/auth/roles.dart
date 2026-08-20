/// Nama peran sebagaimana dikirim backend di klaim JWT `roles` dan di
/// `AuthUser.roles`.
///
/// Sisa kode lama masih membandingkan literal string di banyak tempat; berkas ini
/// bukan upaya menyeragamkan semuanya sekaligus, melainkan satu tempat rujukan
/// untuk peran divisi kantor pusat yang ditambahkan bersama migrasi V50 — di
/// situlah salah ketik paling mahal, karena peran yang tak dikenal backend akan
/// diam-diam jatuh ke cakupan OWNER dan membuat seluruh layar kosong tanpa error.
///
/// Peran yang dipakai sebagai gerbang di sisi klien HARUS mencerminkan gerbang
/// server, bukan menggantikannya: backend tetap menjawab 403. Gunanya di sini
/// semata agar pengguna tidak disodori pintu yang pasti tertutup.
abstract final class Roles {
  // ── Peran operasional (jaringan kantor) ──────────────────────────────────
  static const admin = 'ADMIN';
  static const ro = 'RO';
  static const bm = 'BM';
  static const kup = 'KUP';
  static const rm = 'RM';
  static const agent = 'AGENT';

  // ── Divisi kantor pusat (V50) ────────────────────────────────────────────
  /// Product Research & Development Division — katalog produk & kategorinya.
  static const divProduct = 'DIV_PRODUCT';

  /// SOE Business Division — daftar/ekosistem BUMN.
  static const divSoe = 'DIV_SOE';

  /// Commercial & Retail Business Division — daftar broker.
  static const divRetail = 'DIV_RETAIL';

  /// Insurance Agent Management — lisensi, perpanjangan, dokumen, CIF, template agen.
  static const divAgen = 'DIV_AGEN';

  /// Internal Audit Division — hanya melihat.
  static const divAudit = 'DIV_AUDIT';

  /// Program Business — hanya melihat.
  static const divProgram = 'DIV_PROGRAM';

  /// Seluruh divisi kantor pusat. Cakupan bacanya nasional; hak tulisnya sempit
  /// dan berbeda-beda per divisi (lihat [curatorDivisions]).
  static const headOfficeDivisions = {
    divProduct,
    divSoe,
    divRetail,
    divAgen,
    divAudit,
    divProgram,
  };

  /// Divisi yang mengelola satu daftar master. Merekalah yang butuh hub "Kelola";
  /// [divAudit] & [divProgram] sengaja tidak termasuk — semua yang boleh mereka
  /// lihat sudah tersedia di tab Dashboard/Customer/BUMN/Broker/Tools.
  static const curatorDivisions = {divProduct, divSoe, divRetail, divAgen};

  /// Boleh mengelola agen dari sisi kantor pusat: input lisensi, setujui
  /// perpanjangan, adjudikasi dokumen, terbitkan CIF. Cermin
  /// `hasAnyRole('ADMIN','DIV_AGEN')` di AgentController.
  static const agentHqManagers = {admin, divAgen};

  /// Boleh mengubah **data pipeline itu sendiri** (produk, TSI, rate, tanggal
  /// closing). Cermin `hasAnyRole('RM','BM','RO','KUP')` pada
  /// `PUT /api/pipelines/{id}`; ADMIN lolos lewat RoleHierarchy.
  static const pipelineWriters = {admin, rm, bm, ro, kup};

  /// Boleh mengerjakan **pekerjaan lapangan** atas pipeline: ubah stage/status,
  /// maju/kalah tender, jadwal kunjungan, catat aktivitas, unggah & hapus dokumen.
  ///
  /// Sengaja LEBIH SEMPIT dari [pipelineWriters]. Seluruh endpoint tersebut
  /// digerbangi `hasRole('RM')` di server, dan RoleHierarchy hanya menaikkan ADMIN
  /// dan KUP ke atas RM — BM & RO tidak. Jadi atasan cabang boleh mengoreksi data
  /// pipeline, tetapi bukan mencatat pekerjaan lapangan yang bukan miliknya.
  static const pipelineFieldWorkers = {admin, rm, kup};

  /// Boleh membuka hub "Kelola" beserta seluruh konsol di bawahnya.
  ///
  /// Dipakai DUA tempat: penampilan tab di MainScreen, dan gerbang rute di
  /// router. Dulu hanya tabnya yang digerbangi, sehingga RM masih bisa membuka
  /// `/kelola/export-data` dengan mengetik URL-nya: halamannya tergambar utuh
  /// padahal setiap tombolnya berujung 403 tanpa pesan apa pun.
  static const kelolaHubRoles = {admin, bm, ro, kup, ...curatorDivisions};

  /// True bila [roles] memuat salah satu dari [allowed].
  static bool hasAny(List<String>? roles, Set<String> allowed) =>
      roles != null && roles.any(allowed.contains);
}
