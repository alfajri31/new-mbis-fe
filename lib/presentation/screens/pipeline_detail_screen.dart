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
import '../../src/broker/broker_repository.dart';
import '../../src/reference/reference_repository.dart';
import '../../src/app.dart';
import '../../src/network/api_client.dart';
import '../../src/pipeline/pipeline_stage.dart';
import '../../utils/format.dart';
import '../../utils/input_formatters.dart';
import '../../utils/responsive.dart';
import '../widgets/timeline_entry_card.dart';
import '../widgets/pipeline_detail/pipeline_header_stepper.dart';
import '../widgets/pipeline_detail/pipeline_info_card.dart';
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
import 'tender_status_screen.dart';
import '../widgets/dispose_callback.dart';

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
  List<BrokerModel> get _brokers =>
      _ds.brokers; // edit sheet broker dropdown (P4)
  ProductCascade get _cascade => _ds.cascade; // edit sheet COB/LOB/ToC
  List<ParamRef> get _kerjaSamaOptions => _ds.kerjaSamaOptions;

  // Repo/ApiClient untuk aksi-tulis & preview yang tetap di widget (upload/delete
  // dokumen, edit/ubah status, jadwal, buka visit). Dari shared provider — bukan
  // konstruksi ApiClient sendiri.
  ApiClient get _apiClient => ref.read(apiClientProvider);
  PipelineRepository get _pipelineRepo => ref.read(pipelineRepoProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = MbisApp.of(context)?.session;
      _currentUserId = session?.user.id;
      // Bootstrap notifier (fetch detail + broker/referensi edit-sheet). Repo kini
      // dibaca notifier dari shared provider — tak perlu susun ApiClient di sini.
      _pdNotifier.start(widget.pipelineId);
      // Label langkah tender ikut master data (editable admin).
      loadTenderLabels(_apiClient).then((_) {
        if (mounted) setState(() {});
      });
    });
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
  Future<void> _fetchData({bool silent = false}) =>
      _pdNotifier.fetchData(silent: silent);

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
    final isReadOnly = isWon || isDeclined || isHandedOver;

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
          if (!isAgent && !isReadOnly)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              tooltip: 'Edit Pipeline',
              onPressed: () => _showEditPipelineSheet(pipeline),
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
                                children: _primarySections(pipeline, isAgent: isAgent),
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
                            ..._primarySections(pipeline, isAgent: isAgent),
                            const SizedBox(height: 16),
                            ..._sidebarSections(
                              pipeline,
                              isAgent: isAgent,
                              isReadOnly: isReadOnly,
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
  List<Widget> _primarySections(PipelineDetailModel pipeline, {required bool isAgent}) {
    final banner = PipelineReferralBanner.maybe(pipeline, currentUserId: _currentUserId);
    return [
      if (banner != null) ...[banner, const SizedBox(height: 16)],
      PipelineInfoCard(pipeline: pipeline),
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
    required bool isWon,
    required bool isDeclined,
  }) {
    return [
      // BUTTONS — RM only; hidden when WON/Declined (read-only).
      if (!isAgent && !isReadOnly) ...[
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => _openStatusEditor(pipeline),
            icon: Icon(pipeline.isTender ? Icons.trending_up : Icons.swap_vert,
                size: 18, color: AppColors.primaryNavy),
            label: Text(
              pipeline.isTender ? 'Maju Proses Tender' : 'Ubah Status Pipeline',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primaryNavy),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _showScheduleSheet,
            icon: const Icon(Icons.event, size: 18, color: AppColors.primaryNavy),
            label: const Text(
              'Jadwalkan Visit',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primaryNavy),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
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
            height: 52,
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
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: const Text(
                'Tambah Aktivitas/Visit',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.radiusLg,
                ),
                elevation: 0,
              ),
            ),
          ),
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
        if (!isAgent) ...[
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
                      editable: !isAgent && !isReadOnly,
                      onEdit: _editSchedule,
                      onCancel: _cancelSchedule,
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
              vds.showVisitDetail(context, _apiClient, visit);
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

  /// Edit pipeline business fields. The sheet is a self-contained StatefulWidget
  /// (not an inline StatefulBuilder) so its MediaQuery/controllers tear down
  /// cleanly; the save happens here, after the sheet route is fully popped.
  Future<void> _showEditPipelineSheet(PipelineDetailModel p) async {
    final result = await showModalBottomSheet<_EditPipelineResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _EditPipelineSheet(
          initial: p, brokers: _brokers, cascade: _cascade, kerjaSama: _kerjaSamaOptions),
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _pipelineRepo.updatePipeline(p.id, result.toBody());
      if (!mounted) return;
      _fetchData(silent: true);
      messenger.showSnackBar(const SnackBar(content: Text('Pipeline diperbarui')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  /// Schedule a future visit. Self-contained sheet (see _showEditPipelineSheet
  /// note); inline required-field validation lives inside the sheet (J2).
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
          policyEnd: result.policyEnd);
      if (!mounted) return;
      _fetchData(silent: true);
      messenger.showSnackBar(const SnackBar(content: Text('Status pipeline diperbarui')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

}

// ===========================================================================
//  Bottom-sheet widgets — each is its own StatefulWidget (not an inline
//  StatefulBuilder) so route teardown disposes their MediaQuery/controllers
//  cleanly. They return their result via Navigator.pop; the caller performs
//  the network call afterwards (avoids the `_dependents.isEmpty` assertion).
// ===========================================================================

/// Result of [_EditPipelineSheet].
class _EditPipelineResult {
  final String sourceType;
  final String? refId;
  final String? product;
  final String? projectName;
  final String? statusKerjaSama;
  final String? cobName;
  final String? lobName;
  final String? tocCode;
  final String? tocName;
  final double? tsiIdr;
  final double? ratePremi;
  final DateTime? closing;

  _EditPipelineResult({
    required this.sourceType,
    this.refId,
    this.product,
    this.projectName,
    this.statusKerjaSama,
    this.cobName,
    this.lobName,
    this.tocCode,
    this.tocName,
    this.tsiIdr,
    this.ratePremi,
    this.closing,
  });

  Map<String, dynamic> toBody() {
    final body = <String, dynamic>{'sourceType': sourceType};
    body['refId'] = refId; // null clears the link for non-broker sources
    if (projectName != null) body['projectName'] = projectName;
    if (statusKerjaSama != null) body['statusKerjaSama'] = statusKerjaSama;
    // When a ToC is chosen, send the full cascade; product (card title) follows tocName.
    if (tocCode != null) {
      body['cobName'] = cobName;
      body['lobName'] = lobName;
      body['tocCode'] = tocCode;
      body['tocName'] = tocName;
    } else if (product != null && product!.isNotEmpty) {
      body['product'] = product;
    }
    if (tsiIdr != null) body['tsiIdr'] = tsiIdr;
    if (ratePremi != null) body['ratePremi'] = ratePremi;
    if (closing != null) body['closingEstimasi'] = closing!.toIso8601String();
    return body;
  }
}

class _EditPipelineSheet extends StatefulWidget {
  final PipelineDetailModel initial;
  final List<BrokerModel> brokers;
  final ProductCascade cascade;
  final List<ParamRef> kerjaSama;
  const _EditPipelineSheet(
      {required this.initial, required this.brokers, required this.cascade, required this.kerjaSama});

  @override
  State<_EditPipelineSheet> createState() => _EditPipelineSheetState();
}

class _EditPipelineSheetState extends State<_EditPipelineSheet> {
  static const _sources = {
    'DIRECT': 'Direct',
    'AGENT': 'Agen',
    'BROKER': 'Broker',
    'BANCASSURANCE': 'Bancassurance',
    'TPM': 'TPM'
  };

  late final TextEditingController _tsiCtrl;
  late final TextEditingController _productCtrl;
  late final TextEditingController _rateCtrl;
  late final TextEditingController _projectCtrl;
  late String _sourceType;
  String? _brokerId;
  String? _statusKerjaSama;
  String? _cob;
  String? _lob;
  String? _tocCode;
  String? _tocName;
  DateTime? _closing;

  bool get _hasProducts => widget.cascade.all.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _tsiCtrl = TextEditingController(text: p.tsiIdr > 0 ? AppFormat.thousands(p.tsiIdr.round()) : '');
    _productCtrl = TextEditingController(text: p.product ?? '');
    _rateCtrl = TextEditingController(text: p.ratePremi != null ? _trimNum(p.ratePremi!) : '');
    _projectCtrl = TextEditingController(text: p.projectName ?? '');
    _sourceType = p.sourceType ?? 'DIRECT';
    if (_sourceType == 'BROKER' && p.refId != null && widget.brokers.any((b) => b.id == p.refId)) {
      _brokerId = p.refId;
    }
    _statusKerjaSama = p.statusKerjaSama;
    // Preselect cascade from current values if they exist in the product list.
    _cob = (p.cobName != null && widget.cascade.cobs.contains(p.cobName)) ? p.cobName : null;
    if (_cob != null && p.lobName != null && widget.cascade.lobs(_cob!).contains(p.lobName)) {
      _lob = p.lobName;
    }
    if (_cob != null && _lob != null && p.tocCode != null) {
      final match = widget.cascade.tocs(_cob!, _lob!).where((t) => t.tocCode == p.tocCode);
      if (match.isNotEmpty) {
        _tocCode = match.first.tocCode;
        _tocName = match.first.tocName;
      }
    }
    _closing = p.closingEstimasi != null ? DateTime.tryParse(p.closingEstimasi!) : null;
  }

  static String _trimNum(double v) {
    var s = v.toStringAsFixed(4);
    if (s.contains('.')) s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return s;
  }

  @override
  void dispose() {
    _tsiCtrl.dispose();
    _productCtrl.dispose();
    _rateCtrl.dispose();
    _projectCtrl.dispose();
    super.dispose();
  }

  // Estimasi premi tidak disimpan — backend menghitung ulang dari tsiIdr ×
  // ratePremi saat read. Parsing di sini harus sama dengan _save() agar angka
  // yang dipratinjau sama dengan yang tersimpan.
  double get _tsiInput {
    final digits = _tsiCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? 0 : double.parse(digits);
  }

  double get _rateInput =>
      double.tryParse(_rateCtrl.text.trim().replaceAll(',', '.')) ?? 0;

  double get _estimasiPremiIdr => _tsiInput * (_rateInput / 100);

  void _save() {
    final tsiDigits = _tsiCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final result = _EditPipelineResult(
      sourceType: _sourceType,
      refId: _sourceType == 'BROKER' ? _brokerId : null,
      product: _productCtrl.text.trim().isEmpty ? null : _productCtrl.text.trim(),
      projectName: _projectCtrl.text.trim(),
      statusKerjaSama: _statusKerjaSama,
      cobName: _cob,
      lobName: _lob,
      tocCode: _tocCode,
      tocName: _tocName,
      tsiIdr: tsiDigits.isEmpty ? null : double.parse(tsiDigits),
      ratePremi: double.tryParse(_rateCtrl.text.trim().replaceAll(',', '.')),
      closing: _closing,
    );
    Navigator.of(context).pop(result);
  }

  Widget _estimasiPremiBox() {
    final v = _estimasiPremiIdr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Estimasi Premi (IDR)',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Container(
          height: 44,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.grayBg,
            borderRadius: AppRadius.radiusMd,
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            v > 0 ? 'Rp ${AppFormat.thousands(v.round())}' : 'Auto kalkulasi dari TSI × rate / 100',
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final closingLabel = _closing == null ? 'Pilih tanggal' : AppFormat.dateOnly(_closing);
    return Padding(
      padding: EdgeInsets.only(
          left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Pipeline',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              // Lihat catatan pada dropdown Status Kerja Sama di bawah.
              initialValue: _sources.containsKey(_sourceType) ? _sourceType : null,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                  labelText: 'Sumber Bisnis',
                  labelStyle: const TextStyle(fontSize: 13),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: AppRadius.radiusMd)),
              items: _sources.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 14))))
                  .toList(),
              onChanged: (v) => setState(() {
                _sourceType = v ?? 'DIRECT';
                if (_sourceType != 'BROKER') _brokerId = null;
              }),
            ),
            if (_sourceType == 'BROKER') ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _brokerId,
                isExpanded: true,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                    labelText: 'Broker',
                    labelStyle: const TextStyle(fontSize: 13),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: AppRadius.radiusMd)),
                items: widget.brokers
                    .map((b) => DropdownMenuItem(
                        value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))))
                    .toList(),
                onChanged: (v) => setState(() => _brokerId = v),
              ),
              if (widget.brokers.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Daftar broker belum termuat',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _projectCtrl,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                  labelText: 'Nama Proyek',
                  labelStyle: const TextStyle(fontSize: 13),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: AppRadius.radiusMd)),
            ),
            if (widget.kerjaSama.isNotEmpty) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: widget.kerjaSama.any((k) => k.key == _statusKerjaSama) ? _statusKerjaSama : null,
                isExpanded: true,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                    labelText: 'Status Kerja Sama',
                    labelStyle: const TextStyle(fontSize: 13),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: AppRadius.radiusMd)),
                items: widget.kerjaSama
                    .map((k) => DropdownMenuItem(value: k.key, child: Text(k.value, style: const TextStyle(fontSize: 14))))
                    .toList(),
                onChanged: (v) => setState(() => _statusKerjaSama = v),
              ),
            ],
            const SizedBox(height: 10),
            if (_hasProducts) ...[
              DropdownButtonFormField<String>(
                initialValue: _cob,
                isExpanded: true,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                    labelText: 'COB',
                    labelStyle: const TextStyle(fontSize: 13),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: AppRadius.radiusMd)),
                items: widget.cascade.cobs
                    .map((c) => DropdownMenuItem(
                        value: c, child: Text(c, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))))
                    .toList(),
                onChanged: (v) => setState(() {
                  _cob = v;
                  _lob = null;
                  _tocCode = null;
                  _tocName = null;
                }),
              ),
              if (_cob != null) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _lob,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                      labelText: 'LOB',
                      labelStyle: const TextStyle(fontSize: 13),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: AppRadius.radiusMd)),
                  items: widget.cascade.lobs(_cob!)
                      .map((l) => DropdownMenuItem(
                          value: l, child: Text(l, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _lob = v;
                    _tocCode = null;
                    _tocName = null;
                  }),
                ),
              ],
              if (_cob != null && _lob != null) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _tocCode,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                      labelText: 'ToC (judul card)',
                      labelStyle: const TextStyle(fontSize: 13),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: AppRadius.radiusMd)),
                  items: widget.cascade.tocs(_cob!, _lob!)
                      .map((t) => DropdownMenuItem(
                          value: t.tocCode,
                          child: Text(t.tocName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _tocCode = v;
                    final m = widget.cascade.tocs(_cob!, _lob!).where((t) => t.tocCode == v);
                    _tocName = m.isNotEmpty ? m.first.tocName : null;
                  }),
                ),
              ],
            ] else
              TextField(
                controller: _productCtrl,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                    labelText: 'Produk',
                    labelStyle: const TextStyle(fontSize: 13),
                    hintText: 'mis. Asuransi Kredit Bank',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.grayStage),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: AppRadius.radiusMd)),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _tsiCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsInputFormatter()],
              style: const TextStyle(fontSize: 14),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                  labelText: 'TSI/Plafond Nilai Jaminan',
                  labelStyle: const TextStyle(fontSize: 13),
                  prefixText: 'Rp ',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: AppRadius.radiusMd)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _rateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 14),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                  labelText: 'Rate Premi',
                  labelStyle: const TextStyle(fontSize: 13),
                  hintText: 'mis. 2,5',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.grayStage),
                  suffixText: '%',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: AppRadius.radiusMd)),
            ),
            const SizedBox(height: 10),
            _estimasiPremiBox(),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _closing ?? now,
                  firstDate: now.subtract(const Duration(days: 365)),
                  lastDate: now.add(const Duration(days: 365 * 3)),
                );
                if (picked != null) setState(() => _closing = picked);
              },
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text('Est. Closing: $closingLabel'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg)),
                child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
  _StatusResult(this.subStage,
      {this.realisasiIdr, this.cancelReason, this.policyNumber, this.policyStart, this.policyEnd});
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
      if (p.isNotEmpty) policyNumber = p;
    }
    // Polis baru sah bila masa berlakunya ikut dicatat: server menerbitkan baris
    // polis (dasar pencatatan premi & pelepasan komisi agen) hanya bila lengkap.
    if (policyNumber != null && (_policyStart == null || _policyEnd == null)) {
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
        policyEnd: policyNumber == null ? null : _isoDate(_policyEnd!)));
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Satu isian tanggal periode polis. Rentangnya dilebarkan sampai 5 tahun ke
  /// depan/belakang karena polis bisa terbit mundur maupun berlaku multi-tahun.
  Widget _policyDateField(String label, DateTime? value, ValueChanged<DateTime> onPicked) {
    return InkWell(
      borderRadius: AppRadius.radiusMd,
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
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12),
          isDense: true,
          border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        child: Text(value == null ? 'Pilih tanggal' : _isoDate(value),
            style: TextStyle(
                fontSize: 14,
                color: value == null ? AppColors.grayStage : AppColors.textPrimary)),
      ),
    );
  }

  /// Dialog konfirmasi saat nilai realisasi WON beda dari nilai awal.
  Future<bool?> _confirmRealisasiChanged(double baseline, double entered) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
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
              backgroundColor: AppColors.primaryNavy,
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
      padding: EdgeInsets.only(
          left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_selectedBucket != null)
                InkWell(
                  onTap: () => setState(() {
                    _selectedBucket = null;
                    _selected = null;
                    _showErrors = false;
                  }),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.arrow_back, size: 20, color: AppColors.textSecondary),
                  ),
                ),
              const Text('Ubah Status Pipeline',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _selectedBucket == null
                ? 'Langkah 1 — pilih tahap pipeline'
                : 'Langkah 2 — pilih detail di ${PipelineStages.bucketLabel[_selectedBucket]}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: _selectedBucket == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final bucket in PipelineStages.byBucket.keys)
                          InkWell(
                            onTap: () => setState(() {
                              _selectedBucket = bucket;
                              final subs = PipelineStages.byBucket[bucket]!;
                              _selected = subs.length == 1 ? subs.first.value : null;
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      PipelineStages.bucketLabel[bucket] ?? bucket,
                                      style: const TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, size: 18, color: AppColors.grayStage),
                                ],
                              ),
                            ),
                          ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final sub in PipelineStages.byBucket[_selectedBucket]!)
                          InkWell(
                            onTap: () => setState(() => _selected = sub.value),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Icon(
                                    _selected == sub.value
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                    size: 20,
                                    color: _selected == sub.value ? AppColors.primaryNavy : AppColors.grayStage,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(sub.label,
                                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          if (isWon) ...[
            const SizedBox(height: 12),
            const Text('Nilai Premi (wajib)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            TextField(
              controller: _realisasiCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsInputFormatter()],
              onChanged: (_) {
                if (_showErrors) setState(() {});
              },
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                hintText: 'mis. 500.000.000',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.grayStage),
                isDense: true,
                border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                errorText: _showErrors && _realisasiCtrl.text.replaceAll(RegExp(r'[^0-9]'), '').isEmpty
                    ? 'Nilai realisasi wajib diisi saat Won'
                    : null,
                errorStyle: const TextStyle(fontSize: 11, color: AppColors.errorRed),
              ),
            ),
            const SizedBox(height: 12),
            const Text('No. Polis',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            TextField(
              controller: _policyCtrl,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'mis. 101.2026.0001',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.grayStage),
                isDense: true,
                border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Periode Polis',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _policyDateField('Mulai', _policyStart, (d) => setState(() => _policyStart = d))),
              const SizedBox(width: 8),
              Expanded(child: _policyDateField('Selesai', _policyEnd, (d) => setState(() => _policyEnd = d))),
            ]),
            if (_showErrors && _policyCtrl.text.trim().isNotEmpty && (_policyStart == null || _policyEnd == null))
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Periode polis wajib diisi bila No. Polis diisi',
                    style: TextStyle(fontSize: 12, color: AppColors.errorRed)),
              ),
          ],
          if (isDecline) ...[
            const SizedBox(height: 12),
            const Text('Alasan (wajib)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            TextField(
              controller: _reasonCtrl,
              maxLines: 2,
              onChanged: (_) {
                if (_showErrors) setState(() {});
              },
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'mis. Decline dari UW / customer membatalkan',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.grayStage),
                isDense: true,
                border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                errorText: _showErrors && _reasonCtrl.text.trim().isEmpty ? 'Alasan wajib diisi' : null,
                errorStyle: const TextStyle(fontSize: 11, color: AppColors.errorRed),
              ),
            ),
          ],
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
    );
  }
}
