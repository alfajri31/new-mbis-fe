import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../providers/pipeline_detail_provider.dart';
import '../../src/common/file_opener.dart';
import '../../src/common/mobile_browser_detector.dart';
import '../../theme/app_theme.dart';
import '../../src/nav.dart';
import '../../src/pipeline/pipeline_repository.dart';
import '../../src/pipeline/pipeline_timeline.dart';
import '../../src/visit/visit_repository.dart';
import '../../src/app.dart';
import '../../src/auth/roles.dart';
import '../../src/network/api_client.dart';
import '../../src/pipeline/pipeline_stage.dart';
import '../../utils/format.dart';
import '../../utils/input_formatters.dart';
import '../../utils/responsive.dart';
import '../widgets/timeline_entry_card.dart';
import '../widgets/pipeline_detail/pipeline_header_stepper.dart';
import '../widgets/pipeline_detail/pipeline_info_card.dart';
import '../widgets/pipeline_detail/pipeline_pengelola_card.dart';
import '../widgets/pipeline_detail/pipeline_referral_banner.dart';
import '../widgets/pipeline_detail/pipeline_documents_card.dart';
import '../widgets/pipeline_detail/pipeline_parties_card.dart';
import '../widgets/pipeline_detail/pipeline_won_shares_card.dart';
import '../widgets/pipeline_detail/pipeline_tender_processes_card.dart';
import '../widgets/pipeline_detail/pipeline_schedule_card.dart';
import '../widgets/pipeline_detail/pipeline_visit_web_notice.dart';
// Deferred: the visit-detail sheet renders a mini-map (flutter_map), so it's
// loaded on demand to keep the map library out of the initial bundle.
import '../widgets/visit_detail_sheet.dart' deferred as vds;
import 'add_activity_screen.dart';
import 'add_pipeline_screen.dart';
import 'tender_status_screen.dart';
import '../widgets/dispose_callback.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../features/quotation_slip/qs_form_screen.dart';
import '../../features/quotation_slip/qs_form_state.dart' show QsProduct;

class PipelineDetailScreen extends ConsumerStatefulWidget {
  final String pipelineId;

  const PipelineDetailScreen({super.key, required this.pipelineId});

  @override
  ConsumerState<PipelineDetailScreen> createState() =>
      _PipelineDetailScreenState();
}

class _PipelineDetailScreenState extends ConsumerState<PipelineDetailScreen>
    with RouteAware {
  final List<String> _stages = const ['P3', 'P2', 'P1', 'WON'];
  // UI/sesi-ephemeral (tetap di widget): id user aktif dipakai untuk cek peran.
  String? _currentUserId;

  // State ketersediaan Quotation Slip (QS) via API /api/pipeline/{id}/isQas
  IsQasModelResponse? _qasStatus;
  bool _isQasLoading = true;
  String? _qasError;

  // State DATA/LOADING dikelola PipelineDetailNotifier. Getter berikut memproksinya
  // agar seluruh kode build/widget di bawah tetap memakai nama lama tanpa diubah.
  PipelineDetailState get _ds => ref.read(pipelineDetailProvider);
  PipelineDetailNotifier get _pdNotifier =>
      ref.read(pipelineDetailProvider.notifier);

  bool get _isLoading => _ds.isLoading;
  String? get _error => _ds.error;
  PipelineDetailModel? get _pipeline => _ds.pipeline;
  List<VisitModel> get _visits => _ds.visits;
  List<PipelineHistoryModel> get _history =>
      _ds.history; // Log Activity timeline
  List<PipelineDocumentModel> get _docs => _ds.docs; // SPAU / Underlying
  // Broker, cascade produk, dan opsi kerja sama tidak lagi dibaca di sini:
  // formulir edit kini AddPipelineScreen, yang memuat referensinya sendiri.

  // Repo/ApiClient untuk aksi-tulis & preview yang tetap di widget (upload/delete
  // dokumen, edit/ubah status, jadwal, buka visit). Dari shared provider — bukan
  // konstruksi ApiClient sendiri.
  ApiClient get _apiClient => ref.read(apiClientProvider);
  PipelineRepository get _pipelineRepo => ref.read(pipelineRepoProvider);

  /// Dummy pipelineId untuk keperluan testing
  static const String _dummyPipelineId = "ce116c9b-3a0b-4109-84ae-56175ffb27f2";
  String get _activePipelineId => _dummyPipelineId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = MbisApp.of(context)?.session;
      _currentUserId = session?.user.id;
      // Bootstrap notifier (fetch detail + broker/referensi edit-sheet). Repo kini
      // dibaca notifier dari shared provider — tak perlu susun ApiClient di sini.
      _pdNotifier.start(_activePipelineId);
      _fetchQasStatus();
      // Label langkah tender ikut master data (editable admin).
      loadTenderLabels(_apiClient).then((_) {
        if (mounted) setState(() {});
      });
    });
  }

  /// Memuat status ketersediaan Quotation Slip dari server (/api/pipeline/{id}/isQas).
  Future<void> _fetchQasStatus() async {
    if (!mounted) return;
    setState(() {
      _isQasLoading = true;
      _qasError = null;
    });
    try {
      final res = await _pipelineRepo.getPipelineQas(_activePipelineId);
      if (mounted) {
        setState(() {
          _qasStatus = res;
          _isQasLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _qasError = e.toString().replaceFirst('Exception: ', '');
          _isQasLoading = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) MbisApp.routeObserver.subscribe(this, route);
  }

  /// Returned from the activity list (which can add/edit visits) — refresh.
  @override
  void didPopNext() => _fetchData(silent: true);

  @override
  void dispose() {
    MbisApp.routeObserver.unsubscribe(this);
    super.dispose();
  }

  // Fetch data → delegasi ke PipelineDetailNotifier (logika dipindah utuh).
  // Aksi-tulis di layar memanggil ini untuk reload setelah mutasi.
  Future<void> _fetchData({bool silent = false}) {
    _fetchQasStatus();
    return _pdNotifier.fetchData(silent: silent);
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(pipelineDetailProvider);
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Pipeline')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _pipeline == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Pipeline')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? 'Pipeline tidak ditemukan'),
              ElevatedButton(onPressed: _fetchData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final pipeline = _pipeline!;
    final currentStageIdx = _stages.indexOf(pipeline.stage.toUpperCase());
    // Agents view pipelines read-only; activity/visit logging is RM-only.
    final isAgent =
        MbisApp.of(context)?.session?.user.roles.contains('AGENT') ?? false;
    final isWon = pipeline.stage.toUpperCase() == 'WON';
    // Declined/canceled pipelines are read-only too (P6).
    final isDeclined = pipeline.stage.toUpperCase() == 'DECLINE';
    // After a referral is approved & handed over, the ORIGINAL RM sees it read-only
    // (only the destination RM can act); they may still add documents.
    final isHandedOver = pipeline.isReferral &&
        pipeline.referralStatus == 'APPROVED' &&
        _currentUserId != null &&
        _currentUserId == pipeline.referralFromRmId;
    // Pipeline terkunci karena SIKLUS HIDUPNYA, terlepas dari siapa yang membuka.
    final lifecycleLocked = isWon || isDeclined || isHandedOver;

    // Dua gerbang peran, karena server memang membedakannya:
    //   • data pipeline (produk/TSI/rate) → hasAnyRole('RM','BM','RO','KUP')
    //   • pekerjaan lapangan (stage, jadwal, kunjungan, dokumen) → hasRole('RM'),
    //     yang lewat RoleHierarchy hanya menaikkan ADMIN & KUP — bukan BM/RO.
    // Sebelumnya keduanya disamakan, sehingga BM/RO disodori tombol ubah status,
    // jadwal, dan unggah dokumen yang seluruhnya berujung 403. Peran divisi kantor
    // pusat gagal di kedua gerbang: cakupan bacanya nasional, hak tulisnya tidak ada.
    final roles = MbisApp.of(context)?.session?.user.roles;
    final canEditPipeline = Roles.hasAny(roles, Roles.pipelineWriters);
    final canFieldWork = Roles.hasAny(roles, Roles.pipelineFieldWorkers);
    // Gerbang KETIGA, dan ini soal OBJEK bukan peran: server menjawab apakah
    // pipeline INI boleh diubah pemanggil (`canEdit`). Perlu terpisah karena cakupan
    // BACA bisa lebih luas daripada cakupan TULIS — RM yang berkantor di Kanwil
    // melihat pipeline seluruh cabang tetapi hanya boleh mengubah miliknya sendiri
    // (CR-18). Tanpa ini ia disodori tombol "Tambah Aktivitas/Visit", mengisi seluruh
    // formulir kunjungan lengkap dengan foto dan GPS, lalu baru ditolak 403 di ujung.
    final isReadOnly = lifecycleLocked || !canFieldWork || !pipeline.canEdit;

    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: AppBar(
        backgroundColor: AppColors.primaryNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => safePop(context),
        ),
        title: const Text(
          'Detail Pipeline',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Sengaja memakai lifecycleLocked + canEditPipeline, bukan isReadOnly:
          // BM/RO boleh mengoreksi data pipeline di kantornya walau tak boleh
          // mengerjakan pekerjaan lapangannya.
          if (!isAgent && !lifecycleLocked && canEditPipeline && pipeline.canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              tooltip: 'Edit Pipeline',
              onPressed: () => _openEditPipeline(pipeline),
            ),
          // Hapus permanen: ADMIN saja, sejalan dengan gerbang server. RM pemilik
          // pun tidak diberi tombol ini — pipeline ikut membentuk angka capaian,
          // jadi koreksinya lewat ubah stage/isi, bukan menghapus jejaknya.
          if (roles != null && roles.contains('ADMIN'))
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Hapus Pipeline',
              onPressed: () => _confirmDeletePipeline(pipeline),
            ),
        ],
      ),
      body: Column(
        children: [
          // Navy Header & Stage Stepper Box
          PipelineHeaderStepper(
            pipeline: pipeline,
            stages: _stages,
            currentStageIdx: currentStageIdx,
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.isWide(context)
                        ? Responsive.contentMaxWidthFor(context)
                        : double.infinity,
                  ),
                  // Desktop/tablet: two columns (primary info | actions & timeline).
                  // Mobile: the same sections, stacked in one column (identical order).
                  child: Responsive.isWide(context)
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _primarySections(pipeline, isAgent: isAgent, canWrite: canFieldWork && pipeline.canEdit),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: _sidebarSections(
                                  pipeline,
                                  isAgent: isAgent,
                                  isReadOnly: isReadOnly,
                                  canFieldWork: canFieldWork,
                                  isWon: isWon,
                                  isDeclined: isDeclined,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ..._primarySections(pipeline, isAgent: isAgent, canWrite: canFieldWork && pipeline.canEdit),
                            const SizedBox(height: 16),
                            ..._sidebarSections(
                              pipeline,
                              isAgent: isAgent,
                              isReadOnly: isReadOnly,
                              canFieldWork: canFieldWork,
                              isWon: isWon,
                              isDeclined: isDeclined,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Primary info sections — the left column on desktop, the top of the single
  /// column on mobile.
  List<Widget> _primarySections(PipelineDetailModel pipeline,
      {required bool isAgent, required bool canWrite}) {
    final banner = PipelineReferralBanner.maybe(pipeline, currentUserId: _currentUserId);
    return [
      if (banner != null) ...[banner, const SizedBox(height: 16)],
      PipelineInfoCard(pipeline: pipeline),
      const SizedBox(height: 16),
      PipelinePengelolaCard(pipeline: pipeline),
      if (pipeline.parties.isNotEmpty) ...[
        const SizedBox(height: 16),
        PipelinePartiesCard(pipeline: pipeline),
      ],
      if (pipeline.isTender && pipeline.tenderProcesses.isNotEmpty) ...[
        const SizedBox(height: 16),
        PipelineTenderProcessesCard(pipeline: pipeline),
      ],
      if (pipeline.isTender && pipeline.wonShares.isNotEmpty) ...[
        const SizedBox(height: 16),
        PipelineWonSharesCard(pipeline: pipeline),
      ],
      const SizedBox(height: 16),
      PipelineDocumentsCard(
        pipeline: pipeline,
        docs: _docs,
        currentUserId: _currentUserId,
        isAgent: isAgent,
        canWrite: canWrite,
        onView: _openPipelineDoc,
        onUpload: _uploadPipelineDoc,
        onDelete: _deletePipelineDoc,
      ),
    ];
  }

  /// Buka dokumen SPAU/Underlying milik pipeline.
  ///
  /// Berkasnya dilayani `/api/files/**` yang menuntut token, jadi isinya diambil
  /// lewat ApiClient lalu diserahkan ke penampil — bukan dengan melempar URL ke
  /// peramban, yang hanya akan berbuah 401. Pola & alasannya sama persis dengan
  /// `CustomerDetailScreen._openDocument`; tab web sengaja dibuka LEBIH DULU di
  /// dalam handler ketukan karena Safari/iOS memblokir window.open() setelah await.
  Future<void> _openPipelineDoc(PipelineDocumentModel doc) async {
    final messenger = ScaffoldMessenger.of(context);
    final pending = openPendingTab();
    try {
      final res = await ref.read(apiClientProvider).get(doc.fileUrl);
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final mime = res.headers['content-type'] ?? 'application/octet-stream';
      final opened = await openBytes(res.bodyBytes, mime, doc.fileName, pending: pending);
      if (!opened) {
        closePendingTab(pending);
        messenger.showSnackBar(
          SnackBar(content: Text('Tidak ada aplikasi untuk membuka "${doc.fileName}".')),
        );
      }
    } catch (e) {
      closePendingTab(pending);
      messenger.showSnackBar(SnackBar(
        content: Text('Gagal membuka dokumen: ${e.toString().replaceFirst('Exception: ', '')}'),
        backgroundColor: AppColors.errorRed,
      ));
    }
  }

  Future<void> _uploadPipelineDoc(String docType) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) {
      return;
    }
    if (!mounted) return;
    final file = result.files.first;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _pipelineRepo.uploadDocument(
          widget.pipelineId, docType, file.bytes!, file.name);
      if (!mounted) return;
      await _fetchData(silent: true);
      messenger.showSnackBar(SnackBar(
          content: Text('Dokumen $docType disimpan'),
          backgroundColor: AppColors.successGreen));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Gagal menyimpan dokumen: ${e.toString().replaceFirst('Exception: ', '')}')));
    }
  }

  /// Konfirmasi hapus pipeline (ADMIN).
  ///
  /// Dialognya menyebut akibat yang tidak terlihat dari layar ini: jadwal,
  /// kunjungan, dan dokumennya ikut terhapus, dan untuk pipeline WON angka
  /// realisasi RM-nya ikut turun. Tanpa itu, penghapusan terasa seperti
  /// "menutup satu baris" padahal ia mengubah angka capaian.
  Future<void> _confirmDeletePipeline(PipelineDetailModel pipeline) async {
    final won = pipeline.stage.toUpperCase() == 'WON';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Hapus pipeline ini?'),
        content: Text(
          'Pipeline "${pipeline.projectName ?? pipeline.customerName ?? '-'}" '
          'akan dihapus permanen beserta jadwal, kunjungan, dan dokumennya.'
          '${won ? '\n\nPipeline ini berstatus WON: realisasinya ikut hilang, '
              'sehingga capaian RM yang bersangkutan akan turun.' : ''}'
          '\n\nTindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Hapus',
                  style: TextStyle(color: AppColors.errorRed))),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await _pipelineRepo.deletePipeline(pipeline.id);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('Pipeline dihapus'),
        backgroundColor: AppColors.successGreen,
      ));
      navigator.pop(true); // daftar di belakang memuat ulang
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.errorRed,
      ));
    }
  }

  Future<void> _deletePipelineDoc(PipelineDocumentModel doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
        scrollable: true,
        title: const Text('Hapus Dokumen'),
        content: Text('Hapus dokumen ${doc.docType} (${doc.fileName})?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Hapus', style: TextStyle(color: AppColors.errorRed))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _pipelineRepo.deleteDocument(widget.pipelineId, doc.id);
      if (!mounted) return;
      await _fetchData(silent: true);
      messenger.showSnackBar(const SnackBar(content: Text('Dokumen dihapus')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Gagal menghapus: ${e.toString().replaceFirst('Exception: ', '')}')));
    }
  }

  /// Actions + status banners + activity/timeline — the right sidebar on desktop,
  /// the continuation of the single column on mobile.
  List<Widget> _sidebarSections(
    PipelineDetailModel pipeline, {
    required bool isAgent,
    required bool isReadOnly,
    required bool canFieldWork,
    required bool isWon,
    required bool isDeclined,
  }) {
    // Jadwal yang tertinggal berstatus OPEN pada pipeline WON/DECLINE/hand-over masih
    // perlu dirapikan — ditandai selesai atau dibatalkan — justru KARENA pipeline-nya
    // sudah ditutup. Karena itu gerbang menu jadwal memakai HAK TULIS saja, bukan
    // isReadOnly yang ikut terkunci oleh siklus hidup. Dilaporkan 2026-08-20: pada
    // pipeline WON seluruh jadwalnya kehilangan titik tiga, sehingga jadwal telat tidak
    // bisa ditutup sama sekali. Gerbang peran & izin objek tetap dihormati, jadi
    // penonton read-only tidak disodori tombol yang ujungnya 403.
    final canManageSchedules = !isAgent && canFieldWork && pipeline.canEdit;
    return [
      // BUTTONS — RM only; hidden when WON/Declined (read-only).
      if (!isAgent && !isReadOnly) ...[
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () => _openStatusEditor(pipeline),
            icon: Icon(pipeline.isTender ? Icons.trending_up : Icons.swap_vert,
                size: 20, color: const Color(0xFF0E2B53)),
            label: Text(
              pipeline.isTender ? 'Maju Proses Tender' : 'Ubah Status Pipeline',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0E2B53),
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF0E2B53), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _showScheduleSheet,
            icon: const Icon(Icons.event, size: 20, color: Color(0xFF0E2B53)),
            label: const Text(
              'Jadwalkan Visit',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0E2B53),
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF0E2B53), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Mencatat aktivitas/visit wajib foto kamera + lokasi GPS. Native app selalu
        // boleh. Di web, sementara dibuka juga untuk browser HP (piloting — build iOS
        // native belum sempat diuji) via cek User-Agent; ini BUKAN pagar keamanan
        // (UA gampang di-spoof), cuma menahan pemakaian dari desktop/laptop selagi
        // native app belum tersedia di semua platform. Laptop/desktop tetap diganti
        // petunjuk memakai HP.
        if (kIsWeb && !isMobileBrowserUserAgent())
          const PipelineVisitWebNotice()
        else
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () async {
                final added = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddActivityScreen(pipelineId: widget.pipelineId),
                  ),
                );
                if (added == true) {
                  _fetchData();
                }
              },
              icon: const Icon(Icons.add, color: Colors.white, size: 20),
              label: const Text(
                'Tambah Aktivitas/Visit',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E2B53),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],

      // === Buat Quotation Slip (QS)
      if (!isAgent && !isWon && !isDeclined) ...[
        _buildQuotationSlipSection(pipeline),
        const SizedBox(height: 20),
      ],

      // WON — read-only celebration + (RM) cancel option.
      if (isWon) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.greenLight,
            borderRadius: AppRadius.radiusLg,
            border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.3)),
          ),
          child: const Column(
            children: [
              Icon(Icons.celebration, color: AppColors.successGreen, size: 28),
              SizedBox(height: 6),
              Text('Selamat, pipeline sudah Won!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.successGreen)),
              SizedBox(height: 2),
              Text('Detail bersifat read-only.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        // "Pipeline Dicancel" memanggil PUT /{id}/status → hasRole('RM'). BM/RO
        // tidak lolos, jadi tombolnya jangan ditampilkan kepada mereka.
        if (!isAgent && canFieldWork) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => _showCancelWonDialog(pipeline),
              icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.errorRed),
              label: const Text('Pipeline Dicancel',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.errorRed)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.errorRed),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],

      // DECLINE / CANCELED — read-only banner + alasan (P6).
      if (isDeclined) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.redLight,
            borderRadius: AppRadius.radiusLg,
            border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cancel_outlined, color: AppColors.errorRed, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    PipelineStages.labelOf(pipeline.subStage),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.errorRed),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Alasan',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(
                (pipeline.cancelReason != null && pipeline.cancelReason!.isNotEmpty)
                    ? pipeline.cancelReason!
                    : '-',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary, height: 1.4),
              ),
              const SizedBox(height: 4),
              const Text('Detail bersifat read-only.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],

      // ── Jadwal Mendatang (open only, nearest first) ──
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Jadwal Mendatang',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          InkWell(
            onTap: () => goRel(context, '/activity'),
            child: const Text('Lihat semua',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.secondaryOrange)),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Builder(builder: (_) {
        final open = pipeline.schedules
            .where((s) => s.status.toUpperCase() == 'OPEN')
            .toList()
          ..sort((a, b) => (a.date ?? '').compareTo(b.date ?? ''));
        if (open.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: AppRadius.radiusLg,
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Text('Belum ada jadwal mendatang',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ),
          );
        }
        return Column(
            children: open
                .take(3)
                .map((s) => PipelineScheduleCard(
                      schedule: s,
                      editable: canManageSchedules,
                      onEdit: _editSchedule,
                      onCancel: _cancelSchedule,
                      onComplete: _completeSchedule,
                    ))
                .toList());
      }),

      // ── Riwayat (perubahan status + kunjungan, satu timeline; terbaru dulu) ──
      Builder(builder: (_) {
        // Edits are hidden here to match the Riwayat tab's default — the preview
        // is for "what happened", and the tab's toggle is where field-level
        // changes are opted into.
        final entries = mergePipelineTimeline(
          history: _history,
          visits: _visits,
          includeEdits: false,
        );
        if (entries.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Riwayat',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                InkWell(
                  onTap: () => goRel(context, '/activity?tab=1'),
                  child: const Text('Lihat semua',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.secondaryOrange)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final e in entries.take(3)) _buildTimelineCard(e),
          ],
        );
      }),
    ];
  }

  Widget _buildTimelineCard(TimelineEntry e) {
    final visit = e.visit;
    return TimelineEntryCard(
      entry: e,
      onTap: visit == null
          ? null
          : () async {
              await vds.loadLibrary();
              if (!mounted) return;
              final changed = await vds.showVisitDetail(context, _apiClient, visit);
              if (changed && mounted) await _fetchData(silent: true);
            },
    );
  }

  /// Strong confirmation to cancel a WON pipeline: retype the phrase, give a
  /// reason, AND wait 10 seconds. On confirm, status -> Canceled (Customer),
  /// the reason is stored, and realisasi is reverted (BE).
  Future<void> _showCancelWonDialog(PipelineDetailModel pipeline) async {
    final ctrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    const phrase = 'pipeline dicancel';
    int remaining = 10;
    Timer? timer;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        // Controller dibuang saat dialog benar-benar lepas dari tree (setelah
        // animasi keluar), bukan tepat setelah `await` — lihat dispose_callback.dart.
        return DisposeCallback(
          onDispose: () {
            ctrl.dispose();
            reasonCtrl.dispose();
          },
          child: StatefulBuilder(
          builder: (dialogCtx, setD) {
            timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (remaining <= 1) t.cancel();
              setD(() => remaining = remaining > 0 ? remaining - 1 : 0);
            });
            final canConfirm = remaining == 0 &&
                ctrl.text.trim().toLowerCase() == phrase &&
                reasonCtrl.text.trim().isNotEmpty;
            return AlertDialog(
              title: const Text('Batalkan Pipeline yang sudah Won?'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status berubah dari Won menjadi Canceled (Customer) dan nilai realisasi '
                      'dihapus (total di dashboard ikut berkurang). Pastikan ini benar-benar dibatalkan.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    const Text('Alasan pembatalan (wajib)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonCtrl,
                      onChanged: (_) => setD(() {}),
                      maxLines: 2,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                          hintText: 'mis. customer memilih kompetitor',
                          hintStyle: const TextStyle(fontSize: 13, color: AppColors.grayStage),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: AppRadius.radiusMd)),
                    ),
                    const SizedBox(height: 12),
                    const Text('Ketik ulang: "pipeline dicancel"',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: ctrl,
                      onChanged: (_) => setD(() {}),
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                          isDense: true, border: OutlineInputBorder(borderRadius: AppRadius.radiusMd)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    timer?.cancel();
                    Navigator.of(dialogCtx).pop(false);
                  },
                  child: const Text('Kembali'),
                ),
                TextButton(
                  onPressed: canConfirm
                      ? () {
                          timer?.cancel();
                          Navigator.of(dialogCtx).pop(true);
                        }
                      : null,
                  child: Text(
                    canConfirm ? 'Oke, Cancel' : 'Tunggu ${remaining}s',
                    style: TextStyle(
                        color: canConfirm ? AppColors.errorRed : AppColors.grayStage,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
          ),
        );
      },
    );
    timer?.cancel();
    final reason = reasonCtrl.text.trim();

    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _pipelineRepo.updateStatus(pipeline.id,
          subStage: 'CANCELED_CUSTOMER', cancelReason: reason);
      if (!mounted) return;
      _fetchData(silent: true);
      messenger.showSnackBar(const SnackBar(content: Text('Pipeline dibatalkan (Canceled)')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  /// Buka formulir pipeline dalam mode edit.
  ///
  /// Memakai [AddPipelineScreen] yang sama dengan alur tambah, menggantikan sheet
  /// lama yang hanya memuat sebagian field — nama tender, tahapan tender, dan
  /// pihak kerja sama dulu tidak pernah bisa diperbaiki setelah pipeline dibuat.
  /// Penyimpanan dikerjakan layar itu; di sini tinggal memuat ulang detailnya.
  Future<void> _openEditPipeline(PipelineDetailModel p) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddPipelineScreen(
          customerId: p.customerId ?? '',
          customerName: p.customerName,
          existing: p,
        ),
      ),
    );
    if (saved == true && mounted) await _fetchData(silent: true);
  }

  /// Schedule a future visit. Self-contained sheet; inline required-field
  /// validation lives inside the sheet (J2).
  Future<void> _showScheduleSheet() async {
    final result = await showModalBottomSheet<_ScheduleResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const _ScheduleSheet(),
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _pipelineRepo.addSchedule(widget.pipelineId,
          agenda: result.agenda, scheduleDateTime: result.dateTime);
      if (!mounted) return;
      _fetchData(silent: true);
      messenger.showSnackBar(const SnackBar(content: Text('Jadwal visit dibuat')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  /// Reschedule / edit an existing OPEN schedule. Reuses [_ScheduleSheet]
  /// pre-filled with the current date/time/agenda; the backend rejects edits
  /// to DONE/CANCELLED schedules.
  Future<void> _editSchedule(PipelineScheduleModel s) async {
    final initial = s.date != null ? DateTime.tryParse(s.date!)?.toLocal() : null;
    final result = await showModalBottomSheet<_ScheduleResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _ScheduleSheet(
        initialDateTime: initial,
        initialAgenda: s.title,
        title: 'Ubah Jadwal',
      ),
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _pipelineRepo.updateSchedule(s.id,
          agenda: result.agenda, scheduleDateTime: result.dateTime);
      if (!mounted) return;
      _fetchData(silent: true);
      messenger.showSnackBar(const SnackBar(content: Text('Jadwal diperbarui')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  /// Soft-delete a schedule: mark it CANCELLED. It then drops out of the
  /// "Jadwal Mendatang" list (which only shows OPEN) but the record is kept.
  /// Tutup jadwal yang sudah dikerjakan. Dipakai juga untuk merapikan jadwal telat
  /// yang tertinggal OPEN — termasuk pada pipeline yang siklus hidupnya sudah ditutup.
  Future<void> _completeSchedule(PipelineScheduleModel s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Tandai jadwal selesai?'),
        content: Text(
          'Jadwal "${s.title.isEmpty ? 'kunjungan' : s.title}" akan ditandai selesai dan '
          'hilang dari daftar jadwal mendatang. Lanjutkan?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Kembali')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Tandai selesai',
                style: TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _pipelineRepo.setScheduleStatus(s.id, 'DONE');
      if (!mounted) return;
      _fetchData(silent: true);
      messenger.showSnackBar(const SnackBar(content: Text('Jadwal ditandai selesai')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _cancelSchedule(PipelineScheduleModel s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
        scrollable: true,
        title: const Text('Batalkan jadwal?'),
        content: Text(
          'Jadwal "${s.title.isEmpty ? 'kunjungan' : s.title}" akan dibatalkan dan '
          'hilang dari daftar jadwal mendatang. Lanjutkan?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Kembali')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Batalkan jadwal',
                style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _pipelineRepo.setScheduleStatus(s.id, 'CANCELLED');
      if (!mounted) return;
      _fetchData(silent: true);
      messenger.showSnackBar(const SnackBar(content: Text('Jadwal dibatalkan')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  /// Route the status editor: tender pipelines use the dedicated step-by-step
  /// screen; the rest use the normal status sheet.
  Future<void> _openStatusEditor(PipelineDetailModel p) async {
    if (p.isTender) {
      final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => TenderStatusScreen(pipeline: p, apiClient: _apiClient)));
      if (changed == true && mounted) _fetchData(silent: true);
    } else {
      _showStatusSheet(p);
    }
  }

  /// Move the pipeline to a sub-stage. Self-contained sheet; WON needs realisasi,
  /// DECLINE needs a reason (both enforced inside the sheet and on the backend).
  Future<void> _showStatusSheet(PipelineDetailModel pipeline) async {
    final result = await showModalBottomSheet<_StatusResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (_) => _StatusSheet(pipeline: pipeline),
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _pipelineRepo.updateStatus(pipeline.id,
          subStage: result.subStage,
          realisasiIdr: result.realisasiIdr,
          cancelReason: result.cancelReason,
          policyNumber: result.policyNumber,
          policyStart: result.policyStart,
          policyEnd: result.policyEnd,
          policyIssuedDate: result.policyIssuedDate);
      if (!mounted) return;
      _fetchData(silent: true);
      messenger.showSnackBar(const SnackBar(content: Text('Status pipeline diperbarui')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  // ── Quotation Slip (QS) Integration (Dynamic from /api/pipeline/{id}/isQas) ──

  QsProduct _resolveQsProduct(String? prodName) {
    if (prodName != null) {
      final lower = prodName.toLowerCase();
      if (lower.contains('pa xtra') ||
          lower.contains('paxtra') ||
          lower.contains('pa extra') ||
          lower.contains('personal accident')) {
        return QsProduct.paXtra;
      }
    }
    return QsProduct.psakdi;
  }

  Widget _buildQsLoadingCard() {
    return Skeletonizer(
      enabled: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.post_add_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Buat Quotation Slip (QS)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.alertTitle,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Memeriksa ketersediaan fitur Quotation Slip...',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQsErrorBanner(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.errorBannerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.errorBannerBorder, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.error_outline_rounded,
              size: 20,
              color: AppColors.errorBannerTitle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Gagal memuat status QS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.errorBannerTitle,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  error,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.errorBannerText,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _fetchQasStatus,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.errorBannerTitle,
            ),
            child: const Text(
              'Coba Lagi',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationSlipSection(PipelineDetailModel pipeline) {
    if (_isQasLoading) {
      return _buildQsLoadingCard();
    }
    if (_qasError != null) {
      return _buildQsErrorBanner(_qasError!);
    }
    if (_qasStatus != null && _qasStatus!.isQas == true) {
      final qsProd = _resolveQsProduct(_qasStatus?.productName ?? pipeline.product);
      final prodLabel = qsProd == QsProduct.psakdi ? 'PSAKDI' : 'PA Xtra';
      final displayName = (_qasStatus?.productName != null && _qasStatus!.productName!.trim().isNotEmpty)
          ? _qasStatus!.productName!
          : prodLabel;
      final hint = '$displayName · data customer & pipeline terisi otomatis';
      return _buildActiveQsButton(pipeline, qsProd, hint, productCode: _qasStatus?.productCode);
    }
    return _buildDisabledQsBanner(pipeline, _qasStatus?.productName);
  }

  Widget _buildActiveQsButton(
    PipelineDetailModel pipeline,
    QsProduct product,
    String hint, {
    String? productCode,
  }) {
    return Material(
      color: AppColors.alertBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => QsFormScreen(
                product: product,
                customerName: pipeline.customerName,
                pipelineId: _activePipelineId,
                productCode: productCode ?? _qasStatus?.productCode,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.orangeMbis, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.orangeMbis,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.post_add_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Buat Quotation Slip (QS)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.alertTitle,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.alertTitle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisabledQsBanner(PipelineDetailModel pipeline, [String? productName]) {
    final title = (productName != null && productName.trim().isNotEmpty)
        ? 'QS belum tersedia untuk $productName'
        : 'QS belum tersedia untuk produk ini';
    return CustomPaint(
      painter: DashedRectPainter(
        color: AppColors.borderDashed,
        strokeWidth: 1.5,
        gap: 5,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgDisabledCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.lock_outline,
                size: 20,
                color: AppColors.iconDropdown,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textLabel,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Saat ini QS hanya tersedia untuk PSAKDI – Personal dan PA Xtra – Personal.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
//  Bottom-sheet widgets — each is its own StatefulWidget (not an inline
//  StatefulBuilder) so route teardown disposes their MediaQuery/controllers
//  cleanly. They return their result via Navigator.pop; the caller performs
//  the network call afterwards (avoids the `_dependents.isEmpty` assertion).
// ===========================================================================

/// Result of [_ScheduleSheet].
class _ScheduleResult {
  final DateTime dateTime;
  final String agenda;
  _ScheduleResult(this.dateTime, this.agenda);
}

class _ScheduleSheet extends StatefulWidget {
  /// When set, the sheet opens in edit mode pre-filled with these values.
  final DateTime? initialDateTime;
  final String? initialAgenda;
  final String title;
  const _ScheduleSheet({
    this.initialDateTime,
    this.initialAgenda,
    this.title = 'Jadwalkan Visit',
  });

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  DateTime? _date;
  TimeOfDay? _time;
  late final TextEditingController _agendaCtrl;
  bool _showErrors = false; // inline required-field validation (J2)

  @override
  void initState() {
    super.initState();
    final dt = widget.initialDateTime;
    if (dt != null) {
      _date = DateTime(dt.year, dt.month, dt.day);
      _time = TimeOfDay(hour: dt.hour, minute: dt.minute);
    }
    _agendaCtrl = TextEditingController(text: widget.initialAgenda ?? '');
  }

  @override
  void dispose() {
    _agendaCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final agendaEmpty = _agendaCtrl.text.trim().isEmpty;
    if (_date == null || _time == null || agendaEmpty) {
      setState(() => _showErrors = true);
      return;
    }
    final dt = DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
    Navigator.of(context).pop(_ScheduleResult(dt, _agendaCtrl.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _date == null ? 'Pilih tanggal' : AppFormat.dateOnly(_date);
    final timeLabel = _time == null ? 'Pilih waktu' : _time!.format(context);
    final agendaEmpty = _agendaCtrl.text.trim().isEmpty;
    return Padding(
      padding: EdgeInsets.only(
          left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      // Isi sheet bisa lebih tinggi dari layar (mis. daftar chip kategori,
      // atau keyboard terbuka di layar pendek) -> harus bisa di-scroll,
      // kalau tidak muncul garis kuning 'BOTTOM OVERFLOWED BY ... PIXELS'.
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        // Allow rescheduling an already-overdue plan: clamp
                        // firstDate so an existing past date stays selectable.
                        final defaultFirst = now.subtract(const Duration(days: 1));
                        final first = _date != null && _date!.isBefore(defaultFirst) ? _date! : defaultFirst;
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date ?? now,
                          firstDate: first,
                          lastDate: now.add(const Duration(days: 365)),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(dateLabel, overflow: TextOverflow.ellipsis),
                    ),
                    if (_showErrors && _date == null)
                      const Padding(
                        padding: EdgeInsets.only(left: 4, top: 4),
                        child: Text('Tanggal wajib diisi',
                            style: TextStyle(fontSize: 11, color: AppColors.errorRed)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                        if (picked != null) setState(() => _time = picked);
                      },
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text(timeLabel, overflow: TextOverflow.ellipsis),
                    ),
                    if (_showErrors && _time == null)
                      const Padding(
                        padding: EdgeInsets.only(left: 4, top: 4),
                        child: Text('Waktu wajib diisi',
                            style: TextStyle(fontSize: 11, color: AppColors.errorRed)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _agendaCtrl,
            onChanged: (_) {
              if (_showErrors) setState(() {});
            },
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Agenda',
              labelStyle: const TextStyle(fontSize: 13),
              hintText: 'mis. Follow up penawaran',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.grayStage),
              isDense: true,
              border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
              errorText: _showErrors && agendaEmpty ? 'Agenda wajib diisi' : null,
              errorStyle: const TextStyle(fontSize: 11, color: AppColors.errorRed),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
              ),
              child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Result of [_StatusSheet].
class _StatusResult {
  final String subStage;
  final double? realisasiIdr;
  final String? cancelReason;
  final String? policyNumber;
  /// Periode polis (ISO yyyy-MM-dd) — wajib menyertai [policyNumber]. Nomor dan
  /// masa berlaku sama-sama berasal dari sistem penerbitan polis di luar aplikasi.
  final String? policyStart;
  final String? policyEnd;
  /// Tanggal terbit polis (ISO yyyy-MM-dd) — penentu bulan pengakuan realisasi.
  /// Opsional dan berdiri sendiri dari [policyNumber]: bila null, server memakai
  /// tanggal Won.
  final String? policyIssuedDate;
  _StatusResult(this.subStage,
      {this.realisasiIdr,
      this.cancelReason,
      this.policyNumber,
      this.policyStart,
      this.policyEnd,
      this.policyIssuedDate});
}

class _StatusSheet extends StatefulWidget {
  final PipelineDetailModel pipeline;
  const _StatusSheet({required this.pipeline});

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  String? _selectedBucket;
  String? _selected;
  late final TextEditingController _realisasiCtrl;
  final _reasonCtrl = TextEditingController();
  late final TextEditingController _policyCtrl;
  DateTime? _policyStart;
  DateTime? _policyEnd;
  /// Tanggal terbit polis — penentu bulan pengakuan realisasi. Opsional: bila
  /// dikosongkan server memakai tanggal Won. Sengaja terpisah dari [_policyStart],
  /// yang menandai awal masa berlaku dan bisa jatuh di bulan yang berbeda.
  DateTime? _policyIssuedDate;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _realisasiCtrl = TextEditingController(
      text: widget.pipeline.realisasiIdr != null
          ? AppFormat.thousands(widget.pipeline.realisasiIdr!.round())
          : '',
    );
    _policyCtrl = TextEditingController(text: widget.pipeline.policyNumber ?? '');
    // Prefill supaya membuka sheet ini lagi untuk mengoreksi hal lain tidak
    // diam-diam menghapus tanggal terbit yang sudah tercatat.
    _policyIssuedDate = DateTime.tryParse(widget.pipeline.policyIssuedDate ?? '');
  }

  @override
  void dispose() {
    _realisasiCtrl.dispose();
    _reasonCtrl.dispose();
    _policyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selected == null) {
      setState(() => _showErrors = true);
      return;
    }
    final isWon = _selectedBucket == 'WON';
    final isDecline = _selectedBucket == 'DECLINE';
    double? realisasi;
    if (isWon) {
      final digits = _realisasiCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty) {
        setState(() => _showErrors = true);
        return;
      }
      realisasi = double.parse(digits);
    }
    String? reason;
    if (isDecline) {
      reason = _reasonCtrl.text.trim();
      if (reason.isEmpty) {
        setState(() => _showErrors = true);
        return;
      }
    }
    String? policyNumber;
    if (isWon) {
      final p = _policyCtrl.text.trim();
      if (p.isEmpty) {
        setState(() => _showErrors = true);
        return;
      }
      policyNumber = p;

      if (_policyStart == null || _policyEnd == null || _hasPeriodOrderError) {
        setState(() => _showErrors = true);
        return;
      }
    }
    // Tanggal Terbit Polis WAJIB saat WON (CR-04). Inilah bulan pengakuan
    // realisasi; tanpa isian ini pipeline bisa jadi WON tanpa bulan yang
    // menentukan angka dashboard, dan itu melubangi seluruh gunanya. Nilai
    // cadangan berupa tanggal WON di server sengaja hanya untuk data lama.
    if (isWon && _policyIssuedDate == null) {
      setState(() => _showErrors = true);
      return;
    }
    // Konfirmasi kalau nilai realisasi WON berbeda dari nilai premi awal
    // (estimasi saat pipeline dibuat). Mencegah salah ketik nilai realisasi.
    if (isWon && realisasi != null) {
      final baseline = widget.pipeline.premi ?? widget.pipeline.potensiPremi;
      if (baseline != null && baseline > 0 && realisasi.round() != baseline.round()) {
        final ok = await _confirmRealisasiChanged(baseline, realisasi);
        if (ok != true) return;
        if (!mounted) return;
      }
    }
    Navigator.of(context).pop(_StatusResult(_selected!,
        realisasiIdr: realisasi,
        cancelReason: reason,
        policyNumber: policyNumber,
        policyStart: policyNumber == null ? null : _isoDate(_policyStart!),
        policyEnd: policyNumber == null ? null : _isoDate(_policyEnd!),
        // Tidak diikat pada ada/tidaknya No. Polis: bulan pengakuan realisasi
        // tetap bisa dicatat walau nomor polisnya belum keluar.
        policyIssuedDate: !isWon || _policyIssuedDate == null
            ? null
            : _isoDate(_policyIssuedDate!)));
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _customerOwnerType {
    final name = (widget.pipeline.customerName ?? '').toUpperCase();
    final source = (widget.pipeline.sourceType ?? '').toUpperCase();
    if (name.contains('PERSERO') ||
        name.contains('BUMN') ||
        name.contains('PERUM') ||
        source.contains('BUMN')) {
      return 'BUMN';
    }
    return 'tipe Swasta';
  }

  bool get _hasRealisasiError {
    if (_selectedBucket != 'WON') return false;
    final digits = _realisasiCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty || (double.tryParse(digits) ?? 0) <= 0;
  }

  bool get _hasPolicyNoError {
    if (_selectedBucket != 'WON') return false;
    return _policyCtrl.text.trim().isEmpty;
  }

  bool get _hasPeriodOrderError {
    if (_selectedBucket != 'WON') return false;
    if (_policyStart != null && _policyEnd != null) {
      return _policyEnd!.isBefore(_policyStart!) || _policyEnd!.isAtSameMomentAs(_policyStart!);
    }
    return false;
  }

  bool get _hasPeriodError {
    if (_selectedBucket != 'WON') return false;
    if (_hasPeriodOrderError) return true;
    return _policyStart == null || _policyEnd == null;
  }

  bool get _hasTerbitError {
    if (_selectedBucket != 'WON') return false;
    return _policyIssuedDate == null;
  }

  bool get _hasReasonError {
    if (_selectedBucket != 'DECLINE') return false;
    return _reasonCtrl.text.trim().isEmpty;
  }

  bool get _hasAnyError {
    if (_selected == null) return true;
    if (_selectedBucket == 'WON') {
      return _hasRealisasiError || _hasPolicyNoError || _hasPeriodError || _hasTerbitError;
    }
    if (_selectedBucket == 'DECLINE') {
      return _hasReasonError;
    }
    return false;
  }

  /// Satu isian tanggal periode polis dengan title kecil di atas (floating label).
  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onPicked,
    bool hasError = false,
  }) {
    final text = value == null ? 'Pilih tanggal' : _isoDate(value);
    final borderColor = hasError ? const Color(0xFFC8322F) : const Color(0xFFD5DCE7);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? now,
              firstDate: DateTime(now.year - 5),
              lastDate: DateTime(now.year + 5),
            );
            if (picked != null) onPicked(picked);
          },
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      color: value == null ? const Color(0xFF8A94A6) : const Color(0xFF15223B),
                    ),
                  ),
                ),
                const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF6B7485)),
              ],
            ),
          ),
        ),
        Positioned(
          left: 12,
          top: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            color: Colors.white,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF5A6475),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Dialog konfirmasi saat nilai realisasi WON beda dari nilai awal.
  Future<bool?> _confirmRealisasiChanged(double baseline, double entered) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Nilai realisasi berubah?'),
        content: Text(
          'Nilai yang Anda masukkan (${AppFormat.rupiah(entered)}) berbeda dengan '
          'nilai awal (${AppFormat.rupiah(baseline)}).\n\n'
          'Apakah Anda yakin nilainya berubah?',
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E2B53),
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, lanjutkan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWon = _selectedBucket == 'WON';
    final isDecline = _selectedBucket == 'DECLINE';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Sheet
          Row(
            children: [
              if (_selectedBucket != null)
                InkWell(
                  onTap: () => setState(() {
                    _selectedBucket = null;
                    _selected = null;
                    _showErrors = false;
                  }),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.arrow_back, size: 22, color: Color(0xFF15223B)),
                  ),
                ),
              const Text(
                'Ubah Status Pipeline',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF15223B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _selectedBucket == null
                ? 'Langkah 1 — pilih tahap pipeline'
                : 'Langkah 2 — pilih detail di ${PipelineStages.bucketLabel[_selectedBucket]}',
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF5A6475)),
          ),
          const SizedBox(height: 16),

          Flexible(
            child: SingleChildScrollView(
              child: _selectedBucket == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final bucket in PipelineStages.byBucket.keys)
                          Builder(builder: (context) {
                            final isCurrent = widget.pipeline.stage.toUpperCase() == bucket;
                            final isSelected = _selectedBucket == bucket;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: InkWell(
                                onTap: () => setState(() {
                                  _selectedBucket = bucket;
                                  final subs = PipelineStages.byBucket[bucket]!;
                                  if (bucket == 'WON') {
                                    _selected = 'TERBIT_POLIS';
                                  } else if (subs.length == 1) {
                                    _selected = subs.first.value;
                                  } else {
                                    _selected = subs.first.value;
                                  }
                                }),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: double.infinity,
                                  constraints: const BoxConstraints(minHeight: 52),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFE9EEF6) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          PipelineStages.bucketLabel[bucket] ?? bucket,
                                          style: TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            color: const Color(0xFF15223B),
                                          ),
                                        ),
                                      ),
                                      if (isCurrent) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEEF1F6),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Saat ini',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF5A6475),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      if (isSelected && bucket != 'WON')
                                        const Icon(Icons.check, size: 18, color: Color(0xFF0E2B53))
                                      else
                                        const Icon(Icons.chevron_right, size: 18, color: Color(0xFF6B7485)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Radio Row Terbit Polis
                        if (isWon) ...[
                          Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF0E2B53), width: 2),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF0E2B53),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Terbit Polis',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF15223B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Banner info Customer BUMN / Swasta
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF6EF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF3C9A8)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline, size: 18, color: Color(0xFFC25A17)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      text: 'Customer ',
                                      children: [
                                        TextSpan(
                                          text: _customerOwnerType,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const TextSpan(
                                          text: ': Nilai Premi, No. Polis, dan Periode Polis ',
                                        ),
                                        const TextSpan(
                                          text: 'wajib diisi',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const TextSpan(text: '.'),
                                      ],
                                    ),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF7A3A0E),
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Banner Error jika ada isian merah belum lengkap
                          if (_showErrors && _hasAnyError) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDECEC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Lengkapi isian bertanda merah.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF9E2522),
                                ),
                              ),
                            ),
                          ],

                          // Nilai Premi (wajib)
                          Text.rich(
                            const TextSpan(
                              text: 'Nilai Premi ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF15223B),
                              ),
                              children: [
                                TextSpan(
                                  text: '(wajib)',
                                  style: TextStyle(color: Color(0xFFC8322F)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _showErrors && _hasRealisasiError
                                    ? const Color(0xFFC8322F)
                                    : const Color(0xFFD5DCE7),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  'Rp',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF5A6475),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _realisasiCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [ThousandsInputFormatter()],
                                    onChanged: (_) {
                                      if (_showErrors) setState(() {});
                                    },
                                    style: const TextStyle(fontSize: 15, color: Color(0xFF15223B)),
                                    decoration: const InputDecoration(
                                      hintText: 'mis. 500.000.000',
                                      hintStyle: TextStyle(fontSize: 14, color: Color(0xFF8A94A6)),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_showErrors && _hasRealisasiError)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                'Wajib diisi',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFC8322F),
                                ),
                              ),
                            ),
                          const SizedBox(height: 14),

                          // No. Polis (wajib)
                          Text.rich(
                            const TextSpan(
                              text: 'No. Polis ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF15223B),
                              ),
                              children: [
                                TextSpan(
                                  text: '(wajib)',
                                  style: TextStyle(color: Color(0xFFC8322F)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _showErrors && _hasPolicyNoError
                                    ? const Color(0xFFC8322F)
                                    : const Color(0xFFD5DCE7),
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.centerLeft,
                            child: TextField(
                              controller: _policyCtrl,
                              onChanged: (_) {
                                if (_showErrors) setState(() {});
                              },
                              style: const TextStyle(fontSize: 15, color: Color(0xFF15223B)),
                              decoration: const InputDecoration(
                                hintText: 'mis. 101.2026.0001',
                                hintStyle: TextStyle(fontSize: 14, color: Color(0xFF8A94A6)),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_showErrors && _hasPolicyNoError)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                'Wajib diisi',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFC8322F),
                                ),
                              ),
                            ),
                          const SizedBox(height: 14),

                          // Periode Polis (wajib)
                          Text.rich(
                            const TextSpan(
                              text: 'Periode Polis ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF15223B),
                              ),
                              children: [
                                TextSpan(
                                  text: '(wajib)',
                                  style: TextStyle(color: Color(0xFFC8322F)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateField(
                                  label: 'Mulai',
                                  value: _policyStart,
                                  hasError: _showErrors && _hasPeriodError && _policyStart == null,
                                  onPicked: (d) => setState(() {
                                    _policyStart = d;
                                    _policyEnd ??= DateTime(d.year + 1, d.month, d.day);
                                  }),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildDateField(
                                  label: 'Selesai',
                                  value: _policyEnd,
                                  hasError: _showErrors && _hasPeriodError && (_policyEnd == null || _hasPeriodOrderError),
                                  onPicked: (d) => setState(() => _policyEnd = d),
                                ),
                              ),
                            ],
                          ),
                          if (_showErrors && _hasPeriodError)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                _hasPeriodOrderError
                                    ? 'Tanggal selesai harus setelah tanggal mulai'
                                    : 'Wajib diisi',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFC8322F),
                                ),
                              ),
                            ),
                          const SizedBox(height: 14),

                          // Tanggal Terbit Polis *
                          Text.rich(
                            const TextSpan(
                              text: 'Tanggal Terbit Polis ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF15223B),
                              ),
                              children: [
                                TextSpan(
                                  text: '*',
                                  style: TextStyle(color: Color(0xFFC8322F)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildDateField(
                            label: 'Tanggal terbit',
                            value: _policyIssuedDate,
                            hasError: _showErrors && _hasTerbitError,
                            onPicked: (d) => setState(() => _policyIssuedDate = d),
                          ),
                          if (_showErrors && _hasTerbitError)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                'Wajib diisi',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFC8322F),
                                ),
                              ),
                            ),
                        ] else if (isDecline) ...[
                          for (final sub in PipelineStages.byBucket['DECLINE']!)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: InkWell(
                                onTap: () => setState(() => _selected = sub.value),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _selected == sub.value
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        size: 20,
                                        color: _selected == sub.value
                                            ? const Color(0xFF0E2B53)
                                            : const Color(0xFF6B7485),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          sub.label,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: _selected == sub.value ? FontWeight.w600 : FontWeight.normal,
                                            color: const Color(0xFF15223B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Text.rich(
                            const TextSpan(
                              text: 'Alasan ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF15223B),
                              ),
                              children: [
                                TextSpan(
                                  text: '(wajib)',
                                  style: TextStyle(color: Color(0xFFC8322F)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _showErrors && _hasReasonError
                                    ? const Color(0xFFC8322F)
                                    : const Color(0xFFD5DCE7),
                                width: 1.5,
                              ),
                            ),
                            child: TextField(
                              controller: _reasonCtrl,
                              maxLines: 2,
                              onChanged: (_) {
                                if (_showErrors) setState(() {});
                              },
                              style: const TextStyle(fontSize: 14, color: Color(0xFF15223B)),
                              decoration: const InputDecoration(
                                hintText: 'mis. Decline dari UW / customer membatalkan',
                                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF8A94A6)),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_showErrors && _hasReasonError)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                'Alasan wajib diisi',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFC8322F),
                                ),
                              ),
                            ),
                        ] else ...[
                          // Sub stages for P3, P2, P1
                          for (final sub in PipelineStages.byBucket[_selectedBucket]!)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: InkWell(
                                onTap: () => setState(() => _selected = sub.value),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _selected == sub.value
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        size: 20,
                                        color: _selected == sub.value
                                            ? const Color(0xFF0E2B53)
                                            : const Color(0xFF6B7485),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          sub.label,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: _selected == sub.value ? FontWeight.w600 : FontWeight.normal,
                                            color: const Color(0xFF15223B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Tombol Simpan
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E2B53),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                'Simpan',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

