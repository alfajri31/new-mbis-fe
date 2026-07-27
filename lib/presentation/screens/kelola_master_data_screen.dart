import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../src/app.dart';
import '../../src/network/api_client.dart';
import '../../src/agent/agent_repository.dart';
import '../../src/master_data/master_data_repository.dart';
import '../../src/product_knowledge/product_knowledge_models.dart' show pkCategoryIcon;
import '../widgets/glass_app_bar.dart';
import '../widgets/state_views.dart';
import '../widgets/max_width_body.dart';
import '../widgets/kelola_master_data/parameter_category_card.dart';
import '../widgets/kelola_master_data/template_row.dart';
import '../widgets/kelola_master_data/komisi_rate_row.dart';
import '../widgets/kelola_master_data/product_row.dart';
import '../widgets/kelola_master_data/broker_row.dart';
import '../widgets/kelola_master_data/bank_row.dart';
import '../widgets/kelola_master_data/bank_branch_row.dart';
import '../widgets/kelola_master_data/bumn_row.dart';
import '../widgets/kelola_master_data/category_row.dart';
import '../widgets/kelola_master_data/office_row.dart';
import '../../core/providers/repository_providers.dart';
import '../providers/kelola_master_data_provider.dart';
import '../widgets/dispose_callback.dart';

/// Satu bagian master data: satu kartu di hub, satu halaman saat dibuka.
class _Section {
  final String id;
  final String title;

  /// Dipakai dua kali: baris kedua di kartu hub, dan kalimat pengantar di
  /// halamannya — supaya admin tahu "ini dipakai di mana" tanpa menebak.
  final String subtitle;
  final IconData icon;
  final String group;
  final Widget Function(MasterDataRepository repo) builder;

  const _Section({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.group,
    required this.builder,
  });
}

const _kGroupNasabah = 'DATA NASABAH';
const _kGroupProduk = 'PRODUK & KOMISI';
const _kGroupMitra = 'MITRA & DOKUMEN';
const _kGroupOrganisasi = 'ORGANISASI';

final List<_Section> _kSections = [
  _Section(
    id: 'parameter',
    title: 'Dropdown & Rate',
    subtitle: 'Nilai pilihan di form: badan hukum, entitas, mata uang, rate premi',
    icon: Icons.tune,
    group: _kGroupNasabah,
    builder: (repo) => _ParameterTab(repo: repo),
  ),
  _Section(
    id: 'produk',
    title: 'Produk',
    subtitle: 'Katalog produk asuransi yang dipilih RM saat membuat pipeline',
    icon: Icons.inventory_2_outlined,
    group: _kGroupProduk,
    builder: (repo) => _ProductTab(repo: repo),
  ),
  _Section(
    id: 'kategori',
    title: 'Kategori Produk',
    subtitle: 'Pengelompokan produk beserta ikon & warnanya',
    icon: Icons.category_outlined,
    group: _kGroupProduk,
    builder: (repo) => _CategoryTab(repo: repo),
  ),
  _Section(
    id: 'komisi',
    title: 'Rate Komisi',
    subtitle: 'Persentase komisi agen per jenis pertanggungan (TOC)',
    icon: Icons.percent,
    group: _kGroupProduk,
    builder: (repo) => _KomisiTab(repo: repo),
  ),
  _Section(
    id: 'broker',
    title: 'Broker',
    subtitle: 'Daftar perusahaan broker rekanan',
    icon: Icons.handshake_outlined,
    group: _kGroupMitra,
    builder: (repo) => _BrokerTab(repo: repo),
  ),
  _Section(
    id: 'bank',
    title: 'Bank & Cabang',
    subtitle: 'Bank rekanan beserta daftar cabangnya',
    icon: Icons.account_balance_outlined,
    group: _kGroupMitra,
    builder: (repo) => _BankTab(repo: repo),
  ),
  _Section(
    id: 'bumn',
    title: 'Ekosistem BUMN',
    subtitle: 'Pohon induk–anak perusahaan BUMN',
    icon: Icons.hub_outlined,
    group: _kGroupMitra,
    builder: (repo) => _BumnTab(repo: repo),
  ),
  _Section(
    id: 'template',
    title: 'Template Dokumen Agen',
    subtitle: 'Formulir kosong onboarding agen yang diunduh RM',
    icon: Icons.description_outlined,
    group: _kGroupMitra,
    builder: (_) => const _TemplateTab(),
  ),
  _Section(
    id: 'kantor',
    title: 'Kantor',
    subtitle: 'Kantor wilayah, cabang, dan KUP beserta hierarkinya',
    icon: Icons.apartment_outlined,
    group: _kGroupOrganisasi,
    builder: (repo) => _OfficeTab(repo: repo),
  ),
];

/// Kelola Master Data — hub admin untuk seluruh data acuan (dropdown, produk,
/// komisi, mitra, kantor, template). Tulis dijaga ADMIN di sisi server.
///
/// Dulu layar ini satu `TabBar` berisi 9 tab yang harus di-geser: tab paling
/// kanan (Kantor, Template) praktis tak terlihat, dan tak ada penjelasan isi tiap
/// tab. Sekarang jadi daftar kartu berkelompok + pencarian; tiap kartu membuka
/// halamannya sendiri, jadi tak ada menu tersembunyi.
class KelolaMasterDataScreen extends ConsumerStatefulWidget {
  const KelolaMasterDataScreen({super.key});

  @override
  ConsumerState<KelolaMasterDataScreen> createState() => _KelolaMasterDataScreenState();
}

class _KelolaMasterDataScreenState extends ConsumerState<KelolaMasterDataScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  MasterDataRepository? _repo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(masterDataCountsProvider.notifier).load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repo ??= MasterDataRepository(apiClient: ApiClient(session: MbisApp.of(context)?.session));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_Section> get _filtered {
    if (_query.isEmpty) return _kSections;
    return _kSections
        .where((s) =>
            s.title.toLowerCase().contains(_query) ||
            s.subtitle.toLowerCase().contains(_query))
        .toList();
  }

  Future<void> _open(_Section section) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _SectionPage(section: section, repo: _repo!),
    ));
    // Segarkan SETELAH kembali: admin mungkin menambah/menghapus data di sana.
    if (!mounted) return;
    await ref.read(masterDataCountsProvider.notifier).load(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final counts = ref.watch(masterDataCountsProvider);
    final sections = _filtered;
    final groups = <String, List<_Section>>{};
    for (final s in sections) {
      (groups[s.group] ??= []).add(s);
    }

    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: const GlassAppBar(title: 'Kelola Master Data', showBack: true),
      body: MaxWidthBody(
        child: _repo == null
            ? const SizedBox.shrink()
            : RefreshIndicator(
                color: AppColors.primaryNavy,
                onRefresh: () =>
                    ref.read(masterDataCountsProvider.notifier).load(force: true),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                      child: Text(
                        'Data acuan yang dipakai form di seluruh aplikasi. '
                        'Pilih bagian yang ingin diubah.',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ),
                    _searchField(_searchCtrl, 'Cari bagian pengaturan…',
                        (v) => setState(() => _query = v)),
                    if (sections.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: EmptyStateView(
                          icon: Icons.search_off,
                          title: 'Bagian tidak ditemukan',
                          subtitle: 'Coba kata kunci lain, mis. "bank" atau "komisi".',
                        ),
                      )
                    else
                      for (final entry in groups.entries) ...[
                        _groupLabel(entry.key),
                        for (final s in entry.value)
                          _SectionCard(
                            section: s,
                            count: counts.counts[s.id],
                            loadingCount: counts.loading && !counts.counts.containsKey(s.id),
                            onTap: () => _open(s),
                          ),
                      ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _groupLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.grayStage,
          ),
        ),
      );
}

/// Kartu satu bagian di hub: ikon, nama, penjelasan singkat, jumlah data.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.count,
    required this.loadingCount,
    required this.onTap,
  });

  final _Section section;
  final int? count;
  final bool loadingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      child: Material(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.radiusLg,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: AppRadius.radiusLg,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryNavy.withValues(alpha: 0.06),
                    borderRadius: AppRadius.radiusMd,
                  ),
                  child: Icon(section.icon, size: 20, color: AppColors.primaryNavy),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        section.subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary, height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _countBadge(),
                const Icon(Icons.chevron_right, color: AppColors.grayStage),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _countBadge() {
    if (loadingCount) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 1.6, color: AppColors.grayStage),
      );
    }
    if (count == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bgScreen,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Halaman satu bagian: judul + kalimat pengantar + isi bagian (widget lama).
class _SectionPage extends StatelessWidget {
  const _SectionPage({required this.section, required this.repo});

  final _Section section;
  final MasterDataRepository repo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: GlassAppBar(title: section.title, showBack: true),
      body: MaxWidthBody(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
              color: AppColors.surfaceWhite,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.grayStage),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      section.subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: section.builder(repo)),
          ],
        ),
      ),
    );
  }
}

// ── helpers shared by tabs ────────────────────────────────────────────────────

void _snack(BuildContext context, String msg, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: isError ? AppColors.errorRed : AppColors.successGreen,
  ));
}

Future<bool> _confirmDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
      // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
      scrollable: true,
      title: const Text('Hapus?'),
      content: Text('"$what" akan dihapus permanen.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Hapus', style: TextStyle(color: AppColors.errorRed)),
        ),
      ],
    ),
  );
  return ok == true;
}

// Input mengikuti design.md §3.11: bg `bg-screen`, radius 10 (radius-md),
// border tipis idle, fokus navy 1.5dp.
InputDecoration _dec(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: AppColors.bgScreen,
      border: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: const BorderSide(color: AppColors.primaryNavy, width: 1.5)),
    );

/// Judul sheet + tombol tutup. Dipakai form panjang (Tambah Nilai, Tambah Produk)
/// yang nyaris memenuhi layar: tanpa tombol ini satu-satunya jalan keluar adalah
/// gestur geser ke bawah, yang tidak terlihat sebagai pilihan oleh pengguna baru.
Widget _sheetTitleBar(BuildContext context, String title) => Row(
      children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        IconButton(
          tooltip: 'Tutup',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close, size: 20, color: AppColors.grayStage),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );

/// Handle bar bottom sheet (design.md §3.12): 36×4dp, warna border, centered.
Widget _sheetGrabber() => Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

/// Search bar (design.md §S-102): height 44, bg `bg-screen`, radius 10, ikon cari.
Widget _searchField(TextEditingController ctrl, String hint, ValueChanged<String> onChanged) =>
    Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
      child: TextField(
        controller: ctrl,
        onChanged: (v) => onChanged(v.trim().toLowerCase()),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.grayStage),
          suffixIcon: ctrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppColors.grayStage),
                  onPressed: () {
                    ctrl.clear();
                    onChanged('');
                  },
                ),
          isDense: true,
          filled: true,
          fillColor: AppColors.bgScreen,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(borderRadius: AppRadius.radiusMd, borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.radiusMd,
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.radiusMd,
              borderSide: const BorderSide(color: AppColors.primaryNavy, width: 1.5)),
        ),
      ),
    );

/// Tombol tambah. [label] wajib menyebut OBJEKNYA ("Tambah Broker", bukan
/// "Tambah"): sejak tiap bagian punya halaman sendiri, label generik membuat
/// admin ragu apa yang akan dibuat.
Widget _addFab(VoidCallback onTap, String label) => FloatingActionButton.extended(
      onPressed: onTap,
      backgroundColor: AppColors.primaryNavy,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: Text(label),
    );

// ════════════════════════════════════════════════════════════════════════════
// PARAMETER TAB
// ════════════════════════════════════════════════════════════════════════════

/// Definisi satu kategori dropdown yang dikelola admin: kode DB, label ramah, grup.
class _CatDef {
  final String code;
  final String label;
  final String group;
  const _CatDef(this.code, this.label, this.group);
}

/// Daftar kategori parameter yang dikurasi — ditampilkan PER-KATEGORI walau kosong,
/// supaya admin bisa mengisi/mengubah semuanya tanpa menyentuh kode.
/// Catatan: COB/LOB/TOC sengaja TIDAK di sini — sumbernya tab "Produk" (master_products).
const List<_CatDef> _kCategoryRegistry = [
  // Customer
  _CatDef('BADAN_HUKUM', 'Badan Hukum', 'Customer'),
  _CatDef('ENTITY_CATEGORY', 'Entitas Customer', 'Customer'),
  _CatDef('STRUKTUR_RELASI', 'Struktur Relasi (BUMN)', 'Customer'),
  _CatDef('BUMN', 'Daftar BUMN', 'Customer'),
  _CatDef('PIC_TITLE', 'Sebutan PIC (Bapak/Ibu)', 'Customer'),
  // Bisnis
  _CatDef('DOC_TYPE', 'Jenis Dokumen', 'Bisnis'),
  _CatDef('CURRENCY', 'Mata Uang', 'Bisnis'),
  _CatDef('SUMBER_BISNIS', 'Sumber Bisnis (Pipeline)', 'Bisnis'),
  _CatDef('PREMI_RATE', 'Rate Premi', 'Bisnis'),
  _CatDef('COMMISSION_DEFAULT', 'Rate Komisi Agen Default (mis. 0.10)', 'Bisnis'),
  // Agen (onboarding) — Nilai Numerik: 1 = WAJIB, 0 = OPSIONAL
  _CatDef('GENDER', 'Jenis Kelamin', 'Agen'),
  _CatDef('AGENT_LICENSE', 'Lisensi Agen (hari)', 'Agen'),
  _CatDef('AGENT_FIELD', 'Kolom Data Agen (1=wajib)', 'Agen'),
  _CatDef('AGENT_DOC_REG', 'Dokumen Pendaftaran (1=wajib)', 'Agen'),
  _CatDef('AGENT_DOC_POST', 'Dokumen Setelah Lisensi (1=wajib)', 'Agen'),
  _CatDef('AGENT_DOC_RENEWAL', 'Dokumen Perpanjangan (1=wajib)', 'Agen'),
  // Tender
  _CatDef('KERJA_SAMA', 'Bentuk Kerja Sama', 'Tender'),
  _CatDef('PROSES_TENDER', 'Langkah Proses Tender', 'Tender'),
  // Sistem (ubah dengan hati-hati — terkait alur aplikasi)
  _CatDef('PIPELINE_STAGE', 'Tahap Pipeline', 'Sistem'),
  _CatDef('PIPELINE_SUB_STAGE', 'Sub-Tahap Pipeline', 'Sistem'),
  _CatDef('KATEGORI', 'Kategori Customer', 'Sistem'),
  _CatDef('CUSTOMER_STATE', 'Status Customer (Aktivitas AI)', 'Sistem'),
  // Link portal Fintrack untuk pencairan komisi agen (isi 1 nilai = URL portal).
  _CatDef('FINTRACK_URL', 'Link Portal Fintrack (Pencairan Komisi)', 'Sistem'),
];

/// Urutan tampil grup.
const List<String> _kGroupOrder = ['Customer', 'Bisnis', 'Agen', 'Tender', 'Sistem', 'Lainnya'];

/// Kategori "sistem" diberi penanda peringatan agar tak diubah sembarangan.
const Set<String> _kSystemCategories = {'PIPELINE_STAGE', 'PIPELINE_SUB_STAGE', 'KATEGORI'};

_CatDef _catDef(String code) => _kCategoryRegistry.firstWhere(
      (c) => c.code == code,
      orElse: () => _CatDef(code, code, 'Lainnya'),
    );

/// Admin mengelola template onboarding (Surat Pernyataan, Pakta, SMAP, memo, …):
/// menambah jenis baru, mengubah nama/urutan, menghapus, dan mengunggah berkas
/// kosongnya. Setelah berkas diunggah, tombol unduh di form RM/agen aktif.
///
/// Sebelumnya daftar jenis template TETAP — hanya bisa lahir dari migrasi Flyway,
/// jadi menambah dokumen baru butuh rilis backend.
class _TemplateTab extends ConsumerStatefulWidget {
  const _TemplateTab();

  @override
  ConsumerState<_TemplateTab> createState() => _TemplateTabState();
}

class _TemplateTabState extends ConsumerState<_TemplateTab> {
  // DATA/LOADING/ERROR pindah ke MasterTemplateNotifier; repository diambil dari
  // agentRepoProvider (dulu ApiClient dirakit sendiri di didChangeDependencies).
  // `_uploadingCode` TETAP di widget: status tombol per baris, murni tampilan.
  MasterTemplateState get _ts => ref.read(masterTemplateProvider);
  MasterTemplateNotifier get _notifier => ref.read(masterTemplateProvider.notifier);
  AgentRepository get _repo => ref.read(agentRepoProvider);
  bool get _loading => _ts.loading;
  String? get _error => _ts.error;
  List<AgentTemplateItem> get _items => _ts.items;

  String? _uploadingCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifier.fetch();
    });
  }

  Future<void> _fetch() => _notifier.fetch();

  Future<void> _upload(AgentTemplateItem t) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
    final f = res.files.first;
    setState(() => _uploadingCode = t.code);
    try {
      await _repo.uploadTemplate(t.code, fileBytes: f.bytes!, fileName: f.name);
      if (!mounted) return;
      _snack(context, 'Template ${t.name} diunggah.');
      await _fetch();
    } catch (e) {
      if (!mounted) return;
      _snack(context, '$e'.replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _uploadingCode = null);
    }
  }

  /// Form tambah/ubah template. Saat menambah, admin cukup mengisi nama —
  /// kodenya diturunkan server dari nama itu.
  Future<void> _openForm({AgentTemplateItem? item}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _TemplateForm(repo: _repo, item: item),
    );
    if (saved == true) await _fetch();
  }

  Future<void> _delete(AgentTemplateItem t) async {
    if (!await _confirmDelete(context, t.name)) return;
    try {
      await _repo.deleteTemplate(t.code);
      if (!mounted) return;
      _snack(context, 'Template ${t.name} dihapus.');
      await _fetch();
    } catch (e) {
      if (!mounted) return;
      _snack(context, '$e'.replaceFirst('Exception: ', ''), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(masterTemplateProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _addFab(() => _openForm(), 'Tambah Template'),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const SkeletonList(itemCount: 5);
    if (_error != null) {
      return ListView(children: [
        const SizedBox(height: 60),
        ErrorStateView(message: _error!, onRetry: _fetch),
      ]);
    }
    if (_items.isEmpty) {
      // Tanpa ini tab tampil putih polos saat daftar kosong — tak bisa dibedakan
      // dari layar gagal muat. ListView (bukan Center) + physics selalu bisa
      // di-scroll supaya pull-to-refresh tetap jalan walau isinya nihil.
      return RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 80),
            EmptyStateView(
              icon: Icons.description_outlined,
              title: 'Belum ada template',
              subtitle: 'Tekan "Tambah Template" untuk membuat jenis dokumen '
                  'onboarding, lalu unggah berkas kosongnya.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 90),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final t = _items[i];
          return TemplateRow(
            item: t,
            busy: _uploadingCode == t.code,
            onUpload: () => _upload(t),
            onEdit: () => _openForm(item: t),
            onDelete: () => _delete(t),
          );
        },
      ),
    );
  }
}

/// Sheet tambah/ubah template. Kode hanya bisa diisi saat membuat (setelah itu
/// permanen, karena dipakai sebagai id berkas di URL unggah/unduh).
class _TemplateForm extends StatefulWidget {
  final AgentRepository repo;
  final AgentTemplateItem? item;

  const _TemplateForm({required this.repo, this.item});

  @override
  State<_TemplateForm> createState() => _TemplateFormState();
}

class _TemplateFormState extends State<_TemplateForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _sort;
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item?.name ?? '');
    _code = TextEditingController(text: widget.item?.code ?? '');
    _sort = TextEditingController(text: widget.item?.sortOrder?.toString() ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _sort.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final sort = int.tryParse(_sort.text.trim());
    try {
      if (_isEdit) {
        await widget.repo.updateTemplate(widget.item!.code,
            name: _name.text.trim(), sortOrder: sort);
      } else {
        await widget.repo.createTemplate(
            name: _name.text.trim(), code: _code.text.trim(), sortOrder: sort);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(context, '$e'.replaceFirst('Exception: ', ''), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetGrabber(),
              Text(_isEdit ? 'Ubah Template' : 'Tambah Template',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                _isEdit
                    ? 'Kode template tidak bisa diubah karena dipakai berkas yang sudah terunggah.'
                    : 'Isi nama dokumennya saja — kode dibuat otomatis. Berkas kosongnya diunggah setelah ini.',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary, height: 1.35),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: _dec('Nama template', hint: 'mis. Pakta Integritas'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              if (_isEdit)
                TextFormField(
                  controller: _code,
                  enabled: false,
                  decoration: _dec('Kode'),
                )
              else
                TextFormField(
                  controller: _code,
                  decoration: _dec('Kode (opsional)',
                      hint: 'kosongkan untuk dibuat otomatis dari nama'),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return null;
                    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(s)) {
                      return 'Hanya huruf, angka, dan garis bawah';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sort,
                keyboardType: TextInputType.number,
                decoration: _dec('Urutan tampil (opsional)',
                    hint: 'makin kecil makin atas'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Simpan',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParameterTab extends ConsumerStatefulWidget {
  final MasterDataRepository repo;
  const _ParameterTab({required this.repo});

  @override
  ConsumerState<_ParameterTab> createState() => _ParameterTabState();
}

class _ParameterTabState extends ConsumerState<_ParameterTab> {
  // State DATA/LOADING/ERROR dipindah ke MasterParameterNotifier. Getter berikut
  // memproksinya agar kode build/aksi di bawah tetap memakai nama lama.
  MasterParameterState get _ps => ref.read(masterParameterProvider);
  MasterParameterNotifier get _notifier => ref.read(masterParameterProvider.notifier);
  bool get _loading => _ps.loading;
  String? get _error => _ps.error;
  List<ParameterItem> get _items => _ps.items;

  // Pencarian client-side: mencocokkan nama/kode kategori MAUPUN isi nilainya,
  // jadi admin bisa mencari "BNI" tanpa tahu ia ada di kategori BANK.
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    // Muat setelah frame pertama (samakan initState→_fetch lama; state Notifier
    // tak boleh diubah selama build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.fetch();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() => _notifier.fetch();

  /// Kategori yang lolos pencarian: label/kode cocok, ATAU salah satu nilainya cocok.
  bool _matches(String code, List<ParameterItem> values) {
    if (_search.isEmpty) return true;
    final def = _catDef(code);
    if (def.label.toLowerCase().contains(_search) ||
        code.toLowerCase().contains(_search)) {
      return true;
    }
    return values.any((v) =>
        v.paramValue.toLowerCase().contains(_search) ||
        v.paramKey.toLowerCase().contains(_search));
  }

  /// Semua kategori yang ditampilkan: registry (selalu, walau kosong) + yang ada di DB.
  List<String> get _allCategories {
    final ordered = [for (final c in _kCategoryRegistry) c.code];
    for (final c in _items.map((e) => e.category)) {
      if (!ordered.contains(c)) ordered.add(c); // kategori DB di luar registry
    }
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(masterParameterProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _addFab(() => _openForm(), 'Tambah Nilai'),
      body: _loading
          ? const SkeletonList(itemCount: 6)
          : _error != null
              ? ListView(children: [
                  const SizedBox(height: 60),
                  ErrorStateView(message: _error!, onRetry: _fetch),
                ])
              : Column(
                  children: [
                    _searchField(_searchCtrl, 'Cari kategori atau nilainya',
                        (v) => setState(() => _search = v)),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _fetch,
                        child: _buildGroupedList(),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildGroupedList() {
    final byCat = <String, List<ParameterItem>>{};
    for (final p in _items) {
      (byCat[p.category] ??= []).add(p);
    }
    final byGroup = <String, List<String>>{};
    for (final code in _allCategories) {
      if (!_matches(code, byCat[code] ?? const [])) continue;
      (byGroup[_catDef(code).group] ??= []).add(code);
    }
    final groups = [
      for (final g in _kGroupOrder) if (byGroup.containsKey(g)) g,
      for (final g in byGroup.keys) if (!_kGroupOrder.contains(g)) g,
    ];

    if (groups.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          EmptyStateView(
            icon: Icons.search_off,
            title: 'Tidak ada hasil',
            subtitle: 'Tidak ada kategori atau nilai yang cocok dengan "$_search".',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 90),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        for (final g in groups) ...[
          _groupHeader(g),
          for (final code in byGroup[g]!)
            ParameterCategoryCard(
              label: _catDef(code).label,
              code: code,
              isSystem: _kSystemCategories.contains(code),
              values: byCat[code] ?? const [],
              onAddValue: () => _openForm(presetCategory: code),
              onEditValue: (p) => _openForm(item: p),
              onDeleteValue: (p) => _delete(p),
            ),
        ],
      ],
    );
  }

  Widget _groupHeader(String group) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6, left: 4),
        child: Text(
          group.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: AppColors.textSecondary,
          ),
        ),
      );

  Future<void> _delete(ParameterItem p) async {
    if (!await _confirmDelete(context, p.paramValue)) return;
    try {
      await widget.repo.deleteParameter(p.id);
      if (!mounted) return;
      _snack(context, 'Parameter dihapus');
      _fetch();
    } catch (e) {
      if (!mounted) return;
      _snack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _openForm({ParameterItem? item, String? presetCategory}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      // Batasi tinggi supaya form tidak menutup seluruh layar: sisa layar tetap
      // terlihat, jadi jelas ini panel yang bisa ditutup (plus tombol X di judul).
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ParameterForm(
        repo: widget.repo,
        item: item,
        knownCategories: _allCategories,
        presetCategory: presetCategory,
      ),
    );
    if (saved == true) _fetch();
  }
}

class _ParameterForm extends StatefulWidget {
  final MasterDataRepository repo;
  final ParameterItem? item;
  final List<String> knownCategories;
  final String? presetCategory;

  const _ParameterForm({
    required this.repo,
    this.item,
    required this.knownCategories,
    this.presetCategory,
  });

  @override
  State<_ParameterForm> createState() => _ParameterFormState();
}

class _ParameterFormState extends State<_ParameterForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _category;
  late final TextEditingController _value;
  late final TextEditingController _numeric;
  late final TextEditingController _sort;
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _category = TextEditingController(text: it?.category ?? widget.presetCategory ?? '');
    _value = TextEditingController(text: it?.paramValue ?? '');
    _numeric = TextEditingController(text: it?.numericValue?.toString() ?? '');
    _sort = TextEditingController(text: (it?.sortOrder ?? 0).toString());
    _active = it?.active ?? true;
  }

  @override
  void dispose() {
    _category.dispose();
    _value.dispose();
    _numeric.dispose();
    _sort.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      // Isi sheet bisa lebih tinggi dari layar (mis. daftar chip kategori,
      // atau keyboard terbuka di layar pendek) -> harus bisa di-scroll,
      // kalau tidak muncul garis kuning 'BOTTOM OVERFLOWED BY ... PIXELS'.
      child: SingleChildScrollView(
        child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetGrabber(),
            _sheetTitleBar(context,
                widget.item == null ? 'Tambah Parameter' : 'Edit Parameter'),
            const SizedBox(height: 16),
            // Category: free text + quick-pick from known categories.
            TextFormField(
              controller: _category,
              decoration: _dec('Kategori', hint: 'mis. BADAN_HUKUM, COB, BANK'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            if (widget.knownCategories.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final c in widget.knownCategories)
                    ActionChip(
                      label: Text(_catDef(c).label, style: const TextStyle(fontSize: 11)),
                      onPressed: () => setState(() => _category.text = c),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _value,
              decoration: _dec('Nilai / Label', hint: 'teks yang tampil di dropdown'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _numeric,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('Nilai numerik (opsional)', hint: 'mis. rate 0.15'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    controller: _sort,
                    keyboardType: TextInputType.number,
                    decoration: _dec('Urutan'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aktif', style: TextStyle(fontSize: 14)),
              value: _active,
              activeThumbColor: AppColors.successGreen,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.repo.saveParameter(
        id: widget.item?.id,
        category: _category.text.trim(),
        paramValue: _value.text.trim(),
        numericValue: _numeric.text.trim().isEmpty ? null : double.tryParse(_numeric.text.trim()),
        sortOrder: int.tryParse(_sort.text.trim()) ?? 0,
        active: _active,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PRODUCT TAB
// ════════════════════════════════════════════════════════════════════════════

// ── Komisi tab: per-product (ToC) commission rate ─────────────────────────────

class _KomisiTab extends ConsumerStatefulWidget {
  final MasterDataRepository repo;
  const _KomisiTab({required this.repo});

  @override
  ConsumerState<_KomisiTab> createState() => _KomisiTabState();
}

class _KomisiTabState extends ConsumerState<_KomisiTab> {
  // Daftar/loading/error dipindah ke MasterKomisiNotifier; `_search` (filter UI)
  // tetap di widget.
  MasterKomisiState get _ks => ref.read(masterKomisiProvider);
  MasterKomisiNotifier get _notifier => ref.read(masterKomisiProvider.notifier);
  bool get _loading => _ks.loading;
  String? get _error => _ks.error;
  List<MasterProductRate> get _items => _ks.items;
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.fetch();
    });
  }

  Future<void> _fetch() => _notifier.fetch();

  List<MasterProductRate> get _filtered {
    if (_search.trim().isEmpty) return _items;
    final q = _search.toLowerCase();
    return _items
        .where((p) =>
            p.tocName.toLowerCase().contains(q) ||
            (p.cobName ?? '').toLowerCase().contains(q) ||
            (p.lobName ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(masterKomisiProvider);
    if (_loading) return const SkeletonList(itemCount: 6);
    if (_error != null) {
      return ListView(children: [
        const SizedBox(height: 60),
        ErrorStateView(message: _error!, onRetry: _fetch),
      ]);
    }
    final filtered = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Cari produk / COB…',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceWhite,
              border: OutlineInputBorder(
                borderRadius: AppRadius.radiusMd,
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetch,
            child: filtered.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 100),
                    EmptyStateView(
                      icon: Icons.percent,
                      title: 'Produk tidak ditemukan',
                      subtitle: 'Coba kata kunci lain.',
                    ),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, 80),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final p = filtered[i];
                      return KomisiRateRow(rate: p, onEdit: () => _editRate(p));
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _editRate(MasterProductRate p) async {
    final controller = TextEditingController(
        text: p.percent == null ? '' : _fmtPct(p.percent!));
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => DisposeCallback(
        onDispose: controller.dispose,
        child: AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
        scrollable: true,
        title: Text(p.tocName, style: const TextStyle(fontSize: 16)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Persentase komisi agen dari tiap pembayaran premi produk ini.',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Persentase Komisi',
                  suffixText: '%',
                  hintText: 'mis. 10 atau 12.5',
                ),
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) return 'Isi persentase';
                  final n = double.tryParse(s.replaceAll(',', '.'));
                  if (n == null) return 'Angka tidak valid';
                  if (n < 0 || n > 100) return 'Antara 0 dan 100';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
      ),
    );
    if (saved != true) return;
    final percent = double.parse(controller.text.trim().replaceAll(',', '.'));
    try {
      await widget.repo.updateCommissionRate(p.tocCode, percent / 100);
      if (!mounted) return;
      _snack(context, 'Rate komisi disimpan');
      _fetch();
    } catch (e) {
      if (!mounted) return;
      _snack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  /// Trims a trailing ".0" so 10.0 shows as "10" but 12.5 stays "12.5".
  String _fmtPct(double v) {
    final s = v.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

class _ProductTab extends ConsumerStatefulWidget {
  final MasterDataRepository repo;
  const _ProductTab({required this.repo});

  @override
  ConsumerState<_ProductTab> createState() => _ProductTabState();
}

class _ProductTabState extends ConsumerState<_ProductTab> {
  // DATA/LOADING/ERROR pindah ke MasterProductNotifier; getter berikut
  // memproksinya agar kode build & aksi di bawah tetap memakai nama lama.
  // Pencarian (_query, _searchCtrl) TETAP di widget: itu state tampilan.
  MasterProductState get _ps => ref.read(masterProductProvider);
  MasterProductNotifier get _notifier => ref.read(masterProductProvider.notifier);
  bool get _loading => _ps.loading;
  String? get _error => _ps.error;
  List<ProductItem> get _items => _ps.items;
  List<ProductCategoryItem> get _categories => _ps.categories;

  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Muat setelah frame pertama: state Notifier tak boleh diubah saat build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifier.fetch();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ProductItem> get _filtered {
    if (_query.isEmpty) return _items;
    return _items.where((p) {
      final cat = _categories.where((c) => c.id == p.categoryId).firstOrNull;
      return p.name.toLowerCase().contains(_query) ||
          p.lini.toLowerCase().contains(_query) ||
          (cat?.name.toLowerCase().contains(_query) ?? false);
    }).toList();
  }

  Future<void> _fetch() => _notifier.fetch();

  @override
  Widget build(BuildContext context) {
    // Berlangganan → rebuild otomatis saat daftar/loading berubah (ganti setState).
    ref.watch(masterProductProvider);
    if (_loading) return const SkeletonList(itemCount: 6);
    if (_error != null) {
      return ListView(children: [
        const SizedBox(height: 60),
        ErrorStateView(message: _error!, onRetry: _fetch),
      ]);
    }
    final items = _filtered;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _addFab(() => _openForm(), 'Tambah Produk'),
      body: Column(
        children: [
          _searchField(_searchCtrl, 'Cari produk...', (v) => setState(() => _query = v)),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetch,
              child: items.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 100),
                      EmptyStateView(
                        icon: Icons.inventory_2_outlined,
                        title: _query.isEmpty ? 'Belum ada produk' : 'Tidak ada hasil',
                        subtitle: _query.isEmpty
                            ? 'Tambah produk katalog.'
                            : 'Coba kata kunci lain.',
                      ),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 80),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final p = items[i];
                        final cat = _categories.where((c) => c.id == p.categoryId).firstOrNull;
                        return ProductRow(
                          product: p,
                          category: cat,
                          color: _parseHex(cat?.colorHex),
                          onToggleActive: (v) => _toggleActive(p, v),
                          onEdit: () => _openForm(item: p),
                          onDelete: () => _delete(p),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Optimistic: ubah state lokal dulu, panggil API, revert bila gagal.
  Future<void> _toggleActive(ProductItem p, bool active) async {
    final prev = _items;
    _notifier.setItems(
        [for (final x in _items) x.id == p.id ? x.copyWith(active: active) : x]);
    try {
      await widget.repo.setProductActive(id: p.id, active: active);
    } catch (e) {
      if (!mounted) return;
      _notifier.setItems(prev);
      _snack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _delete(ProductItem p) async {
    if (!await _confirmDelete(context, p.name)) return;
    final prev = _items;
    _notifier.setItems([for (final x in _items) if (x.id != p.id) x]);
    try {
      await widget.repo.deleteProduct(p.id);
      if (!mounted) return;
      _snack(context, 'Produk dihapus');
    } catch (e) {
      if (!mounted) return;
      _notifier.setItems(prev); // kembalikan bila gagal
      _snack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _openForm({ProductItem? item}) async {
    final saved = await showModalBottomSheet<ProductItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      // Lihat catatan di _ParameterTab._openForm: tinggi dibatasi 85% layar.
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ProductForm(repo: widget.repo, item: item, categories: _categories),
    );
    if (saved == null || !mounted) return;
    final i = _items.indexWhere((p) => p.id == saved.id);
    _notifier.setItems(i >= 0
        ? [for (final x in _items) x.id == saved.id ? saved : x]
        : [..._items, saved]);
  }
}

/// Satu baris editor "Jenis Produk" (title + detail), dengan controller sendiri.
class _JenisRow {
  final TextEditingController title;
  final TextEditingController detail;
  _JenisRow({String title = '', String detail = ''})
      : title = TextEditingController(text: title),
        detail = TextEditingController(text: detail);
  void dispose() {
    title.dispose();
    detail.dispose();
  }
}

class _ProductForm extends StatefulWidget {
  final MasterDataRepository repo;
  final ProductItem? item;
  final List<ProductCategoryItem> categories;
  const _ProductForm({required this.repo, this.item, required this.categories});

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  String? _categoryId;
  final List<_JenisRow> _jenis = [];
  late final TextEditingController _desc;
  late final TextEditingController _manfaat;
  // quickFacts
  late final TextEditingController _premi;
  late final TextEditingController _masa;
  late final TextEditingController _nilai;
  // section prosa
  late final TextEditingController _skemaBayar;
  late final TextEditingController _skemaUrl;
  late final TextEditingController _simulasi;
  // section daftar (satu per baris)
  late final TextEditingController _biaya;
  late final TextEditingController _pengecualian;
  late final TextEditingController _persyaratan;
  late final TextEditingController _tataCara;
  late final TextEditingController _persyaratanKlaim;
  late final TextEditingController _tataCaraKlaim;
  late final TextEditingController _risiko;
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _name = TextEditingController(text: it?.name ?? '');
    final catIds = widget.categories.map((c) => c.id).toSet();
    _categoryId = (it?.categoryId != null && catIds.contains(it!.categoryId))
        ? it.categoryId
        : (widget.categories.isNotEmpty ? widget.categories.first.id : null);
    for (final j in it?.jenis ?? const <JenisItem>[]) {
      _jenis.add(_JenisRow(title: j.title, detail: j.detail));
    }
    _desc = TextEditingController(text: it?.description ?? '');
    _manfaat = TextEditingController(text: (it?.manfaat ?? const []).join('\n'));
    _premi = TextEditingController(text: it?.premi ?? '');
    _masa = TextEditingController(text: it?.masaPertanggungan ?? '');
    _nilai = TextEditingController(text: it?.nilaiPertanggungan ?? '');
    _skemaBayar = TextEditingController(text: it?.skemaPembayaran ?? '');
    _skemaUrl = TextEditingController(text: it?.skemaUrl ?? '');
    _simulasi = TextEditingController(text: it?.simulasi ?? '');
    _biaya = TextEditingController(text: (it?.biaya ?? const []).join('\n'));
    _pengecualian = TextEditingController(text: (it?.pengecualian ?? const []).join('\n'));
    _persyaratan = TextEditingController(text: (it?.persyaratan ?? const []).join('\n'));
    _tataCara = TextEditingController(text: (it?.tataCara ?? const []).join('\n'));
    _persyaratanKlaim = TextEditingController(text: (it?.persyaratanKlaim ?? const []).join('\n'));
    _tataCaraKlaim = TextEditingController(text: (it?.tataCaraKlaim ?? const []).join('\n'));
    _risiko = TextEditingController(text: (it?.risiko ?? const []).join('\n'));
    _active = it?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    for (final j in _jenis) {
      j.dispose();
    }
    _desc.dispose();
    _manfaat.dispose();
    _premi.dispose();
    _masa.dispose();
    _nilai.dispose();
    _skemaBayar.dispose();
    _skemaUrl.dispose();
    _simulasi.dispose();
    _biaya.dispose();
    _pengecualian.dispose();
    _persyaratan.dispose();
    _tataCara.dispose();
    _persyaratanKlaim.dispose();
    _tataCaraKlaim.dispose();
    _risiko.dispose();
    super.dispose();
  }

  /// Pisah textarea "satu per baris" menjadi list (buang baris kosong).
  List<String> _lines(TextEditingController c) => c.text
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  String? _nullIfEmpty(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 2),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: AppColors.textSecondary)),
      );

  Widget _jenisRow(int i) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        decoration: BoxDecoration(
          color: AppColors.bgScreen,
          borderRadius: AppRadius.radiusSm,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  TextFormField(
                    controller: _jenis[i].title,
                    decoration: _dec('Judul jenis', hint: 'mis. Bid Bond'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _jenis[i].detail,
                    decoration: _dec('Keterangan'),
                    minLines: 1,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Hapus jenis',
              icon: const Icon(Icons.close, size: 18, color: AppColors.errorRed),
              onPressed: () => setState(() => _jenis.removeAt(i).dispose()),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetGrabber(),
              _sheetTitleBar(context,
                  widget.item == null ? 'Tambah Produk' : 'Edit Produk'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: _dec('Nama Produk'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                isExpanded: true,
                decoration: _dec('Kategori'),
                items: [
                  for (final c in widget.categories)
                    DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
                validator: (v) => (v == null || v.isEmpty) ? 'Wajib dipilih' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                decoration: _dec('Deskripsi'),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _manfaat,
                decoration: _dec('Manfaat (satu per baris)'),
                minLines: 3,
                maxLines: 6,
              ),

              _sectionLabel('Jenis Produk (opsional)'),
              const SizedBox(height: 6),
              for (var i = 0; i < _jenis.length; i++) _jenisRow(i),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _jenis.add(_JenisRow())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah Jenis'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primaryNavy),
                ),
              ),

              _sectionLabel('Sekilas (opsional)'),
              const SizedBox(height: 8),
              TextFormField(controller: _premi, decoration: _dec('Premi', hint: 'mis. Sesuai tarif OJK')),
              const SizedBox(height: 12),
              TextFormField(controller: _masa, decoration: _dec('Masa Pertanggungan', hint: 'mis. Maks. 12 bulan')),
              const SizedBox(height: 12),
              TextFormField(controller: _nilai, decoration: _dec('Nilai Pertanggungan', hint: 'mis. Sesuai nilai proyek')),

              _sectionLabel('Detail (opsional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _biaya,
                decoration: _dec('Biaya (satu per baris)'),
                minLines: 2,
                maxLines: 5,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _skemaBayar,
                decoration: _dec('Skema Pembayaran Premi'),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pengecualian,
                decoration: _dec('Pengecualian (satu per baris)'),
                minLines: 2,
                maxLines: 6,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _persyaratan,
                decoration: _dec('Persyaratan Penutupan (satu per baris)'),
                minLines: 2,
                maxLines: 6,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tataCara,
                decoration: _dec('Tata Cara Penutupan (satu langkah per baris)'),
                minLines: 2,
                maxLines: 6,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _persyaratanKlaim,
                decoration: _dec('Persyaratan Klaim (satu per baris)'),
                minLines: 2,
                maxLines: 6,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tataCaraKlaim,
                decoration: _dec('Tata Cara Klaim (satu langkah per baris)'),
                minLines: 2,
                maxLines: 6,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _risiko,
                decoration: _dec('Risiko (satu per baris)'),
                minLines: 2,
                maxLines: 5,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _simulasi,
                decoration: _dec('Contoh Simulasi'),
                minLines: 2,
                maxLines: 5,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _skemaUrl,
                decoration: _dec('URL Skema Produk (opsional)', hint: 'link Google Drive'),
                keyboardType: TextInputType.url,
              ),

              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktif', style: TextStyle(fontSize: 14)),
                value: _active,
                activeThumbColor: AppColors.successGreen,
                onChanged: (v) => setState(() => _active = v),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final manfaat = _manfaat.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final cat = widget.categories.where((c) => c.id == _categoryId).firstOrNull;
      final jenis = [
        for (final j in _jenis)
          if (j.title.text.trim().isNotEmpty)
            JenisItem(title: j.title.text.trim(), detail: j.detail.text.trim()),
      ];
      final saved = await widget.repo.saveProduct(
        id: widget.item?.id,
        name: _name.text.trim(),
        lini: cat?.name ?? _categoryId ?? 'Lainnya',
        categoryId: _categoryId,
        jenis: jenis,
        icon: null,
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        manfaat: manfaat,
        premi: _nullIfEmpty(_premi),
        masaPertanggungan: _nullIfEmpty(_masa),
        nilaiPertanggungan: _nullIfEmpty(_nilai),
        skemaPembayaran: _nullIfEmpty(_skemaBayar),
        skemaUrl: _nullIfEmpty(_skemaUrl),
        simulasi: _nullIfEmpty(_simulasi),
        biaya: _lines(_biaya),
        pengecualian: _lines(_pengecualian),
        persyaratan: _lines(_persyaratan),
        tataCara: _lines(_tataCara),
        persyaratanKlaim: _lines(_persyaratanKlaim),
        tataCaraKlaim: _lines(_tataCaraKlaim),
        risiko: _lines(_risiko),
        active: _active,
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BROKER TAB
// ════════════════════════════════════════════════════════════════════════════

class _BrokerTab extends ConsumerStatefulWidget {
  final MasterDataRepository repo;
  const _BrokerTab({required this.repo});

  @override
  ConsumerState<_BrokerTab> createState() => _BrokerTabState();
}

class _BrokerTabState extends ConsumerState<_BrokerTab> {
  // Daftar/loading/error dipindah ke MasterBrokerNotifier.
  MasterBrokerState get _bs => ref.read(masterBrokerProvider);
  MasterBrokerNotifier get _notifier => ref.read(masterBrokerProvider.notifier);
  bool get _loading => _bs.loading;
  String? get _error => _bs.error;
  List<BrokerItem> get _items => _bs.items;

  // Pencarian client-side (daftar broker dimuat sekaligus, ±150 baris).
  final _searchCtrl = TextEditingController();
  String _search = '';

  List<BrokerItem> get _filtered {
    if (_search.isEmpty) return _items;
    return _items
        .where((b) =>
            b.name.toLowerCase().contains(_search) ||
            b.brokerCode.toLowerCase().contains(_search))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.fetch();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() => _notifier.fetch();

  @override
  Widget build(BuildContext context) {
    ref.watch(masterBrokerProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _addFab(() => _openForm(), 'Tambah Broker'),
      body: _loading
          ? const SkeletonList(itemCount: 6)
          : _error != null
              ? ListView(children: [
                  const SizedBox(height: 60),
                  ErrorStateView(message: _error!, onRetry: _fetch),
                ])
              : Column(
                  children: [
                    _searchField(_searchCtrl, 'Cari nama atau kode broker',
                        (v) => setState(() => _search = v)),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _fetch,
                        child: _buildList(),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildList() {
    final items = _filtered;
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          EmptyStateView(
            icon: _search.isEmpty ? Icons.handshake_outlined : Icons.search_off,
            title: _search.isEmpty ? 'Belum ada broker' : 'Tidak ada hasil',
            subtitle: _search.isEmpty
                ? 'Tambah broker mitra.'
                : 'Tidak ada broker yang cocok dengan "$_search".',
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 80),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final b = items[i];
        return BrokerRow(
          broker: b,
          onEdit: () => _openForm(item: b),
          onDelete: () => _delete(b),
        );
      },
    );
  }

  Future<void> _delete(BrokerItem b) async {
    if (!await _confirmDelete(context, b.name)) return;
    try {
      await widget.repo.deleteBroker(b.id);
      if (!mounted) return;
      _snack(context, 'Broker dihapus');
      _fetch();
    } catch (e) {
      if (!mounted) return;
      _snack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _openForm({BrokerItem? item}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BrokerForm(repo: widget.repo, item: item),
    );
    if (saved == true) _fetch();
  }
}

class _BrokerForm extends StatefulWidget {
  final MasterDataRepository repo;
  final BrokerItem? item;
  const _BrokerForm({required this.repo, this.item});

  @override
  State<_BrokerForm> createState() => _BrokerFormState();
}

class _BrokerFormState extends State<_BrokerForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.item?.brokerCode ?? '');
    _name = TextEditingController(text: widget.item?.name ?? '');
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      // Isi sheet bisa lebih tinggi dari layar (mis. daftar chip kategori,
      // atau keyboard terbuka di layar pendek) -> harus bisa di-scroll,
      // kalau tidak muncul garis kuning 'BOTTOM OVERFLOWED BY ... PIXELS'.
      child: SingleChildScrollView(
        child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetGrabber(),
            Text(widget.item == null ? 'Tambah Broker' : 'Edit Broker',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _code,
              decoration: _dec('Kode Broker'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: _dec('Nama Broker'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.repo.saveBroker(
        id: widget.item?.id,
        brokerCode: _code.text.trim(),
        name: _name.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }
}

// ── Bank tab: bank (induk) + cabang, admin-editable ───────────────────────────

Widget _saveBtn(bool saving, VoidCallback onPressed) => SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: saving ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryNavy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
        ),
        child: saving
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );

Widget _simpleSearchField(String hint, ValueChanged<String> onChanged) => Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceWhite,
          border: OutlineInputBorder(
            borderRadius: AppRadius.radiusMd,
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );

class _BankTab extends ConsumerStatefulWidget {
  final MasterDataRepository repo;
  const _BankTab({required this.repo});

  @override
  ConsumerState<_BankTab> createState() => _BankTabState();
}

class _BankTabState extends ConsumerState<_BankTab> {
  // Daftar/loading/error dipindah ke MasterBankNotifier; `_search` tetap di widget.
  MasterBankState get _bs => ref.read(masterBankProvider);
  MasterBankNotifier get _notifier => ref.read(masterBankProvider.notifier);
  bool get _loading => _bs.loading;
  String? get _error => _bs.error;
  List<BankItem> get _items => _bs.items;
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.fetch();
    });
  }

  Future<void> _fetch() => _notifier.fetch();

  List<BankItem> get _filtered {
    if (_search.trim().isEmpty) return _items;
    final q = _search.toLowerCase();
    return _items
        .where((b) =>
            b.name.toLowerCase().contains(q) ||
            (b.tipeBank ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(masterBankProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _addFab(() => _openForm(), 'Tambah Bank'),
      body: _loading
          ? const SkeletonList(itemCount: 6)
          : _error != null
              ? ListView(children: [
                  const SizedBox(height: 60),
                  ErrorStateView(message: _error!, onRetry: _fetch),
                ])
              : Column(
                  children: [
                    _simpleSearchField('Cari bank…', (v) => setState(() => _search = v)),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _fetch,
                        child: _filtered.isEmpty
                            ? ListView(children: const [
                                SizedBox(height: 100),
                                EmptyStateView(
                                  icon: Icons.account_balance_outlined,
                                  title: 'Tidak ada bank',
                                  subtitle: 'Tambah bank atau ubah pencarian.',
                                ),
                              ])
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.lg, 0, AppSpacing.lg, 80),
                                itemCount: _filtered.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final b = _filtered[i];
                                  return BankRow(
                                    bank: b,
                                    onOpenBranches: () => _openBranches(b),
                                    onEdit: () => _openForm(item: b),
                                    onDelete: () => _delete(b),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }

  void _openBranches(BankItem b) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _BankBranchesScreen(repo: widget.repo, bank: b)));
  }

  Future<void> _delete(BankItem b) async {
    if (!await _confirmDelete(context, '${b.name} (beserta cabangnya)')) return;
    try {
      await widget.repo.deleteBank(b.id);
      if (!mounted) return;
      _snack(context, 'Bank dihapus');
      _fetch();
    } catch (e) {
      if (!mounted) return;
      _snack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _openForm({BankItem? item}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _BankForm(repo: widget.repo, item: item),
    );
    if (saved == true) _fetch();
  }
}

class _BankForm extends StatefulWidget {
  final MasterDataRepository repo;
  final BankItem? item;
  const _BankForm({required this.repo, this.item});

  @override
  State<_BankForm> createState() => _BankFormState();
}

class _BankFormState extends State<_BankForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _tipe;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item?.name ?? '');
    _tipe = TextEditingController(text: widget.item?.tipeBank ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _tipe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      // Isi sheet bisa lebih tinggi dari layar (mis. daftar chip kategori,
      // atau keyboard terbuka di layar pendek) -> harus bisa di-scroll,
      // kalau tidak muncul garis kuning 'BOTTOM OVERFLOWED BY ... PIXELS'.
      child: SingleChildScrollView(
        child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.item == null ? 'Tambah Bank' : 'Edit Bank',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: _dec('Nama Bank'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tipe,
              decoration: _dec('Tipe Bank (opsional)',
                  hint: 'HIMBARA = bank BUMN; mis. SWASTA/BPD'),
            ),
            const SizedBox(height: 16),
            _saveBtn(_saving, _save),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.repo.saveBank(
        id: widget.item?.id,
        name: _name.text.trim(),
        tipeBank: _tipe.text.trim().isEmpty ? null : _tipe.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }
}

class _BankBranchesScreen extends ConsumerStatefulWidget {
  final MasterDataRepository repo;
  final BankItem bank;
  const _BankBranchesScreen({required this.repo, required this.bank});

  @override
  ConsumerState<_BankBranchesScreen> createState() => _BankBranchesScreenState();
}

class _BankBranchesScreenState extends ConsumerState<_BankBranchesScreen> {
  // DATA/LOADING/ERROR pindah ke MasterBankBranchNotifier; kolom cari (_search)
  // TETAP di widget karena murni tampilan.
  MasterBankBranchState get _bs => ref.read(masterBankBranchProvider);
  MasterBankBranchNotifier get _notifier =>
      ref.read(masterBankBranchProvider.notifier);
  bool get _loading => _bs.loading;
  String? get _error => _bs.error;
  List<BankBranchItem> get _items => _bs.items;

  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifier.start(widget.bank.id);
    });
  }

  Future<void> _fetch() => _notifier.fetch();

  List<BankBranchItem> get _filtered {
    if (_search.trim().isEmpty) return _items;
    final q = _search.toLowerCase();
    return _items
        .where((b) =>
            b.name.toLowerCase().contains(q) ||
            (b.address ?? '').toLowerCase().contains(q) ||
            (b.cifNo ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(masterBankBranchProvider);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: AppBar(
        title: Text('Cabang • ${widget.bank.name}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.surfaceWhite,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: _addFab(() => _openForm(), 'Tambah Cabang'),
      body: _loading
          ? const SkeletonList(itemCount: 6)
          : _error != null
              ? ListView(children: [
                  const SizedBox(height: 60),
                  ErrorStateView(message: _error!, onRetry: _fetch),
                ])
              : Column(
                  children: [
                    _simpleSearchField('Cari cabang…', (v) => setState(() => _search = v)),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _fetch,
                        child: _filtered.isEmpty
                            ? ListView(children: const [
                                SizedBox(height: 100),
                                EmptyStateView(
                                  icon: Icons.location_city_outlined,
                                  title: 'Belum ada cabang',
                                  subtitle: 'Tambah cabang untuk bank ini.',
                                ),
                              ])
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.lg, 0, AppSpacing.lg, 80),
                                itemCount: _filtered.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final b = _filtered[i];
                                  return BankBranchRow(
                                    branch: b,
                                    onEdit: () => _openForm(item: b),
                                    onDelete: () => _delete(b),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _delete(BankBranchItem b) async {
    if (!await _confirmDelete(context, b.name)) return;
    try {
      await widget.repo.deleteBankBranch(widget.bank.id, b.id);
      if (!mounted) return;
      _snack(context, 'Cabang dihapus');
      _fetch();
    } catch (e) {
      if (!mounted) return;
      _snack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _openForm({BankBranchItem? item}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _BankBranchForm(repo: widget.repo, bankId: widget.bank.id, item: item),
    );
    if (saved == true) _fetch();
  }
}

class _BankBranchForm extends StatefulWidget {
  final MasterDataRepository repo;
  final String bankId;
  final BankBranchItem? item;
  const _BankBranchForm({required this.repo, required this.bankId, this.item});

  @override
  State<_BankBranchForm> createState() => _BankBranchFormState();
}

class _BankBranchFormState extends State<_BankBranchForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _cif;
  late final TextEditingController _address;
  late final TextEditingController _kode;
  late final TextEditingController _tipe;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item?.name ?? '');
    _cif = TextEditingController(text: widget.item?.cifNo ?? '');
    _address = TextEditingController(text: widget.item?.address ?? '');
    _kode = TextEditingController(text: widget.item?.kodeUnitKerja ?? '');
    _tipe = TextEditingController(text: widget.item?.tipeBank ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _cif.dispose();
    _address.dispose();
    _kode.dispose();
    _tipe.dispose();
    super.dispose();
  }

  String? _orNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.item == null ? 'Tambah Cabang' : 'Edit Cabang',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: _dec('Nama Cabang'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _cif, decoration: _dec('No. CIF (opsional)')),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _address,
                  decoration: _dec('Alamat (opsional)'),
                  maxLines: 2),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _kode,
                  decoration: _dec('Kode Unit Kerja (opsional)')),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _tipe,
                  decoration: _dec('Tipe Bank (opsional)', hint: 'mis. HIMBARA')),
              const SizedBox(height: 16),
              _saveBtn(_saving, _save),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.repo.saveBankBranch(
        widget.bankId,
        id: widget.item?.id,
        name: _name.text.trim(),
        cifNo: _orNull(_cif),
        address: _orNull(_address),
        kodeUnitKerja: _orNull(_kode),
        tipeBank: _orNull(_tipe),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BUMN TAB — pohon ekosistem BUMN (master_bumn), admin-editable, with parent pick
// ════════════════════════════════════════════════════════════════════════════

/// Nilai level & badan hukum sesuai kolom master_bumn (lihat V1__baseline.sql).
const List<String> _kBumnLevels = ['Induk', 'Anak', 'Cucu', 'Cicit'];
const List<String> _kBumnBadanHukum = ['PT', 'PT Tbk', 'CV', 'UD', 'Lainnya'];

class _BumnTab extends ConsumerStatefulWidget {
  final MasterDataRepository repo;
  const _BumnTab({required this.repo});

  @override
  ConsumerState<_BumnTab> createState() => _BumnTabState();
}

class _BumnTabState extends ConsumerState<_BumnTab> {
  // Daftar/loading/error dipindah ke MasterBumnNotifier; `_search` tetap di widget.
  MasterBumnState get _bs => ref.read(masterBumnProvider);
  MasterBumnNotifier get _notifier => ref.read(masterBumnProvider.notifier);
  bool get _loading => _bs.loading;
  String? get _error => _bs.error;
  List<BumnMasterItem> get _items => _bs.items;
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.fetch();
    });
  }

  Future<void> _fetch() => _notifier.fetch();

  List<BumnMasterItem> get _filtered {
    if (_search.trim().isEmpty) return _items;
    final q = _search.toLowerCase();
    return _items
        .where((b) =>
            b.name.toLowerCase().contains(q) ||
            (b.parentName ?? '').toLowerCase().contains(q) ||
            (b.level ?? '').toLowerCase().contains(q) ||
            (b.badanHukum ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(masterBumnProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _addFab(() => _openForm(), 'Tambah BUMN'),
      body: _loading
          ? const SkeletonList(itemCount: 6)
          : _error != null
              ? ListView(children: [
                  const SizedBox(height: 60),
                  ErrorStateView(message: _error!, onRetry: _fetch),
                ])
              : Column(
                  children: [
                    _simpleSearchField('Cari BUMN / induk…', (v) => setState(() => _search = v)),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _fetch,
                        child: _filtered.isEmpty
                            ? ListView(children: const [
                                SizedBox(height: 100),
                                EmptyStateView(
                                  icon: Icons.account_tree_outlined,
                                  title: 'Tidak ada BUMN',
                                  subtitle: 'Tambah BUMN atau ubah pencarian.',
                                ),
                              ])
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.lg, 0, AppSpacing.lg, 80),
                                itemCount: _filtered.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final b = _filtered[i];
                                  return BumnRow(
                                    item: b,
                                    onEdit: () => _openForm(item: b),
                                    onDelete: () => _delete(b),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _delete(BumnMasterItem b) async {
    if (!await _confirmDelete(context, b.name)) return;
    try {
      await widget.repo.deleteBumn(b.id);
      if (!mounted) return;
      _snack(context, 'BUMN dihapus');
      _fetch();
    } catch (e) {
      if (!mounted) return;
      _snack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _openForm({BumnMasterItem? item}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _BumnForm(repo: widget.repo, item: item, allItems: _items),
    );
    if (saved == true) _fetch();
  }
}

class _BumnForm extends StatefulWidget {
  final MasterDataRepository repo;
  final BumnMasterItem? item;

  /// Semua BUMN yang sudah ada — sumber pilihan induk (parent picker).
  final List<BumnMasterItem> allItems;

  const _BumnForm({required this.repo, this.item, required this.allItems});

  @override
  State<_BumnForm> createState() => _BumnFormState();
}

class _BumnFormState extends State<_BumnForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  String? _level;
  String? _badanHukum;
  String? _parentId;
  String? _parentName;
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _name = TextEditingController(text: it?.name ?? '');
    _level = it?.level;
    _badanHukum = it?.badanHukum;
    _parentId = it?.parentId;
    _parentName = it?.parentName;
    _active = it?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// DropdownButtonFormField items, ensuring an unknown current value still shows.
  List<DropdownMenuItem<String>> _dropItems(List<String> base, String? current) {
    final values = [...base];
    if (current != null && current.isNotEmpty && !values.contains(current)) {
      values.add(current);
    }
    return [
      for (final v in values)
        DropdownMenuItem<String>(value: v, child: Text(v, style: const TextStyle(fontSize: 14))),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.item == null ? 'Tambah BUMN' : 'Edit BUMN',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: _dec('Nama BUMN'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _level,
                isExpanded: true,
                decoration: _dec('Level (opsional)', hint: 'Induk / Anak / Cucu / Cicit'),
                items: _dropItems(_kBumnLevels, _level),
                onChanged: (v) => setState(() => _level = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _badanHukum,
                isExpanded: true,
                decoration: _dec('Badan Hukum (opsional)', hint: 'PT / PT Tbk / CV / UD / Lainnya'),
                items: _dropItems(_kBumnBadanHukum, _badanHukum),
                onChanged: (v) => setState(() => _badanHukum = v),
              ),
              const SizedBox(height: 12),
              _parentField(),
              const SizedBox(height: 4),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktif', style: TextStyle(fontSize: 14)),
                value: _active,
                activeThumbColor: AppColors.successGreen,
                onChanged: (v) => setState(() => _active = v),
              ),
              const SizedBox(height: 8),
              _saveBtn(_saving, _save),
            ],
          ),
        ),
      ),
    );
  }

  Widget _parentField() {
    final hasParent = _parentId != null && _parentId!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 6),
          child: Text('Induk (opsional)',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ),
        InkWell(
          onTap: _pickParent,
          borderRadius: AppRadius.radiusSm,
          child: InputDecorator(
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(borderRadius: AppRadius.radiusSm),
              hintText: 'Pilih induk dari BUMN yang sudah ada',
              suffixIcon: hasParent
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Jadikan Induk teratas',
                      onPressed: () => setState(() {
                        _parentId = null;
                        _parentName = null;
                      }),
                    )
                  : const Icon(Icons.search, size: 18),
            ),
            child: Text(
              hasParent ? _parentName ?? _parentId! : 'Tanpa induk (Induk teratas)',
              style: TextStyle(
                fontSize: 14,
                color: hasParent ? AppColors.textPrimary : AppColors.grayStage,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickParent() async {
    // Kandidat: semua BUMN kecuali dirinya sendiri (siklus divalidasi lagi server-side).
    final candidates =
        widget.allItems.where((b) => b.id != widget.item?.id).toList();
    final picked = await showModalBottomSheet<BumnMasterItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _BumnParentPicker(items: candidates),
    );
    if (picked != null) {
      setState(() {
        _parentId = picked.id;
        _parentName = picked.name;
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.repo.saveBumn(
        id: widget.item?.id,
        name: _name.text.trim(),
        level: _level,
        badanHukum: _badanHukum,
        parentId: _parentId,
        active: _active,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }
}

/// Searchable picker over existing BUMN to choose a parent (induk). Pops the chosen
/// [BumnMasterItem]; pops null on cancel (clearing is handled by the form's field).
class _BumnParentPicker extends StatefulWidget {
  final List<BumnMasterItem> items;
  const _BumnParentPicker({required this.items});

  @override
  State<_BumnParentPicker> createState() => _BumnParentPickerState();
}

class _BumnParentPickerState extends State<_BumnParentPicker> {
  String _search = '';

  List<BumnMasterItem> get _filtered {
    if (_search.trim().isEmpty) return widget.items;
    final q = _search.toLowerCase();
    return widget.items.where((b) => b.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    // Lift above the keyboard and size against the remaining visible area so
    // the sheet never gets pushed to the very top of the screen.
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
      height: (mq.size.height - mq.viewInsets.bottom) * 0.75,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Pilih Induk BUMN',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          _simpleSearchField('Cari BUMN…', (v) => setState(() => _search = v)),
          Expanded(
            child: filtered.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 80),
                    EmptyStateView(
                      icon: Icons.search_off,
                      title: 'Tidak ditemukan',
                      subtitle: 'Coba kata kunci lain.',
                    ),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final b = filtered[i];
                      final sub = [
                        if (b.level != null && b.level!.isNotEmpty) b.level!,
                        if (b.badanHukum != null && b.badanHukum!.isNotEmpty) b.badanHukum!,
                      ].join(' • ');
                      return ListTile(
                        dense: true,
                        title: Text(b.name, style: const TextStyle(fontSize: 14)),
                        subtitle: sub.isEmpty
                            ? null
                            : Text(sub,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary)),
                        onTap: () => Navigator.of(context).pop(b),
                      );
                    },
                  ),
          ),
        ],
      ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CATEGORY TAB (kategori produk)
// ════════════════════════════════════════════════════════════════════════════

/// Nama ikon yang didukung UI (dipetakan ke Material via pkCategoryIcon).
const List<String> _kCategoryIcons = [
  'shield-check', 'trending-up', 'building-2', 'hard-hat', 'car',
  'scale', 'heart-pulse', 'ship', 'sprout', 'shapes',
];

Color _parseHex(String? hex, {Color fallback = AppColors.primaryNavy}) {
  if (hex == null) return fallback;
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

class _CategoryTab extends ConsumerStatefulWidget {
  final MasterDataRepository repo;
  const _CategoryTab({required this.repo});

  @override
  ConsumerState<_CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends ConsumerState<_CategoryTab> {
  // DATA/LOADING/ERROR pindah ke MasterCategoryNotifier.
  MasterCategoryState get _cs => ref.read(masterCategoryProvider);
  MasterCategoryNotifier get _notifier => ref.read(masterCategoryProvider.notifier);
  bool get _loading => _cs.loading;
  String? get _error => _cs.error;
  List<ProductCategoryItem> get _items => _cs.items;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifier.fetch();
    });
  }

  Future<void> _fetch() => _notifier.fetch();

  @override
  Widget build(BuildContext context) {
    ref.watch(masterCategoryProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _addFab(() => _openForm(), 'Tambah Kategori'),
      body: _loading
          ? const SkeletonList(itemCount: 6)
          : _error != null
              ? ListView(children: [
                  const SizedBox(height: 60),
                  ErrorStateView(message: _error!, onRetry: _fetch),
                ])
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: _items.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 100),
                          EmptyStateView(
                            icon: Icons.category_outlined,
                            title: 'Belum ada kategori',
                            subtitle: 'Tambah kategori produk.',
                          ),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 80),
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final c = _items[i];
                            return CategoryRow(
                              item: c,
                              color: _parseHex(c.colorHex),
                              onEdit: () => _openForm(item: c),
                              onDelete: () => _delete(c),
                            );
                          },
                        ),
                ),
    );
  }

  Future<void> _delete(ProductCategoryItem c) async {
    if (!await _confirmDelete(context, c.name)) return;
    final prev = _items;
    _notifier.setItems([for (final x in _items) if (x.id != c.id) x]);
    try {
      await widget.repo.deleteProductCategory(c.id);
      if (!mounted) return;
      _snack(context, 'Kategori dihapus');
    } catch (e) {
      if (!mounted) return;
      _notifier.setItems(prev); // revert (mis. kategori masih dipakai)
      _snack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _openForm({ProductCategoryItem? item}) async {
    final saved = await showModalBottomSheet<ProductCategoryItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CategoryForm(repo: widget.repo, item: item),
    );
    if (saved == null || !mounted) return;
    final i = _items.indexWhere((c) => c.id == saved.id);
    _notifier.setItems(i >= 0
        ? [for (final x in _items) x.id == saved.id ? saved : x]
        : [..._items, saved]);
  }
}

class _CategoryForm extends StatefulWidget {
  final MasterDataRepository repo;
  final ProductCategoryItem? item;
  const _CategoryForm({required this.repo, this.item});

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _color;
  late final TextEditingController _sort;
  String _icon = 'shapes';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _name = TextEditingController(text: it?.name ?? '');
    _color = TextEditingController(text: it?.colorHex ?? '#0D2C54');
    _sort = TextEditingController(text: (it?.sortOrder ?? 0).toString());
    _icon = (it?.icon != null && _kCategoryIcons.contains(it!.icon)) ? it.icon! : 'shapes';
  }

  @override
  void dispose() {
    _name.dispose();
    _color.dispose();
    _sort.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _parseHex(_color.text);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      // Isi sheet bisa lebih tinggi dari layar (mis. daftar chip kategori,
      // atau keyboard terbuka di layar pendek) -> harus bisa di-scroll,
      // kalau tidak muncul garis kuning 'BOTTOM OVERFLOWED BY ... PIXELS'.
      child: SingleChildScrollView(
        child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetGrabber(),
            Text(widget.item == null ? 'Tambah Kategori' : 'Edit Kategori',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: _dec('Nama Kategori', hint: 'mis. Properti & Harta Benda'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _icon,
              isExpanded: true,
              decoration: _dec('Ikon'),
              items: [
                for (final ic in _kCategoryIcons)
                  DropdownMenuItem(
                    value: ic,
                    child: Row(children: [
                      Icon(pkCategoryIcon(ic), size: 18, color: preview),
                      const SizedBox(width: 10),
                      Text(ic),
                    ]),
                  ),
              ],
              onChanged: (v) => setState(() => _icon = v ?? 'shapes'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _color,
                  decoration: _dec('Warna (hex)', hint: '#0D2C54'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: preview,
                  borderRadius: AppRadius.radiusSm,
                  border: Border.all(color: AppColors.border),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sort,
              keyboardType: TextInputType.number,
              decoration: _dec('Urutan'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final saved = await widget.repo.saveProductCategory(
        id: widget.item?.id,
        name: _name.text.trim(),
        icon: _icon,
        colorHex: _color.text.trim().isEmpty ? null : _color.text.trim(),
        sortOrder: int.tryParse(_sort.text.trim()) ?? 0,
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// KANTOR TAB (offices: kanwil → cabang → KUP, admin-editable)
// ════════════════════════════════════════════════════════════════════════════

/// Office type code → Indonesian label.
String _officeTypeLabel(String type) => switch (type) {
      'REGIONAL' => 'Kanwil',
      'BRANCH' => 'Cabang',
      'KUP' => 'KUP/Connect',
      _ => type,
    };

const List<String> _kOfficeTypes = ['REGIONAL', 'BRANCH', 'KUP'];

class _OfficeTab extends ConsumerStatefulWidget {
  final MasterDataRepository repo;
  const _OfficeTab({required this.repo});

  @override
  ConsumerState<_OfficeTab> createState() => _OfficeTabState();
}

class _OfficeTabState extends ConsumerState<_OfficeTab> {
  // Daftar/loading/error dipindah ke MasterOfficeNotifier; `_search` tetap di widget.
  MasterOfficeState get _os => ref.read(masterOfficeProvider);
  MasterOfficeNotifier get _notifier => ref.read(masterOfficeProvider.notifier);
  bool get _loading => _os.loading;
  String? get _error => _os.error;
  List<OfficeAdminItem> get _items => _os.items;
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.fetch();
    });
  }

  Future<void> _fetch() => _notifier.fetch();

  /// Sort: kanwil → cabang → KUP, then by id — so the flat list reads top-down.
  List<OfficeAdminItem> get _sorted {
    int rank(String t) => _kOfficeTypes.indexOf(t);
    final list = [..._items]
      ..sort((a, b) {
        final r = rank(a.type).compareTo(rank(b.type));
        return r != 0 ? r : a.id.compareTo(b.id);
      });
    if (_search.trim().isEmpty) return list;
    final q = _search.toLowerCase();
    return list
        .where((o) =>
            o.name.toLowerCase().contains(q) ||
            o.id.toLowerCase().contains(q) ||
            (o.parentName ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(masterOfficeProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _addFab(() => _openForm(), 'Tambah Kantor'),
      body: _loading
          ? const SkeletonList(itemCount: 6)
          : _error != null
              ? ListView(children: [
                  const SizedBox(height: 60),
                  ErrorStateView(message: _error!, onRetry: _fetch),
                ])
              : Column(
                  children: [
                    _simpleSearchField('Cari kantor / kode / induk…',
                        (v) => setState(() => _search = v)),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _fetch,
                        child: _sorted.isEmpty
                            ? ListView(children: const [
                                SizedBox(height: 100),
                                EmptyStateView(
                                  icon: Icons.apartment_outlined,
                                  title: 'Tidak ada kantor',
                                  subtitle: 'Tambah kanwil / cabang / KUP.',
                                ),
                              ])
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.lg, 0, AppSpacing.lg, 80),
                                itemCount: _sorted.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final o = _sorted[i];
                                  return OfficeRow(
                                    office: o,
                                    onEdit: () => _openForm(item: o),
                                    onDelete: () => _delete(o),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _delete(OfficeAdminItem o) async {
    if (!await _confirmDelete(context, o.name)) return;
    try {
      await widget.repo.deleteOffice(o.id);
      if (!mounted) return;
      _snack(context, 'Kantor dinonaktifkan');
      _fetch();
    } catch (e) {
      if (!mounted) return;
      _snack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _openForm({OfficeAdminItem? item}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _OfficeForm(repo: widget.repo, item: item, allItems: _items),
    );
    if (saved == true) _fetch();
  }
}

class _OfficeForm extends StatefulWidget {
  final MasterDataRepository repo;
  final OfficeAdminItem? item;

  /// All offices — source for the parent picker (filtered by chosen type).
  final List<OfficeAdminItem> allItems;

  const _OfficeForm({required this.repo, this.item, required this.allItems});

  @override
  State<_OfficeForm> createState() => _OfficeFormState();
}

class _OfficeFormState extends State<_OfficeForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _id;
  late final TextEditingController _name;
  String _type = 'BRANCH';
  String? _parentId;
  String? _parentName;
  bool _active = true;
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _id = TextEditingController(text: it?.id ?? '');
    _name = TextEditingController(text: it?.name ?? '');
    _type = it?.type ?? 'BRANCH';
    _parentId = it?.parentId;
    _parentName = it?.parentName;
    _active = it?.active ?? true;
  }

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    super.dispose();
  }

  /// Parent candidates for the current type: BRANCH → kanwil, KUP → cabang.
  List<OfficeAdminItem> get _parentCandidates {
    final want = _type == 'KUP' ? 'BRANCH' : (_type == 'BRANCH' ? 'REGIONAL' : null);
    if (want == null) return const [];
    return widget.allItems
        .where((o) => o.type == want && o.active && o.id != widget.item?.id)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isEdit ? 'Edit Kantor' : 'Tambah Kantor',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _id,
                enabled: !_isEdit, // id is the primary key — fixed after creation
                textCapitalization: TextCapitalization.characters,
                decoration: _dec('Kode Kantor', hint: 'mis. KC-060, KUP-001, KW-08'),
                validator: (v) =>
                    (!_isEdit && (v == null || v.trim().isEmpty)) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: _dec('Nama Kantor'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                isExpanded: true,
                decoration: _dec('Tipe Kantor'),
                items: [
                  for (final t in _kOfficeTypes)
                    DropdownMenuItem(
                        value: t,
                        child: Text('${_officeTypeLabel(t)} ($t)',
                            style: const TextStyle(fontSize: 14))),
                ],
                onChanged: (v) => setState(() {
                  _type = v ?? _type;
                  // Parent set no longer applies when the type changes.
                  _parentId = null;
                  _parentName = null;
                }),
              ),
              const SizedBox(height: 12),
              if (_type != 'REGIONAL') _parentField(),
              const SizedBox(height: 4),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktif', style: TextStyle(fontSize: 14)),
                value: _active,
                activeThumbColor: AppColors.successGreen,
                onChanged: (v) => setState(() => _active = v),
              ),
              const SizedBox(height: 8),
              _saveBtn(_saving, _save),
            ],
          ),
        ),
      ),
    );
  }

  Widget _parentField() {
    final hasParent = _parentId != null && _parentId!.isNotEmpty;
    final mustHaveParent = _type == 'KUP';
    final label = _type == 'KUP' ? 'Cabang induk (wajib)' : 'Kanwil (opsional)';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ),
        InkWell(
          onTap: _pickParent,
          borderRadius: AppRadius.radiusSm,
          child: InputDecorator(
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(borderRadius: AppRadius.radiusSm),
              suffixIcon: hasParent && !mustHaveParent
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Tanpa induk',
                      onPressed: () => setState(() {
                        _parentId = null;
                        _parentName = null;
                      }),
                    )
                  : const Icon(Icons.search, size: 18),
            ),
            child: Text(
              hasParent
                  ? (_parentName ?? _parentId!)
                  : (mustHaveParent ? 'Pilih cabang induk' : 'Tanpa induk (langsung kantor pusat)'),
              style: TextStyle(
                fontSize: 14,
                color: hasParent ? AppColors.textPrimary : AppColors.grayStage,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickParent() async {
    final candidates = _parentCandidates;
    if (candidates.isEmpty) {
      _snack(context,
          _type == 'KUP' ? 'Belum ada Cabang aktif' : 'Belum ada Kanwil aktif',
          isError: true);
      return;
    }
    final picked = await showModalBottomSheet<OfficeAdminItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _OfficeParentPicker(
        items: candidates,
        title: _type == 'KUP' ? 'Pilih Cabang Induk' : 'Pilih Kanwil',
      ),
    );
    if (picked != null) {
      setState(() {
        _parentId = picked.id;
        _parentName = picked.name;
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_type == 'KUP' && (_parentId == null || _parentId!.isEmpty)) {
      _snack(context, 'KUP wajib punya cabang induk', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repo.saveOffice(
        id: widget.item?.id,
        newId: _isEdit ? null : _id.text.trim().toUpperCase(),
        name: _name.text.trim(),
        type: _type,
        parentId: _type == 'REGIONAL' ? null : _parentId,
        active: _active,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(context, e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }
}

/// Searchable picker over candidate offices to choose a parent. Pops the chosen
/// [OfficeAdminItem]; pops null on cancel.
class _OfficeParentPicker extends StatefulWidget {
  final List<OfficeAdminItem> items;
  final String title;
  const _OfficeParentPicker({required this.items, required this.title});

  @override
  State<_OfficeParentPicker> createState() => _OfficeParentPickerState();
}

class _OfficeParentPickerState extends State<_OfficeParentPicker> {
  String _search = '';

  List<OfficeAdminItem> get _filtered {
    if (_search.trim().isEmpty) return widget.items;
    final q = _search.toLowerCase();
    return widget.items
        .where((o) => o.name.toLowerCase().contains(q) || o.id.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    // Lift above the keyboard and size against the remaining visible area so
    // the sheet never gets pushed to the very top of the screen.
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
      height: (mq.size.height - mq.viewInsets.bottom) * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          _simpleSearchField('Cari kantor…', (v) => setState(() => _search = v)),
          Expanded(
            child: filtered.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 80),
                    EmptyStateView(
                      icon: Icons.search_off,
                      title: 'Tidak ditemukan',
                      subtitle: 'Coba kata kunci lain.',
                    ),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final o = filtered[i];
                      return ListTile(
                        dense: true,
                        title: Text(o.name, style: const TextStyle(fontSize: 14)),
                        subtitle: Text('${o.id} • ${_officeTypeLabel(o.type)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        onTap: () => Navigator.of(context).pop(o),
                      );
                    },
                  ),
          ),
        ],
      ),
      ),
    );
  }
}
