import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/responsive.dart';
import '../../src/app.dart';
import '../../src/network/api_client.dart';
import '../../src/dashboard/dashboard_periode.dart';
import '../../src/dashboard/dashboard_repository.dart';
import '../../src/announcement/announcement_repository.dart';
import '../../src/announcement/announcement_banner.dart';
import '../../core/providers/app_providers.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/state_views.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/dashboard/kinerja_card.dart';
import '../widgets/dashboard/section_title.dart';
import '../widgets/dashboard/office_row.dart';
import '../widgets/dashboard/jadwal_item_card.dart';
import '../widgets/dashboard/pencapaian_target_card.dart';
import 'pipeline_detail_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final Function(int)? onTabChange;

  /// Switches the host (MainScreen) to the RM tab and pre-applies a filter. Null
  /// when there's no RM tab (e.g. ADMIN) — the dashboard then pushes the RM page.
  final void Function({String? regionId, String? branchId, String? search})?
  onOpenRmTab;

  const DashboardScreen({super.key, this.onTabChange, this.onOpenRmTab});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

/// Full-bleed banner height. Konten dashboard TIDAK ditumpuk di atas banner:
/// elemen pertama di bawahnya adalah pemilih Periode (baris tanpa latar), jadi
/// tumpang-tindih membuatnya terbaca "nabrak" dan sentuhannya jatuh ke banner.
const double _bannerHeight = 138;

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with RouteAware {
  // State bisnis/async dikelola DashboardNotifier. Getter berikut memproksinya
  // agar seluruh kode build/widget di bawah tetap memakai nama lama tanpa diubah.
  DashboardState get _ds => ref.read(dashboardProvider);
  DashboardNotifier get _notifier => ref.read(dashboardProvider.notifier);

  bool get _loading => _ds.loading;
  String? get _error => _ds.error;
  DashboardSummary? get _summary => _ds.summary;
  List<DashboardSchedule> get _schedules => _ds.schedules;
  List<Announcement> get _announcements => _ds.announcements;
  DashboardDrilldown? get _drilldown => _ds.drilldown;
  DashboardCategories? get _categories => _ds.categories;
  DashboardPeriode get _periode => _ds.selectedPeriode;
  AngkaPeriode? get _angkaPeriode => _ds.angkaPeriode;
  String? get _selectedCategory => _ds.selectedCategory;
  int? get _selectedYear => _ds.selectedYear;
  DashboardCategoryStat? get _selectedCat => _ds.selectedCat;
  int get _activePipelines => _ds.activePipelines;
  int get _successRate => _ds.successRate;

  /// `ApiClient` aktif (dari [apiClientProvider]) untuk banner pengumuman. Tetap
  /// nullable agar kode build lama (`_apiClient != null` / `_apiClient!`) tak
  /// berubah; secara runtime provider selalu mengembalikan instance non-null.
  ApiClient? get _apiClient => ref.read(apiClientProvider);

  /// Only RM gets the schedule feature on home (Agen/TPM are on their own
  /// dashboard; BM/RO/KUP/ADMIN don't need it).
  bool get _isRm =>
      (MbisApp.of(context)?.session?.user.roles ?? const []).contains('RM');

  /// "Kinerja per Wilayah/Cabang/RM": collapsed to the first few rows by default,
  /// expandable to the full list inline. State UI murni — tetap di widget.
  bool _perOfficeExpanded = false;
  static const int _perOfficeCollapsedCount = 3;

  @override
  void initState() {
    super.initState();
    // Bootstrap notifier setelah frame pertama (samakan timing lama). Sesi &
    // repo dibaca notifier lewat provider — tak perlu context/konstruksi repo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) MbisApp.routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    MbisApp.routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Returned to the dashboard after a pushed screen (add pipeline, status
  /// change, etc.) — refresh silently so the cards update without a skeleton
  /// flash, and a transient refresh error doesn't wipe the visible data.
  @override
  void didPopNext() {
    _fetch(silent: true);
  }

  // Aksi data → delegasi ke DashboardNotifier (logika dipindah utuh).
  Future<void> _fetch({bool silent = false}) => _notifier.fetch(silent: silent);
  void _onCategoryChanged(String v) => _notifier.onCategoryChanged(v);
  void _onYearChanged(int? v) => _notifier.onYearChanged(v);
  void _onPeriodeChanged(DashboardPeriode v) => _notifier.onPeriodeChanged(v);

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(dashboardProvider);
    final session = MbisApp.of(context)?.session;
    final name = session?.user.name ?? 'Pengguna';
    // Subtitle = titel jabatan asli (users.jabatan, mis. "Business Head",
    // "Associate II RM") bila ada; fallback ke nama role (mis. admin yang
    // jabatan-nya kosong). Role tetap penentu akses, jabatan hanya tampilan.
    final jabatan = session?.user.jabatan?.trim() ?? '';
    final roles = jabatan.isNotEmpty
        ? jabatan
        : (session?.user.roles ?? const <String>[]).join(' • ');
    // The navy top bar now reaches up under the status bar, so use light icons.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bgScreen,
        body: Column(
          children: [
            HomeTopBar(
              name: name,
              initials: HomeTopBar.initialsOf(name),
              subtitle: roles,
              showConnectTag: session?.user.isConnect ?? false,
            ),
            Expanded(
              child: RefreshIndicator(onRefresh: _fetch, child: _buildBody()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const SkeletonList(itemCount: 6);
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          ErrorStateView(message: _error!, onRetry: _fetch),
        ],
      );
    }
    final hasBanner = _announcements.isNotEmpty && _apiClient != null;
    final isRm = _isRm;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      // On wide screens cap + centre the content so it reads as a desktop
      // dashboard instead of a single mobile column stretched edge-to-edge.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner pengumuman FULL-BLEED (latar edge-to-edge); teksnya di-cap di dalam
          // AnnouncementBanner agar sejajar konten — jadi satu pita dengan header navy,
          // tidak lagi terlihat "kepotong" pada layar lebar.
          if (hasBanner)
            AnnouncementBanner(
              apiClient: _apiClient!,
              announcements: _announcements,
              height: _bannerHeight,
            ),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.isWide(context)
                    ? Responsive.contentMaxWidthFor(context)
                    : double.infinity,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Satu tombol filter untuk tahun DAN potongan periode. Dulu dua
                    // kendali terpisah (dropdown tahun + deretan chip) yang memakan dua
                    // baris penuh di atas layar, padahal keduanya menjawab satu
                    // pertanyaan yang sama: "angka ini untuk kapan".
                    _buildFilterPeriode(),
                    const SizedBox(height: AppSpacing.md),
                    // Realisasi vs Target YTD is the headline metric, so it leads
                    // the dashboard (replacing the old Customer/Pipeline/Jadwal strip;
                    // those now live as cards in the grid below).
                    PencapaianTargetCard(
                      summary: _summary,
                      selectedCat: _selectedCat,
                      categories: _categories,
                      selectedCategory: _selectedCategory,
                      onCategoryChanged: _onCategoryChanged,
                      periode: _periode,
                      angka: _angkaPeriode,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildKinerjaGrid(),
                    // Sumber bisnis menyusul grid: menjawab "premi ini datang dari
                    // kanal mana", jadi tempatnya sesudah angka totalnya terlihat.
                    if (_ds.realisasiPerSumber.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _buildSumberBisnisSection(),
                    ],
                    // Anyone seeing more than their own data gets the oversight
                    // section: supervisors (KUP/BM/RO) by office subtree, and ADMIN
                    // nationwide. Gated on data scope (scopeLevel != OWNER) rather
                    // than role, so ADMIN's national oversight view shows here too.
                    if (_summary?.isSupervisor == true) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _buildSupervisorSection(),
                    ],
                    if (isRm) ...[
                      const SizedBox(height: AppSpacing.xl),
                      SectionTitle(
                        'Jadwal Kunjungan',
                        onActionTap: () => context.go('/dashboard/jadwal'),
                        actionLabel: 'Lihat semua',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildJadwalList(_schedules),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Warna kanal sumber bisnis — MELEKAT PADA KANAL, bukan pada peringkatnya.
  ///
  /// Empat warna, bukan lima: lima warna kategorikal tidak lolos pemeriksaan
  /// keterbedaan buta warna pada SEMUA pasangan, empat lolos. Kanal sisanya
  /// dilipat jadi "Lainnya" ketimbang mengarang warna kelima yang tak terbaca.
  ///
  /// Divalidasi (bukan dikira-kira) atas latar putih untuk pita lightness, ambang
  /// chroma, keterbedaan protan/deutan/tritan, dan keterbedaan mata normal —
  /// termasuk mode semua-pasangan, karena segmen bernilai nol menghilang sehingga
  /// dua kanal yang tadinya berjauhan bisa menjadi bersebelahan.
  ///
  /// Oranye di bawah 3:1 terhadap latar; itu ditebus legenda berlabel di bawah bar,
  /// jadi identitas tidak pernah bergantung pada warna saja.
  static const Map<String, Color> _warnaSumber = {
    'DIRECT': Color(0xFF2E6FBF),
    'AGENT': Color(0xFFF2843A),
    'BROKER': Color(0xFF8B5CF6),
    'LAINNYA': Color(0xFF0FA3B1),
  };

  /// Realisasi per sumber bisnis (CR-03): Direct / Agen / Broker / Lainnya.
  ///
  /// Dihitung dari pipeline WON, dan itu memang satu-satunya basis yang mungkin:
  /// rekap resmi pusat disimpan per (RM x tahun x bulan x kategori) tanpa dimensi
  /// sumber bisnis sama sekali. Basisnya ditulis di layar supaya angka di sini tidak
  /// dikira salah ketika berbeda dari kartu Realisasi di atas — yang memakai rekap
  /// resmi begitu pusat mengunggahnya.
  Widget _buildSumberBisnisSection() {
    final baris = _ds.realisasiPerSumber;
    if (baris.isEmpty) return const SizedBox.shrink();
    final total = _ds.totalRealisasiSumber;
    final cat = _selectedCat;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Realisasi per Sumber Bisnis'),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: AppRadius.radiusLg,
            border: Border.all(color: AppColors.border),
            boxShadow: const [AppShadows.level1],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${cat != null ? '${cat.label} · ' : ''}Periode ${_periode.label}'
                      ' · dari pipeline WON',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppFormat.currencyShort(total),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _barProporsi(baris, total),
              const SizedBox(height: 14),
              for (final b in baris) ...[
                _legendaSumber(b.kunci, b.label, b.realisasi, total),
                const SizedBox(height: 8),
              ],
              // Penjelasan hanya muncul saat memang bisa membingungkan: begitu ada
              // bulan yang memakai rekap resmi, angka di atas tidak akan cocok dengan
              // kartu Realisasi, dan pembaca berhak tahu sebabnya tanpa bertanya.
              if (cat?.pakaiResmi ?? false) ...[
                const SizedBox(height: 2),
                const Text(
                  'Rekap resmi pusat tidak memuat sumber bisnis, jadi bagian ini '
                  'dihitung dari pipeline WON — totalnya bisa berbeda dari kartu '
                  'Realisasi di atas.',
                  style: TextStyle(fontSize: 10, color: AppColors.grayStage),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Satu bar 100% berisi porsi tiap kanal.
  ///
  /// Segmen dirender dalam urutan tetap, dipisah celah 2px berwarna latar supaya dua
  /// warna tidak pernah bersentuhan langsung, dan ujung luarnya membulat 4px.
  Widget _barProporsi(
      List<({String kunci, String label, double realisasi})> baris, double total) {
    if (total <= 0) {
      return Container(
        height: 12,
        decoration: BoxDecoration(
          color: AppColors.grayBg,
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Belum ada realisasi pada periode ini',
          style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
        ),
      );
    }
    final terisi = baris.where((b) => b.realisasi > 0).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            for (int i = 0; i < terisi.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                // Pembagi dibulatkan ke seperseribu supaya kanal yang nilainya sangat
                // kecil tetap mendapat lebar yang terlihat, bukan hilang jadi nol.
                flex: (terisi[i].realisasi / total * 1000).round().clamp(1, 1000),
                child: Container(color: _warnaSumber[terisi[i].kunci]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Satu baris legenda: titik warna, nama kanal, nilai, dan porsinya.
  ///
  /// Nilai & persen ditulis dengan warna teks biasa, bukan warna kanalnya — warna
  /// hanya dipakai pada titik penanda, supaya angkanya tetap terbaca nyaman.
  Widget _legendaSumber(String kunci, String label, double nilai, double total) {
    final porsi = total > 0 ? nilai / total : 0.0;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: _warnaSumber[kunci],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          AppFormat.currencyShort(nilai),
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '${(porsi * 100).round()}%',
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  /// Ringkasan filter aktif + tombol pembukanya. Tahun dan potongan periode
  /// disatukan dalam satu kendali karena keduanya menjawab pertanyaan yang sama.
  Widget _buildFilterPeriode() {
    final tahun = _selectedYear ?? DateTime.now().year;
    return Row(
      children: [
        const Icon(Icons.calendar_month_outlined,
            size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        const Text('Periode',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const Spacer(),
        InkWell(
          borderRadius: AppRadius.radiusMd,
          onTap: _bukaSheetPeriode,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: AppRadius.radiusMd,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$tahun \u00b7 ${_periode.label}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryNavy),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.tune, size: 16, color: AppColors.primaryNavy),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Lembar pemilih: tahun di atas, potongan periode di bawah.
  ///
  /// Pilihan langsung diterapkan tanpa tombol "Terapkan", dan lembarnya sengaja
  /// TIDAK ditutup — mengganti tahun lalu triwulan adalah satu niat yang sama, dan
  /// menutup lembar di tengahnya memaksa pengguna membukanya lagi.
  void _bukaSheetPeriode() {
    final tahunIni = DateTime.now().year;
    final tahunList = <int>[for (int y = tahunIni; y >= tahunIni - 4; y--) y];
    final terpilih = _selectedYear ?? tahunIni;
    if (!tahunList.contains(terpilih)) tahunList.insert(0, terpilih);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            // Batas bulan dibaca ulang tiap rebuild: mengganti tahun mengubah
            // triwulan mana yang sudah tiba.
            final maxMonth = _categories?.currentMonth ?? DateTime.now().month;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Periode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Tahun',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final y in tahunList)
                        _pilihanFilter(
                          label: '$y',
                          terpilih: (_selectedYear ?? tahunIni) == y,
                          onTap: () {
                            _onYearChanged(y);
                            setSheetState(() {});
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text('Potongan',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final per in DashboardPeriode.values)
                        _pilihanFilter(
                          label: per.label,
                          terpilih: _periode == per,
                          // Periode yang belum tiba tetap bisa dipilih (targetnya
                          // berguna dilihat) tapi diredupkan supaya jelas belum berisi.
                          redup: per.months(maxMonth).isEmpty,
                          onTap: () {
                            _onPeriodeChanged(per);
                            setSheetState(() {});
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                      child: const Text('Selesai'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Satu pilihan dalam lembar filter — dipakai baris tahun maupun baris potongan,
  /// supaya keduanya tidak bisa lepas rupa.
  Widget _pilihanFilter({
    required String label,
    required bool terpilih,
    required VoidCallback onTap,
    bool redup = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: terpilih ? AppColors.primaryNavy : AppColors.navyBg,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: terpilih ? FontWeight.w700 : FontWeight.w500,
            color: terpilih
                ? Colors.white
                : (redup ? AppColors.grayStage : AppColors.primaryNavy),
          ),
        ),
      ),
    );
  }

  // 6 KINERJA DATA GRID (2x3). Item yang punya sumber backend memakai data asli;
  // sisanya (Target/Visit YTD) masih placeholder karena belum ada endpoint-nya.
  Widget _buildKinerjaGrid() {
    final s = _summary;
    final cat =
        _selectedCat; // Target/Realisasi ikut kategori filter bila tersedia
    // Angka periode terpilih (CR-02). null = data kategori belum termuat, di situ
    // kartu jatuh ke angka ringkasan seperti sebelumnya.
    final angka = _angkaPeriode;
    const monthsId = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    // Kunjungan ikut kategori terpilih (CR-09). Yang dipercaya adalah kategori
    // yang DIPANTULKAN server, bukan pilihan di layar: kategori yang tak dikenal
    // server diperlakukan sebagai "tanpa penyaringan", dan memakai pilihan layar
    // di situ akan memberi label kategori pada angka yang sebenarnya semua produk.
    final drilldownCategory = _drilldown?.category;
    final visitFiltered = drilldownCategory != null;
    // Akhiran label untuk kartu yang funnel/potensinya ikut kategori. Sumbernya
    // kategori yang DIPANTULKAN summary — dengan alasan yang sama seperti di atas:
    // kalau server mengabaikan kategorinya, kartunya tidak boleh mengaku tersaring.
    final summaryCategory = s?.category;
    final catSuffix =
        summaryCategory != null ? ' · ${cat?.label ?? summaryCategory}' : '';
    final visitMonthLabel = visitFiltered
        ? 'Visit ${monthsId[DateTime.now().month - 1]} · ${cat?.label ?? drilldownCategory}'
        : 'Visit ${monthsId[DateTime.now().month - 1]}';
    final visitMonthValue = _drilldown != null && _drilldown!.monthly.isNotEmpty
        ? (visitFiltered
            ? '${_drilldown!.monthly.last.visitsCategory}'
            : '${_drilldown!.monthly.last.visits}')
        : (s != null ? '${s.visitCountYtd}' : '–');
    final List<Map<String, dynamic>> gridItems = [
      // SATU kartu target, bukan dua. Sempat ada "Target Setahun" terpisah, tapi itu
      // membuat grid jadi sembilan kartu dan memaksa pembaca memilih sendiri mana yang
      // relevan. Yang dipakai sehari-hari adalah target periode berjalan; angka setahun
      // tetap tersedia — muncul di rincian saat kartunya ditekan.
      {
        'key': 'target',
        'label': angka != null ? 'Target ${_periode.label}' : 'Target Setahun',
        'value': angka != null
            ? (angka.belumTiba ? '–' : AppFormat.currencyShort(angka.target))
            : (cat != null
                ? AppFormat.currencyShort(cat.targetFullYear)
                : (s != null ? AppFormat.currencyShort(s.premiTarget) : '–')),
        'icon': Icons.track_changes_outlined,
        'color': AppColors.primaryNavy,
      },
      {
        'key': 'realisasi',
        // Label ikut periode terpilih: menyebut "YTD" sementara chip menunjuk
        // Triwulan II akan membuat angka yang benar terbaca sebagai angka yang salah.
        'label': angka != null ? 'Realisasi ${_periode.label}' : 'Realisasi YTD',
        'value': angka != null
            ? (angka.belumTiba ? '–' : AppFormat.currencyShort(angka.realisasi))
            : (s != null ? AppFormat.currencyShort(s.totalRealization) : '–'),
        'icon': Icons.trending_up,
        'color': AppColors.successGreen,
        'mtd': true,
      },
      {
        'key': 'visit',
        'label': visitMonthLabel,
        'value': visitMonthValue,
        'suffix': ' kunjungan',
        'icon': Icons.place_outlined,
        'color': AppColors.secondaryOrange,
        'mtd': true,
      },
      {
        'key': 'pipelineAktif',
        'label': 'Pipeline Aktif$catSuffix',
        'value': '$_activePipelines',
        'suffix': ' pipeline',
        'icon': Icons.account_tree_outlined,
        'color': AppColors.primaryNavyLight,
        'mtd': true,
      },
      {
        'key': 'nilaiPipeline',
        'label': 'Nilai Pipeline$catSuffix',
        'value': s != null ? AppFormat.currencyShort(s.totalPotential) : '–',
        'icon': Icons.show_chart,
        'color': AppColors.purpleAccent,
      },
      {
        'key': 'successRate',
        'label': 'Success Rate$catSuffix',
        'value': '$_successRate',
        'suffix': '%',
        'icon': Icons.percent,
        'color': AppColors.successGreen,
      },
      // Summary counts moved to the end (from the old top strip). Non-drill-downs,
      // so they're non-tappable ('tappable': false → no unfold affordance).
      {
        'key': 'customer',
        'label': 'Customer',
        'value': s != null ? '${s.totalCustomers}' : '–',
        'icon': Icons.people_alt_outlined,
        'color': AppColors.primaryNavy,
        'tappable': false,
      },
      // RM sees their upcoming visit schedule count; everyone else sees Visit YTD
      // (same role split the old strip used for its third cell).
      if (_isRm)
        {
          'key': 'jadwal',
          'label': 'Jadwal',
          'value': '${_schedules.length}',
          'icon': Icons.calendar_month_outlined,
          'color': AppColors.secondaryOrange,
          'tappable': false,
        }
      else
        {
          'key': 'visitYtd',
          'label': 'Visit YTD',
          'value': s != null ? '${s.visitCountYtd}' : '–',
          'icon': Icons.place_outlined,
          'color': AppColors.secondaryOrange,
          'tappable': false,
        },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: gridItems.length,
      // Fixed compact height at every breakpoint (columns grow, cards don't).
      // Using childAspectRatio tied height to cell width, so on wide phones/desktop
      // the cards grew tall with a big empty gap under the label — mainAxisExtent
      // keeps them snug regardless of column width.
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.value(
          context,
          mobile: 2,
          tablet: 3,
          desktop: 4,
        ),
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        mainAxisExtent: 118,
      ),
      itemBuilder: (context, index) {
        final item = gridItems[index];
        final tappable = item['tappable'] != false;
        final key = item['key'] as String;
        // Target/Realisasi YTD: kalau filter kategori aktif, buka rincian per bulan
        // untuk kategori terpilih; selain itu drill-down lama.
        final bool categoryCard =
            (key == 'target' || key == 'realisasi') && cat != null;
        return KinerjaCard(
          label: item['label'] as String,
          value: item['value'] as String,
          suffix: item['suffix'] as String?,
          icon: item['icon'] as IconData,
          color: item['color'] as Color,
          onTap: !tappable
              ? null
              : (categoryCard
                    ? _openCategoryMonthly
                    : () => _openDrilldown(key, item['label'] as String)),
        );
      },
    );
  }

  /// Opens a bottom sheet drill-down for a tapped stat card.
  /// Tutup lembar drill-down lalu buka detail pipeline. Dipakai daftar Pipeline
  /// Aktif maupun Success Rate — keduanya berakhir di layar yang sama.
  void _bukaPipeline(BuildContext sheetCtx, String pipelineId) {
    Navigator.of(sheetCtx).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PipelineDetailScreen(pipelineId: pipelineId),
      ),
    );
  }

  void _openDrilldown(String key, String title) {
    final d = _drilldown;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        Widget body;
        if (d == null) {
          body = const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Data belum tersedia',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        } else {
          switch (key) {
            case 'target':
            case 'realisasi':
              // Cadangan saja: kartu target/realisasi sebenarnya memakai
              // _openCategoryMonthly (12 bulan + total setahun). Cabang ini hanya
              // terpakai bila data kategori gagal dimuat.
              body = _monthTable(
                d,
                const ['Bulan', 'Target', 'Realisasi'],
                (m) => [
                  m.label,
                  AppFormat.currencyShort(m.target),
                  AppFormat.currencyShort(m.realisasi),
                ],
              );
              break;
            case 'visit':
              // Dengan kategori terpilih (CR-09), kolom rinciannya jadi kategori
              // ITU — bukan KUR yang dulu dipatok mati. Tanpa kategori, tabelnya
              // tetap Bulan | KUR | All persis seperti sebelumnya.
              final visitCat = d.category;
              body = visitCat == null
                  ? _monthTable(d, const [
                      'Bulan',
                      'KUR',
                      'All',
                    ], (m) => [m.label, '${m.visitsKur}', '${m.visits}'])
                  : _monthTable(d, [
                      'Bulan',
                      _selectedCat?.label ?? visitCat,
                      'All',
                    ], (m) => [m.label, '${m.visitsCategory}', '${m.visits}']);
              break;
            case 'nilaiPipeline':
              body = _monthTable(d, const [
                'Bulan',
                'Nilai Pipeline',
              ], (m) => [m.label, AppFormat.currencyShort(m.pipelineValue)]);
              break;
            case 'pipelineAktif':
              // CR-07: angka pipeline harus bisa ditekan sampai ke daftar rinciannya,
              // lalu dibuka satu per satu. Tabel COB dipertahankan sebagai ringkasan
              // di atas daftarnya — dua pertanyaan berbeda ("sebarannya bagaimana"
              // dan "pipeline mana saja"), dan yang lama sudah dipakai orang.
              body = d.activeItems.isEmpty
                  ? _cobTable(d)
                  : _PipelineListView(
                      items: d.activeItems,
                      headerText:
                          '${d.activeItems.length} pipeline aktif (P3/P2/P1)',
                      filters: const [
                        (label: 'Semua', value: 'ALL'),
                        (label: 'P3', value: 'P3'),
                        (label: 'P2', value: 'P2'),
                        (label: 'P1', value: 'P1'),
                      ],
                      onOpenPipeline: (id) => _bukaPipeline(sheetCtx, id),
                    );
              break;
            case 'successRate':
              body = _PipelineListView(
                items: d.successItems,
                headerText:
                    'WON ${d.won}, Decline ${d.decline} dari total ${d.total} pipeline',
                filters: const [
                  (label: 'Semua', value: 'ALL'),
                  (label: 'Won', value: 'WON'),
                  (label: 'Decline', value: 'DECLINE'),
                ],
                onOpenPipeline: (id) => _bukaPipeline(sheetCtx, id),
              );
              break;
            default:
              body = const SizedBox.shrink();
          }
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                // The success-rate view manages its own scrolling (search + list);
                // the other drill-downs are short tables, so wrap them in a scroller.
                child: (key == 'successRate' && d != null)
                    ? body
                    : SingleChildScrollView(child: body),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tableHeader(List<String> cols) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        for (int i = 0; i < cols.length; i++)
          Expanded(
            flex: i == 0 ? 2 : 2,
            child: Text(
              cols[i],
              textAlign: i == 0 ? TextAlign.start : TextAlign.end,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _tableRow(List<String> cells) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        for (int i = 0; i < cells.length; i++)
          Expanded(
            flex: 2,
            child: Text(
              cells[i],
              textAlign: i == 0 ? TextAlign.start : TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: i == 0 ? FontWeight.w500 : FontWeight.w600,
                color: i == 0 ? AppColors.textSecondary : AppColors.textPrimary,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _monthTable(
    DashboardDrilldown d,
    List<String> cols,
    List<String> Function(DashboardMonthRow) row,
  ) {
    return Column(
      children: [
        _tableHeader(cols),
        const Divider(height: 1, color: AppColors.border),
        for (final m in d.monthly) ...[
          _tableRow(row(m)),
          const Divider(height: 1, color: AppColors.border),
        ],
      ],
    );
  }

  Widget _cobTable(DashboardDrilldown d) {
    if (d.byCob.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Belum ada pipeline aktif',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return Column(
      children: [
        _tableHeader(const ['COB', 'Jumlah']),
        const Divider(height: 1, color: AppColors.border),
        for (final c in d.byCob) ...[
          _tableRow([c.cob, '${c.count}']),
          const Divider(height: 1, color: AppColors.border),
        ],
      ],
    );
  }

  /// Supervisory block (KUP/BM/RO/DPJ): scope chip, visit-map shortcut, and the
  /// per-RM breakdown table. Hidden for an RM's own (OWNER) dashboard.
  Widget _buildSupervisorSection() {
    final s = _summary;
    if (s == null || !s.isSupervisor) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.navyBg,
            borderRadius: AppRadius.radiusLg,
            border: Border.all(
              color: AppColors.primaryNavy.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.groups_outlined,
                color: AppColors.primaryNavy,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cakupan ${_scopeLabel(s.scopeLevel)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    Text(
                      '${s.rmCount} RM dalam cakupan Anda',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/dashboard/visit-map'),
                icon: const Icon(
                  Icons.map_outlined,
                  size: 16,
                  color: Colors.white,
                ),
                label: const Text(
                  'Peta Visit',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusMd,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionTitle(_perOfficeTitle(s.perOfficeLevel)),
        const SizedBox(height: AppSpacing.sm),
        if (s.perOffice.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: AppRadius.radiusLg,
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'Belum ada aktivitas pada cakupan ini.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          )
        else ...[
          ...(_perOfficeExpanded
                  ? s.perOffice
                  : s.perOffice.take(_perOfficeCollapsedCount))
              .map(
                (o) => OfficeRow(
                  office: o,
                  onTap: () {
                    switch (o.type) {
                      case 'REGIONAL':
                        _openRm(regionId: o.id);
                        break;
                      case 'BRANCH':
                        _openRm(branchId: o.id);
                        break;
                      default: // RM
                        _openRm(search: o.name);
                    }
                  },
                ),
              ),
          if (s.perOffice.length > _perOfficeCollapsedCount)
            _buildPerOfficeToggle(s.perOffice.length),
        ],
      ],
    );
  }

  /// Inline expand/collapse for the per-office list — shows the first few cards,
  /// then reveals the rest in place (no separate page).
  Widget _buildPerOfficeToggle(int total) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: () =>
              setState(() => _perOfficeExpanded = !_perOfficeExpanded),
          icon: Icon(
            _perOfficeExpanded ? Icons.expand_less : Icons.expand_more,
            size: 18,
            color: AppColors.primaryNavy,
          ),
          label: Text(
            _perOfficeExpanded
                ? 'Tampilkan lebih sedikit'
                : 'Tampilkan semua ($total)',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryNavy,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
          ),
        ),
      ),
    );
  }

  String _perOfficeTitle(String level) {
    switch (level) {
      case 'REGION':
        return 'Kinerja per Wilayah';
      case 'BRANCH':
        return 'Kinerja per Cabang';
      default:
        return 'Kinerja per RM';
    }
  }

  /// Opens the RM list filtered to the tapped office/RM. Switches to the RM tab
  /// when available (supervisors), otherwise navigates to the RM-performance
  /// route (e.g. ADMIN), passing the filter as query params so it survives a
  /// refresh.
  void _openRm({String? regionId, String? branchId, String? search}) {
    final cb = widget.onOpenRmTab;
    if (cb != null) {
      cb(regionId: regionId, branchId: branchId, search: search);
    } else {
      final qp = <String, String>{};
      if (regionId != null) qp['regionId'] = regionId;
      if (branchId != null) qp['branchId'] = branchId;
      if (search != null) qp['search'] = search;
      context.go(
        Uri(
          path: '/dashboard/rm-performance',
          queryParameters: qp.isEmpty ? null : qp,
        ).toString(),
      );
    }
  }

  String _scopeLabel(String scopeLevel) {
    switch (scopeLevel) {
      case 'KUP':
        return 'KUP';
      case 'BRANCH':
        return 'Cabang';
      case 'REGIONAL':
        return 'Wilayah';
      case 'NATIONAL':
        return 'Nasional';
      default:
        return scopeLevel;
    }
  }

  /// Rincian target vs realisasi per bulan untuk kategori terpilih (kartu Target/
  /// Realisasi YTD ditekan) — "seperti awal" tapi sesuai filter.
  void _openCategoryMonthly() {
    final cat = _selectedCat;
    if (cat == null) return;
    // DUA BELAS bulan penuh, Januari s/d Desember — bukan sampai bulan berjalan.
    // Kartunya sudah menjawab "sudah sampai mana"; yang dicari orang saat menekannya
    // justru gambaran setahun, termasuk target bulan yang belum dijalani. Bulan
    // mendatang diredupkan supaya tetap terbaca sebagai "belum", bukan "gagal".
    final maxMonth = _categories?.currentMonth ?? 12;
    final months = cat.months;
    // Pembedahan sumber angka (rekap resmi vs pipeline WON) hanya untuk RM —
    // dialah pemilik angkanya dan satu-satunya yang bisa menindaklanjuti kalau
    // rekap pusat tak cocok dengan pipeline-nya. Bagi atasan & admin angkanya
    // sudah teragregasi lintas RM, jadi rinciannya tidak bisa ditindaklanjuti
    // dan hanya menambah keramaian. Dibaca sekali di sini, bukan di dalam
    // builder, supaya tiap baris bulan tidak menelusuri context berulang kali.
    final tampilkanSumber = _isRm;
    // Total setahun dihitung dari 12 bulan yang sama dengan yang ditampilkan,
    // bukan dari targetYtd — supaya angka penutup tidak pernah bisa berbeda dari
    // penjumlahan baris di atasnya.
    final totalRealisasi = months.fold<double>(0, (a, m) => a + m.realisasi);
    final pctSetahun = cat.targetFullYear > 0
        ? (totalRealisasi / cat.targetFullYear * 100).round()
        : (totalRealisasi > 0 ? 100 : 0);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rincian per Bulan — ${cat.label}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Target vs realisasi ${_categories?.year ?? ''}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              if (tampilkanSumber) ...[
                _perbandinganSumber(cat),
                const SizedBox(height: 12),
              ],
              Flexible(
                child: months.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Belum ada data bulan ini.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: months.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (c, i) {
                          final m = months[i];
                          final pct = m.target > 0
                              ? (m.realisasi / m.target * 100).round()
                              : (m.realisasi > 0 ? 100 : 0);
                          // Bulan yang belum dijalani: angkanya sah (targetnya sudah
                          // ditetapkan) tapi realisasinya nol karena memang belum
                          // waktunya — diredupkan agar tidak terbaca sebagai capaian buruk.
                          final belumJalan = m.month > maxMonth;
                          final warnaUtama = belumJalan
                              ? AppColors.grayStage
                              : AppColors.textPrimary;
                          final warnaKedua = belumJalan
                              ? AppColors.grayStage
                              : AppColors.textSecondary;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    m.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: warnaUtama,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              'Realisasi ${AppFormat.currencyShort(m.realisasi)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: warnaUtama,
                                              ),
                                            ),
                                          ),
                                          if (tampilkanSumber &&
                                              m.pakaiResmi) ...[
                                            const SizedBox(width: 6),
                                            const _SumberChip(),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        'Target ${AppFormat.currencyShort(m.target)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: warnaKedua,
                                        ),
                                      ),
                                      // Angka WON hanya disebut saat berbeda:
                                      // menuliskannya di tiap baris membuat yang
                                      // penting (selisihnya) tenggelam.
                                      if (tampilkanSumber &&
                                          m.pakaiResmi &&
                                          m.realisasiWon != m.realisasi)
                                        Text(
                                          'Pipeline WON ${AppFormat.currencyShort(m.realisasiWon)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.grayStage,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '$pct%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: belumJalan
                                        ? AppColors.grayStage
                                        : AppColors.primaryNavy,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              // Total setahun: angka inilah yang dulu tampil sebagai kartu
              // "Target Setahun" tersendiri. Tempatnya di sini, sebagai penutup
              // rincian, bukan sebagai kartu kesembilan di grid.
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 48,
                      child: Text(
                        'Setahun',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Realisasi ${AppFormat.currencyShort(totalRealisasi)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Target ${AppFormat.currencyShort(cat.targetFullYear)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$pctSetahun%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Perbandingan sumber angka — hanya untuk RM (lihat `tampilkanSumber` di
  /// [_openCategoryMonthly]), tapi bagi RM ditampilkan untuk SETIAP kategori,
  /// termasuk yang tidak punya rekap resmi sama sekali (Total, KUR).
  ///
  /// Justru kategori tanpa rekap resmi yang paling perlu menyebutkan sumbernya.
  /// Berkas pusat tidak memuat kolom Total maupun KUR, jadi keduanya selamanya
  /// memakai angka pipeline WON — sementara kategori tetangganya sudah memakai
  /// angka resmi. Tanpa keterangan ini, orang yang berpindah filter akan melihat
  /// Total lebih kecil daripada salah satu bagiannya dan menyimpulkan aplikasinya
  /// rusak, padahal yang berbeda adalah sumber datanya.
  Widget _perbandinganSumber(DashboardCategoryStat cat) {
    final selisih = cat.selisihTerhadapWon;
    final naik = selisih >= 0;
    final adaResmi = cat.pakaiResmi;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.navyBg,
        borderRadius: AppRadius.radiusLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (adaResmi) ...[
                const _SumberChip(),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  adaResmi
                      ? '${cat.bulanResmi} bulan memakai rekap resmi pusat'
                      : 'Belum ada rekap resmi untuk kategori ini — '
                          'angkanya murni dari pipeline WON',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _barisSumber('Angka yang tampil', cat.realisasiYtd, tebal: true),
          _barisSumber('Dari rekap resmi', cat.realisasiResmiYtd),
          _barisSumber('Dari pipeline WON', cat.realisasiWonYtd),
          const Divider(height: 14, color: AppColors.border),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Selisih terhadap WON',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ),
              Text(
                adaResmi
                    ? '${naik ? '+' : '−'}${AppFormat.currencyShort(selisih.abs())}'
                    : 'tidak ada',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: !adaResmi
                      ? AppColors.grayStage
                      : (naik ? AppColors.successGreen : AppColors.errorRed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            adaResmi
                ? 'Ekspor data tetap memakai angka dari pipeline WON.'
                : 'Kategori ini tidak ada di berkas rekap pusat, jadi angkanya '
                    'tidak bisa dibandingkan dengan kategori yang sudah memakai '
                    'rekap resmi.',
            style: const TextStyle(fontSize: 11, color: AppColors.grayStage),
          ),
        ],
      ),
    );
  }

  Widget _barisSumber(String label, double value, {bool tebal = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: tebal
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: tebal ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Text(
              AppFormat.currencyShort(value),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: tebal ? FontWeight.bold : FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );

  Widget _buildJadwalList(List<DashboardSchedule> schedules) {
    if (schedules.isEmpty) {
      return const EmptyStateView(
        inCard: true,
        icon: Icons.calendar_today_outlined,
        title: 'Belum ada jadwal kunjungan',
      );
    }

    const maxPreview = 4;
    final preview = schedules.take(maxPreview).toList();
    return Column(
      children: [
        for (final item in preview)
          JadwalItemCard(
            item: item,
            onTap: item.pipelineId == null
                ? null
                : () => context.go('/dashboard/pipeline/${item.pipelineId!}'),
          ),
        if (schedules.length > maxPreview)
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '+${schedules.length - maxPreview} jadwal lainnya',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Success-rate drill-down: WON/Decline summary + a searchable, filterable list of
/// ALL closed deals (national admins can have hundreds — search beats scrolling).
/// Daftar pipeline yang bisa dicari, disaring per stage, dan dibuka satu per satu.
///
/// Dipakai DUA drill-down: Success Rate (WON/Decline) dan Pipeline Aktif (P3/P2/P1,
/// CR-07). Digeneralisasi dari versi khusus Success Rate — menyalinnya untuk daftar
/// kedua berarti dua tempat yang harus diingat setiap kali perilaku daftar berubah.
///
/// Isinya sudah dibatasi cakupan oleh server; di sini hanya pencarian & penyaringan
/// tampilan, bukan penyaringan hak akses.
class _PipelineListView extends StatefulWidget {
  final List<DashboardSuccessItem> items;

  /// Ringkasan di kepala daftar (mis. "WON 4, Decline 1 dari total 9 pipeline").
  final String headerText;

  /// Pilihan penyaring stage. Nilai 'ALL' berarti tanpa saringan.
  final List<({String label, String value})> filters;
  final void Function(String pipelineId) onOpenPipeline;

  const _PipelineListView({
    required this.items,
    required this.headerText,
    required this.filters,
    required this.onOpenPipeline,
  });

  @override
  State<_PipelineListView> createState() => _PipelineListViewState();
}

class _PipelineListViewState extends State<_PipelineListView> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _stage = 'ALL';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Warna & teks lencana per stage. WON/Decline memakai hijau/merah seperti
  /// sebelumnya; stage aktif (P3/P2/P1) memakai navy karena hasilnya belum ada —
  /// mewarnainya hijau/merah menyiratkan menang/kalah yang belum terjadi.
  ({String label, Color fg, Color bg}) _badge(String stage) {
    switch (stage) {
      case 'WON':
        return (label: 'Won', fg: AppColors.successGreen, bg: AppColors.greenLight);
      case 'DECLINE':
        return (label: 'Decline', fg: AppColors.errorRed, bg: AppColors.redLight);
      default:
        return (label: stage, fg: AppColors.primaryNavy, bg: AppColors.navyBg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final items = widget.items.where((it) {
      if (_stage != 'ALL' && it.stage != _stage) return false;
      if (q.isNotEmpty && !it.customerName.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.55,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.navyBg,
              borderRadius: AppRadius.radiusMd,
            ),
            child: Text(
              widget.headerText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryNavy,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            style: AppInput.fieldText,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Cari nama customer...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final f in widget.filters) ...[
                _chip(f.label, f.value),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              Text(
                '${items.length}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada hasil',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (_, i) {
                      final it = items[i];
                      final b = _badge(it.stage);
                      return InkWell(
                        onTap: () => widget.onOpenPipeline(it.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: b.bg,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  b.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: b.fg,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  it.customerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: AppColors.grayStage,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final selected = _stage == value;
    return GestureDetector(
      onTap: () => setState(() => _stage = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryNavy : AppColors.navyBg,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.primaryNavy,
          ),
        ),
      ),
    );
  }
}

/// Penanda kecil "Resmi" — dipasang HANYA pada angka yang benar-benar berasal
/// dari rekap pusat. Bulan yang belum diunggah tetap memakai angka pipeline WON
/// dan sengaja tidak diberi penanda ini, supaya tidak ada klaim sumber yang
/// tidak benar.
class _SumberChip extends StatelessWidget {
  const _SumberChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.successGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'Resmi',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: AppColors.successGreen,
        ),
      ),
    );
  }
}
