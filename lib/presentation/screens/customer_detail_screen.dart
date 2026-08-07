import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../providers/customer_detail_provider.dart';
import '../../theme/app_theme.dart';
import '../../src/nav.dart';
import '../../src/customer/customer_repository.dart';
import '../../src/pipeline/pipeline_repository.dart';
import '../../src/visit/visit_repository.dart';
import '../../src/assistant/assistant_repository.dart';
import '../widgets/ai_result_view.dart';
import '../widgets/visit_detail_sheet.dart' deferred as vds;
import 'assistant_screen.dart';
import '../../src/app.dart';
import '../../src/network/api_client.dart';
import '../../src/network/auth_image.dart';
import '../../src/common/file_opener.dart';
import '../../utils/responsive.dart';
import 'add_customer_screen.dart';
import 'add_pipeline_screen.dart';
import '../widgets/customer_detail/customer_bumn_hierarchy.dart';
import '../widgets/customer_detail/customer_ownership_card.dart';
import '../widgets/customer_detail/customer_identity_section.dart';
import '../widgets/customer_detail/customer_stat_card.dart';
import '../widgets/customer_detail/customer_ai_card.dart';
import '../widgets/customer_detail/pipeline_card.dart';
import '../widgets/customer_detail/customer_doc_card.dart';
import '../widgets/customer_detail/customer_empty_doc_slot.dart';
import '../widgets/customer_detail/customer_visit_card.dart';
import '../widgets/customer_detail/customer_kontak_tab.dart';
import '../widgets/customer_detail/customer_detail_tab_item.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen>
    with RouteAware {
  // UI-ephemeral (tetap di widget): tab aktif murni navigasi tampilan.
  String _activeTab = 'ringkasan'; // 'ringkasan' or 'kontak'

  // State DATA/LOADING dikelola CustomerDetailNotifier. Getter berikut memproksinya
  // agar seluruh kode build/widget di bawah tetap memakai nama lama tanpa diubah.
  CustomerDetailState get _ds => ref.read(customerDetailProvider);
  CustomerDetailNotifier get _notifier =>
      ref.read(customerDetailProvider.notifier);

  bool get _isLoading => _ds.isLoading;
  String? get _error => _ds.error;
  CustomerDetailModel? get _customer => _ds.customer;
  List<PipelineListModel> get _pipelines => _ds.pipelines;
  List<SavedAiResult> get _aiResults => _ds.aiResults;
  List<VisitModel> get _visits => _ds.visits;
  bool get _visitsAllTime => _ds.visitsAllTime;
  bool get _visitsLoading => _ds.visitsLoading;

  // Repo/ApiClient untuk aksi-tulis & preview dokumen yang tetap di widget
  // (upload/replace/delete dokumen, edit customer, buka dokumen, kartu visit).
  // Dari shared provider — bukan konstruksi ApiClient sendiri.
  ApiClient get _apiClient => ref.read(apiClientProvider);
  CustomerRepository get _customerRepo => ref.read(customerRepoProvider);

  @override
  void initState() {
    super.initState();
    // Bootstrap notifier setelah frame pertama (samakan timing lama). Repo kini
    // dibaca notifier dari shared provider — tak perlu susun ApiClient di sini.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start(widget.customerId);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) MbisApp.routeObserver.subscribe(this, route);
  }

  /// Returned from the pipeline detail (status/edits may have changed) — refresh.
  @override
  void didPopNext() => _fetchData(silent: true);

  @override
  void dispose() {
    MbisApp.routeObserver.unsubscribe(this);
    super.dispose();
  }

  // Fetch data → delegasi ke CustomerDetailNotifier (logika dipindah utuh).
  Future<void> _fetchData({bool silent = false}) =>
      _notifier.fetchData(silent: silent);

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(customerDetailProvider);
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer Detail')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer Detail')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? 'Customer tidak ditemukan'),
              ElevatedButton(onPressed: _fetchData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final customer = _customer!;
    final pipelines = _pipelines;

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
          'Detail Customer',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Hanya pembuat / RM pemegang yang boleh mengubah. Flag-nya dari
          // server (`canEdit`) supaya tombol dan gerbang otorisasi memakai
          // aturan yang SAMA — atasan & admin boleh melihat, tidak menyunting.
          if (customer.canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              tooltip: 'Edit Customer',
              onPressed: () => _openEditCustomer(_customer!),
            ),
          // Hapus permanen: ADMIN saja. Server memakai gerbang yang sama
          // (isCustomerOwner mengecualikan ADMIN), jadi tombol dan otorisasi
          // tidak bisa berbeda pendapat.
          if ((MbisApp.of(context)?.session?.user.roles ?? const [])
              .contains('ADMIN'))
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Hapus Customer',
              onPressed: () => _confirmDeleteCustomer(customer),
            ),
        ],
      ),
      body: Column(
        children: [
          // Navy Customer Info Box
          Container(
            color: AppColors.primaryNavy,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Building Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: AppRadius.radiusLg,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.business,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Name & NPWP
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${customer.legalEntity ?? '-'} • ${customer.entityCategory ?? '-'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          // BUMN position: a level badge for this customer itself,
                          // then its ancestors stated explicitly (Induk: …, Anak: …).
                          if (customer.isBumn &&
                              customer.bumnPath.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            CustomerBumnHierarchy(customer: customer),
                          ],
                          if (customer.isBlacklisted) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.errorRed,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Terindikasi Blacklist',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            'CIF: ${customer.cifNumber ?? '-'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),

          // Tab Bar Selector
          Container(
            color: AppColors.surfaceWhite,
            child: Row(
              children: [
                CustomerDetailTabItem(
                  label: 'Ringkasan',
                  isActive: _activeTab == 'ringkasan',
                  onTap: () {
                    setState(() {
                      _activeTab = 'ringkasan';
                    });
                  },
                ),
                CustomerDetailTabItem(
                  label: 'Dokumen',
                  isActive: _activeTab == 'dokumen',
                  onTap: () {
                    setState(() {
                      _activeTab = 'dokumen';
                    });
                  },
                ),
                CustomerDetailTabItem(
                  label: 'Kontak',
                  isActive: _activeTab == 'kontak',
                  onTap: () {
                    setState(() {
                      _activeTab = 'kontak';
                    });
                  },
                ),
              ],
            ),
          ),

          // Tab Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              // Cap + centre the content on wide screens so it reads as a desktop
              // layout instead of stretching every card edge-to-edge.
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.isWide(context)
                        ? Responsive.contentMaxWidthFor(context)
                        : double.infinity,
                  ),
                  child: _activeTab == 'ringkasan'
                      ? _buildRingkasanTab(customer, pipelines)
                      : _activeTab == 'dokumen'
                      ? _buildDokumenTab(customer)
                      : CustomerKontakTab(customer: customer),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Reloads just the visit list when the period toggle flips, so switching to
  /// the full history doesn't re-fetch the whole customer.
  Future<void> _reloadVisits({required bool allTime}) =>
      _notifier.reloadVisits(allTime: allTime);

  /// Riwayat kunjungan lintas seluruh pipeline customer ini. Visible to whoever
  /// can open the customer — so a Pinca/BM reviews their branch's activity here,
  /// not just per-pipeline. Includes non-GPS visits (CALL/ONLINE/ADMIN), which
  /// the supervisory Peta Visit drops for lack of coordinates.
  Widget _buildVisitHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Expanded: pada layar sempit / skala teks besar, judul + aksi bisa
            // melebihi lebar baris dan memicu overflow.
            const Expanded(
              child: Text(
                'Riwayat Kunjungan',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (!_visitsAllTime)
              InkWell(
                onTap: _visitsLoading
                    ? null
                    : () => _reloadVisits(allTime: true),
                child: const Text(
                  'Lihat semua',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondaryOrange,
                  ),
                ),
              )
            else
              InkWell(
                onTap: _visitsLoading
                    ? null
                    : () => _reloadVisits(allTime: false),
                child: const Text(
                  'Tahun ini saja',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondaryOrange,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _visitsAllTime ? 'Seluruh riwayat' : 'Tahun berjalan',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        if (_visitsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_visits.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: AppRadius.radiusLg,
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(
                _visitsAllTime
                    ? 'Belum ada kunjungan'
                    : 'Belum ada kunjungan tahun ini',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          for (final v in _visits)
            CustomerVisitCard(
              visit: v,
              onTap: () async {
                await vds.loadLibrary();
                if (!mounted) return;
                // Kunjungan bisa diedit dari sheet-nya; muat ulang agar kartu
                // riwayat menampilkan hasilnya.
                final changed = await vds.showVisitDetail(context, _apiClient, v);
                if (changed && mounted) await _fetchData(silent: true);
              },
            ),
      ],
    );
  }

  Widget _buildRingkasanTab(
    CustomerDetailModel customer,
    List<PipelineListModel> pipelines,
  ) {
    // Won hanya menghitung pipeline milik customer ini (kerja sama dihitung 1x
    // di customer pemilik, bukan di mitra).
    int wonCount = pipelines
        .where((p) => p.stage == 'WON' && p.customerId == widget.customerId)
        .length;
    // Only field roles create pipelines. Supervisors (ADMIN/RO/BM/KUP) oversee
    // and never author pipelines, so they don't see the "Tambah Pipeline" button.
    final roles = MbisApp.of(context)?.session?.user.roles ?? const [];
    // Ketua KUP ikut: ia RM yang merangkap ketua unit, jadi punya portofolio
    // sendiri. Atasan lain (BM/RO) tetap hanya mengawasi.
    final canCreatePipeline = roles.contains('RM') ||
        roles.contains('AGENT') ||
        roles.contains('KUP');
    final aiRoles = MbisApp.of(context)?.session?.user.roles ?? const [];
    return Column(
      children: [
        CustomerOwnershipCard(customer: customer),
        const SizedBox(height: 16),
        CustomerIdentitySection(
          customer: customer,
          npwpDisplay: _formatNpwpDisplay(customer.npwp),
        ),
        CustomerAiCard(
          canRun: aiRoles.contains('RM'),
          results: _aiResults,
          onRun: _openAssistant,
          onResultTap: _showSavedResult,
        ),
        // Stat Cards Grid — compact fixed-height cards. All four in one row on
        // wide screens (4 cols); 2 cols on phones. mainAxisExtent keeps them small
        // instead of growing tall with the cell width.
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: Responsive.isWide(context) ? 4 : 2,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            mainAxisExtent: 66,
          ),
          children: [
            CustomerStatCard(
              label: 'Pipeline P3',
              value: '${customer.p3Count}',
              color: AppColors.grayStage,
            ),
            CustomerStatCard(
              label: 'Pipeline P2',
              value: '${customer.p2Count}',
              color: AppColors.secondaryOrange,
            ),
            CustomerStatCard(
              label: 'Pipeline P1',
              value: '${customer.p1Count}',
              color: AppColors.primaryNavy,
            ),
            CustomerStatCard(
              label: 'Won',
              value: '$wonCount',
              color: AppColors.successGreen,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Tambah Pipeline Dashed Button — field roles only (RM/agent).
        if (canCreatePipeline)
          GestureDetector(
            onTap: () async {
              final added = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddPipelineScreen(
                    customerId: widget.customerId,
                    customerName: customer.name,
                    customerLegalEntity: customer.legalEntity,
                  ),
                ),
              );
              if (added == true) {
                _fetchData();
              }
            },
            child: CustomPaint(
              painter: DashedRectPainter(
                color: AppColors.primaryNavy,
                strokeWidth: 1.5,
                gap: 4.0,
              ),
              child: Container(
                width: double.infinity,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.navyBg,
                  borderRadius: AppRadius.radiusMd,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 16, color: AppColors.primaryNavy),
                    SizedBox(width: 8),
                    Text(
                      'Tambah Pipeline',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),

        // Pipelines List
        pipelines.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: AppRadius.radiusLg,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Text(
                    'Belum ada pipeline',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            : Responsive.isWide(context)
            ? _buildPipelineTwoColumn(pipelines)
            : Column(children: pipelines.map((p) => _pipelineCard(p)).toList()),

        const SizedBox(height: 20),
        _buildVisitHistorySection(),
      ],
    );
  }

  /// Opens the AI Assistant for this customer (preselected), then refreshes the
  /// stored-profile card on return (a freshly generated profile shows up).
  Future<void> _openAssistant() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssistantScreen(
          customerId: widget.customerId,
          customerName: _customer?.name,
        ),
      ),
    );
    if (mounted) _fetchData(silent: true);
  }

  void _showSavedResult(SavedAiResult r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.activityName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  children: [
                    AiResultView(result: r.result, sources: r.sources),
                    if ((r.generatedAt ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Disimpan: ${r.generatedAt!.replaceFirst('T', ' ').split('.').first}'
                        '${r.model != null ? ' • ${r.model}' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.grayStage,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Desktop/tablet: pipelines in two columns so more fit per screen. Cards vary
  /// in height (COB/LOB/kerja-sama/realisasi rows), so pair them into Rows rather
  /// than a fixed-extent grid to avoid overflow.
  Widget _buildPipelineTwoColumn(List<PipelineListModel> pipelines) {
    final rows = <Widget>[];
    for (int i = 0; i < pipelines.length; i += 2) {
      final left = pipelines[i];
      final right = (i + 1 < pipelines.length) ? pipelines[i + 1] : null;
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _pipelineCard(left)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: right != null
                  ? _pipelineCard(right)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }
    return Column(children: rows);
  }

  /// Builds a pipeline card, keeping the nested-route navigation (goRel) in the
  /// screen while the card itself is a pure presentational widget.
  Widget _pipelineCard(PipelineListModel p) => PipelineCard(
    pipeline: p,
    currentCustomerId: widget.customerId,
    // Nested under this customer (/customer/:id/pipeline/:pid) so the
    // pipeline gets a refresh-survivable URL and back returns here; the
    // list refreshes on return via didPopNext.
    onTap: () => goRel(context, '/pipeline/${p.id}'),
  );

  /// Format NPWP 15 digit ke XX.XXX.XXX.X-XXX.XXX untuk tampilan; kalau bukan
  /// 15 digit, tampilkan apa adanya.
  String? _formatNpwpDisplay(String? npwp) {
    if (npwp == null) return null;
    final d = npwp.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length != 15) return npwp;
    final buf = StringBuffer();
    for (int i = 0; i < d.length; i++) {
      if (i == 2 || i == 5 || i == 8 || i == 12) {
        buf.write('.');
      } else if (i == 9) {
        buf.write('-');
      }
      buf.write(d[i]);
    }
    return buf.toString();
  }

  static const List<String> _docTypes = ['NPWP', 'NIB', 'NIK/KTP PIC'];

  Widget _buildDokumenTab(CustomerDetailModel customer) {
    return Column(
      children: _docTypes.map((type) {
        CustomerDocumentModel? found;
        for (final d in customer.documents) {
          if (d.docType == type) {
            found = d;
            break;
          }
        }
        if (found != null) {
          final doc = found;
          return CustomerDocCard(
            doc: doc,
            apiClient: _apiClient,
            onView: () => _openDocument(doc),
            onReplace: () => _replaceDocument(doc.docType),
            onDelete: () => _confirmDeleteDocument(doc),
          );
        }
        return CustomerEmptyDocSlot(
          docType: type,
          onTap: () => _replaceDocument(type),
        );
      }).toList(),
    );
  }

  Future<void> _replaceDocument(String docType) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null ||
        result.files.isEmpty ||
        result.files.first.bytes == null) {
      return;
    }
    if (!mounted) return;
    final file = result.files.first;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _customerRepo.uploadDocument(
        widget.customerId,
        docType,
        file.bytes!,
        file.name,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('Dokumen $docType disimpan.'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      await _fetchData();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan dokumen: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _confirmDeleteDocument(CustomerDocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
        scrollable: true,
        title: const Text('Hapus Dokumen'),
        content: Text('Hapus dokumen ${doc.docType} (${doc.fileName})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: AppColors.errorRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _customerRepo.deleteDocument(widget.customerId, doc.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Dokumen ${doc.docType} dihapus.'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      await _fetchData();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus dokumen: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Future<void> _openDocument(CustomerDocumentModel doc) async {
    if (doc.isImage) {
      // Inline fullscreen preview (works on every platform).
      showDialog(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(12),
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              InteractiveViewer(
                child: Center(
                  child: AuthImage(
                    apiClient: _apiClient,
                    path: doc.fileUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    // PDF / other: open the tab NOW, synchronously inside this tap handler, then
    // fill it after fetching the bytes. Safari/iOS blocks window.open() called
    // after an await (no longer a user gesture) — which is why this worked in
    // Chrome but not on iPhone. openPendingTab() is a no-op (null) off the web.
    final messenger = ScaffoldMessenger.of(context);
    final pending = openPendingTab();
    try {
      final res = await _apiClient.get(doc.fileUrl);
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final mime = res.headers['content-type'] ?? 'application/octet-stream';
      // Web: fills the pre-opened tab with a blob. Native: writes a temp file and
      // launches the OS viewer (PDF reader, etc.). Returns false if nothing handled it.
      final opened = await openBytes(
        res.bodyBytes,
        mime,
        doc.fileName,
        pending: pending,
      );
      if (!opened) {
        closePendingTab(pending);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Tidak ada aplikasi untuk membuka "${doc.fileName}".',
            ),
          ),
        );
      }
    } catch (e) {
      closePendingTab(pending);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal membuka dokumen: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  /// Buka formulir customer dalam mode edit.
  ///
  /// Memakai [AddCustomerScreen] yang sama dengan alur tambah, menggantikan sheet
  /// lama yang hanya memuat identitas & PIC — badan hukum, entitas, kategori
  /// bank/BUMN, HVC, dan titik lokasi dulu tidak pernah bisa diperbaiki setelah
  /// customer tersimpan. Penyimpanan dikerjakan layar itu sendiri; di sini tinggal
  /// memuat ulang detailnya.
  /// Konfirmasi hapus customer (ADMIN).
  ///
  /// Menyebut jumlah pipeline-nya karena itu yang menentukan besarnya akibat:
  /// menghapus customer berpipeline menghapus jejak kerja RM, bukan sekadar satu
  /// baris nama.
  Future<void> _confirmDeleteCustomer(CustomerDetailModel c) async {
    // Hanya pipeline AKTIF yang dihitung di model ini (P3/P2/P1); WON/DECLINE
    // tidak ikut, jadi angkanya disebut apa adanya sebagai "pipeline aktif".
    final jumlahPipeline = c.p3Count + c.p2Count + c.p1Count;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Hapus customer ini?'),
        content: Text(
          'Customer "${c.name}" akan dihapus permanen.'
          '${jumlahPipeline > 0 ? '\n\nIa masih punya $jumlahPipeline pipeline aktif. '
              'Hapus atau pindahkan pipeline itu lebih dulu bila datanya masih '
              'dipakai — penghapusan ini tidak bisa dibatalkan.' : '\n\nTindakan ini tidak bisa dibatalkan.'}',
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
      await _customerRepo.deleteCustomer(c.id);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('Customer dihapus'),
        backgroundColor: AppColors.successGreen,
      ));
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.errorRed,
      ));
    }
  }

  Future<void> _openEditCustomer(CustomerDetailModel c) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddCustomerScreen(existing: c)),
    );
    if (saved == true && mounted) await _fetchData(silent: true);
  }

}
