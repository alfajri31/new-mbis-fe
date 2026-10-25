import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import 'visit_rm_models.dart';
import 'visit_rm_detail_screen.dart';
import 'models/visit_monitor_models.dart';
import 'providers/visit_monitor_provider.dart';
import 'widget/visit_rm_metrics_row.dart';
import 'widget/visit_rm_idle_card.dart';
import 'widget/visit_rm_filter_card.dart';
import 'widget/visit_item_card.dart';

class VisitRmScreen extends ConsumerStatefulWidget {
  const VisitRmScreen({super.key});

  @override
  ConsumerState<VisitRmScreen> createState() => _VisitRmScreenState();
}

class _VisitRmScreenState extends ConsumerState<VisitRmScreen> {
  // Prototype reference date: 2026-09-23
  static const String _todayStr = '2026-09-23';
  static const String _yesterdayStr = '2026-09-22';

  // Current user role: RM
  static const String _activeRole = 'rm';

  // Filter state
  String _quickPeriod = '30'; // 'today', '7', '30', 'month', 'custom'
  String _customDari = '2026-08-25';
  String _customSampai = '2026-09-23';
  String _selectedWil = '';
  String _selectedCab = '';
  String _selectedRm = '';
  String _selectedStage = '';
  String _selectedKat = '';
  String _selectedEnt = '';
  String _selectedHvc = '';
  String _selectedSumber = '';
  String _selectedCob = '';
  String _selectedLob = '';
  String _selectedToc = '';
  String _searchQuery = '';
  bool _showFilter = false;
  bool _showIdle = false;

  // View mode: 'list' (Per Kunjungan) or 'rm' (Per RM)
  String _viewMode = 'list';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    VisitReviewStore.instance.addListener(_onReviewStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchApiData();
    });
  }

  @override
  void dispose() {
    VisitReviewStore.instance.removeListener(_onReviewStoreChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onReviewStoreChanged() {
    if (mounted) setState(() {});
  }

  static const List<Map<String, String>> _quickPeriodOptions = [
    {'id': 'today', 'label': 'Hari ini'},
    {'id': '7', 'label': '7 hari'},
    {'id': '30', 'label': '30 hari'},
    {'id': 'month', 'label': 'Bulan ini'},
    {'id': 'custom', 'label': 'Pilih rentang'},
  ];

  String get _scopeText {
    if (_activeRole == 'rm') return 'Visit saya · Mohammad Ridwan Majid';
    if (_activeRole == 'pinca') return 'Kabag / Pinca · KC Padang';
    if (_activeRole == 'pinwil') return 'Kanwil 1 · Padang, Pekanbaru, Medan';
    return 'Kantor Pusat · semua Kanwil / KC';
  }

  List<String> get _scopedBranches {
    if (_activeRole == 'rm' || _activeRole == 'pinca') return ['Padang'];
    if (_activeRole == 'pinwil') return kDefaultKanwils[0].cab;
    if (_selectedWil.isNotEmpty) {
      final k = kDefaultKanwils.firstWhere(
        (kw) => kw.id == _selectedWil,
        orElse: () => kDefaultKanwils[0],
      );
      return k.cab;
    }
    return kDefaultKanwils.expand((k) => k.cab).toList();
  }

  // Date range calculation
  (String, String) _getDateRange() {
    switch (_quickPeriod) {
      case 'today':
        return (_todayStr, _todayStr);
      case '7':
        return ('2026-09-17', _todayStr);
      case '30':
        return ('2026-08-25', _todayStr);
      case 'month':
        return ('2026-09-01', _todayStr);
      case 'custom':
        return (_customDari, _customSampai);
      default:
        return ('2026-08-25', _todayStr);
    }
  }

  int get _filterBadgeCount {
    int count = 0;
    if (_quickPeriod != '30') count++;
    if (_activeRole == 'admin' && _selectedWil.isNotEmpty) count++;
    if (_activeRole != 'pinca' && _activeRole != 'rm' && _selectedCab.isNotEmpty) count++;
    if (_activeRole != 'rm' && _selectedRm.isNotEmpty) count++;
    if (_selectedStage.isNotEmpty) count++;
    if (_selectedKat.isNotEmpty) count++;
    if (_selectedEnt.isNotEmpty) count++;
    if (_selectedHvc.isNotEmpty) count++;
    if (_selectedSumber.isNotEmpty) count++;
    if (_selectedCob.isNotEmpty) count++;
    if (_selectedLob.isNotEmpty) count++;
    if (_selectedToc.isNotEmpty) count++;
    return count;
  }

  void _fetchApiData() {
    final (startDate, endDate) = _getDateRange();
    final isRmOrPinca = _activeRole == 'rm' || _activeRole == 'pinca';
    final filter = VisitMonitorFilter(
      from: startDate,
      to: endDate,
      regionId: _selectedWil.isNotEmpty ? _selectedWil : null,
      branchId: isRmOrPinca ? 'Padang' : (_selectedCab.isNotEmpty ? _selectedCab : null),
      rmId: _activeRole == 'rm' ? 'r1' : (_selectedRm.isNotEmpty ? _selectedRm : null),
      stage: _selectedStage.isNotEmpty ? _selectedStage : null,
      category: _selectedKat.isNotEmpty ? _selectedKat : null,
      bumn: _selectedEnt == 'BUMN' ? true : (_selectedEnt == 'Non BUMN' ? false : null),
      hvc: _selectedHvc == 'hvc' ? true : (_selectedHvc == 'non' ? false : null),
      sourceType: _selectedSumber.isNotEmpty ? _selectedSumber : null,
      cob: _selectedCob.isNotEmpty ? _selectedCob : null,
      lob: _selectedLob.isNotEmpty ? _selectedLob : null,
      toc: _selectedToc.isNotEmpty ? _selectedToc : null,
      q: _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
    );
    ref.read(visitMonitorProvider.notifier).loadAll(initialFilter: filter);
  }

  void _resetFilters() {
    setState(() {
      _quickPeriod = '30';
      _customDari = '2026-08-25';
      _customSampai = '2026-09-23';
      _selectedWil = '';
      _selectedCab = '';
      _selectedRm = '';
      _selectedStage = '';
      _selectedKat = '';
      _selectedEnt = '';
      _selectedHvc = '';
      _selectedSumber = '';
      _selectedCob = '';
      _selectedLob = '';
      _selectedToc = '';
      _searchQuery = '';
      _searchController.clear();
      _showIdle = false;
    });
    _fetchApiData();
  }



  @override
  Widget build(BuildContext context) {
    final branchesInScope = _scopedBranches;
    final isRmOrPinca = _activeRole == 'rm' || _activeRole == 'pinca';

    // Branches filtered by dropdown (if selected)
    final effectiveBranches = isRmOrPinca
        ? ['Padang']
        : (_selectedCab.isNotEmpty && branchesInScope.contains(_selectedCab)
            ? [_selectedCab]
            : branchesInScope);

    // RMs in current branch scope
    final rmsInBranchScope = kDefaultRms.where((r) {
      if (!effectiveBranches.contains(r.cab)) return false;
      if (_activeRole == 'rm') return r.nama == 'Mohammad Ridwan Majid';
      return true;
    }).toList();

    // Date range
    final (startDate, endDate) = _getDateRange();

    final vmState = ref.watch(visitMonitorProvider);

    // List visits directly from API
    final List<VisitModel> displayedVisits =
        vmState.visitsPage.content.map((row) => row.toVisitModel()).toList();

    // Group visits by date
    final dateGroups = <String, List<VisitModel>>{};
    for (final v in displayedVisits) {
      dateGroups.putIfAbsent(v.tanggal, () => []).add(v);
    }

    // Idle RMs directly from API
    final List<RmModel> idleRms = vmState.rmsPage.content
        .where((r) => r.visitCount == 0)
        .map((r) => r.toRmModel())
        .toList();

    // Metrics directly from API summary
    final totalVisit = vmState.summary.totalVisit;
    final activeRmCount = vmState.summary.rmActive;
    final idleRmCount = vmState.summary.rmIdle;
    final avgPerRm = vmState.summary.avgPerRm.toStringAsFixed(1).replaceAll('.', ',');
    final reviewedCount = vmState.summary.reviewedCount;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: AppColors.bgScreen,
        appBar: _buildAppBar(context, vmState, displayedVisits.length),
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search bar and Filter toggle button
                _buildSearchAndFilterBar(),
                const SizedBox(height: 12),

                // Expandable Filter card
                if (_showFilter) ...[
                  VisitRmFilterCard(
                    quickPeriod: _quickPeriod,
                    onQuickPeriodChanged: (val) {
                      setState(() => _quickPeriod = val);
                      _fetchApiData();
                    },
                    quickPeriodOptions: _quickPeriodOptions,
                    customDari: _customDari,
                    onCustomDariChanged: (val) {
                      setState(() => _customDari = val);
                      _fetchApiData();
                    },
                    customSampai: _customSampai,
                    onCustomSampaiChanged: (val) {
                      setState(() => _customSampai = val);
                      _fetchApiData();
                    },
                    activeRole: _activeRole,
                    selectedWil: _selectedWil,
                    onSelectedWilChanged: (val) {
                      setState(() {
                        _selectedWil = val ?? '';
                        _selectedCab = '';
                        _selectedRm = '';
                      });
                      _fetchApiData();
                    },
                    selectedCab: _selectedCab,
                    onSelectedCabChanged: (val) {
                      setState(() {
                        _selectedCab = val ?? '';
                        _selectedRm = '';
                      });
                      _fetchApiData();
                    },
                    selectedRm: _selectedRm,
                    onSelectedRmChanged: (val) {
                      setState(() => _selectedRm = val ?? '');
                      _fetchApiData();
                    },
                    selectedStage: _selectedStage,
                    onSelectedStageChanged: (val) {
                      setState(() => _selectedStage = val ?? '');
                      _fetchApiData();
                    },
                    selectedKat: _selectedKat,
                    onSelectedKatChanged: (val) {
                      setState(() => _selectedKat = val ?? '');
                      _fetchApiData();
                    },
                    selectedEnt: _selectedEnt,
                    onSelectedEntChanged: (val) {
                      setState(() => _selectedEnt = val ?? '');
                      _fetchApiData();
                    },
                    selectedHvc: _selectedHvc,
                    onSelectedHvcChanged: (val) {
                      setState(() => _selectedHvc = val ?? '');
                      _fetchApiData();
                    },
                    selectedSumber: _selectedSumber,
                    onSelectedSumberChanged: (val) {
                      setState(() => _selectedSumber = val ?? '');
                      _fetchApiData();
                    },
                    selectedCob: _selectedCob,
                    onSelectedCobChanged: (val) {
                      setState(() {
                        _selectedCob = val ?? '';
                        _selectedLob = '';
                        _selectedToc = '';
                      });
                      _fetchApiData();
                    },
                    selectedLob: _selectedLob,
                    onSelectedLobChanged: (val) {
                      setState(() {
                        _selectedLob = val ?? '';
                        _selectedToc = '';
                      });
                      _fetchApiData();
                    },
                    selectedToc: _selectedToc,
                    onSelectedTocChanged: (val) {
                      setState(() => _selectedToc = val ?? '');
                      _fetchApiData();
                    },
                    branchesInScope: branchesInScope,
                    rmsInBranchScope: rmsInBranchScope,
                    onReset: _resetFilters,
                    onClose: () => setState(() => _showFilter = false),
                  ),
                  const SizedBox(height: 12),
                ],

                // Active filter chips row
                _buildActiveFilterChips(startDate, endDate),
                const SizedBox(height: 12),

                // 4 Metrics cards
                VisitRmMetricsRow(
                  total: totalVisit,
                  activeRm: activeRmCount,
                  idleRm: idleRmCount,
                  avg: avgPerRm,
                  isLoading: vmState.isLoadingSummary,
                  error: vmState.summaryError,
                  onRetry: () => ref.read(visitMonitorProvider.notifier).loadSummary(),
                  onToggleIdle: () => setState(() => _showIdle = !_showIdle),
                ),
                const SizedBox(height: 12),

                // Expandable Idle RM list
                if (_showIdle) ...[
                  VisitRmIdleCard(idleRms: idleRms),
                  const SizedBox(height: 12),
                ],

                // View Tab toggle ("Per Kunjungan" vs "Per RM")
                _buildViewTabs(reviewedCount),
                const SizedBox(height: 14),

                // Main content list
                _viewMode == 'list'
                    ? _buildVisitList(vmState, dateGroups)
                    : _buildRmList(vmState),

              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- AppBar ---
  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    VisitMonitorState vmState,
    int exportCount,
  ) {
    return AppBar(
      backgroundColor: AppColors.surfaceWhite,
      surfaceTintColor: AppColors.transparent,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AppColors.borderDivider, height: 1),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textDark),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            final path = GoRouterState.of(context).uri.path;
            if (path.startsWith('/kelola/tools')) {
              context.go('/kelola/tools');
            } else {
              context.go('/tools');
            }
          }
        },
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Visit RM',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          Text(
            _scopeText,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: OutlinedButton.icon(
            onPressed: vmState.isExporting
                ? null
                : () async {
                    final (startDate, endDate) = _getDateRange();
                    final outcome = await ref
                        .read(visitMonitorProvider.notifier)
                        .exportVisits(from: startDate, to: endDate);

                    if (!context.mounted) return;

                    if (outcome.ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Berhasil mengunduh ${outcome.fileName}'),
                              ),
                            ],
                          ),
                          backgroundColor: AppColors.navyMbis,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else if (outcome.unsupported) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Perangkat tidak mendukung penyimpanan langsung berkas.'),
                          backgroundColor: AppColors.alertTitle,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Gagal mengekspor: ${outcome.error ?? "Terjadi kesalahan"}'),
                          backgroundColor: AppColors.alertTitle,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
            icon: vmState.isExporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.greenTotal,
                    ),
                  )
                : const Icon(Icons.file_download_outlined, size: 18, color: AppColors.greenTotal),
            label: Text(
              vmState.isExporting ? 'Mengunduh...' : 'Excel',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.greenTotal,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.borderDefault, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: AppColors.surfaceWhite,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 38),
            ),
          ),
        ),
      ],
    );
  }




  // --- Search & Filter button bar ---
  Widget _buildSearchAndFilterBar() {
    final badgeCount = _filterBadgeCount;
    return Row(
      children: [
        // Search textfield
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderDefault, width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                const Icon(Icons.search, size: 18, color: AppColors.iconDropdown),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    onSubmitted: (_) => _fetchApiData(),
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                    decoration: const InputDecoration(
                      hintText: 'Cari perusahaan atau nama RM',
                      hintStyle: TextStyle(fontSize: 14, color: AppColors.hintText),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                      _fetchApiData();
                    },
                    child: const Icon(Icons.close, size: 16, color: AppColors.iconDropdown),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Filter button
        OutlinedButton.icon(
          onPressed: () {
            FocusScope.of(context).unfocus();
            setState(() => _showFilter = !_showFilter);
          },
          icon: const Icon(Icons.filter_list, size: 18, color: AppColors.navyMbis),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Filter',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navyMbis,
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.orangeMbis,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.surfaceWhite,
                    ),
                  ),
                ),
              ],
            ],
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.navyMbis, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: AppColors.surfaceWhite,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            minimumSize: const Size(0, 44),
          ),
        ),
      ],
    );
  }

  // --- Active filter chips ---
  Widget _buildActiveFilterChips(String startDate, String endDate) {
    final chips = <String>[];

    // Period label
    if (_quickPeriod == 'custom') {
      chips.add('${VisitRmHelpers.formatIndoDate(startDate)} – ${VisitRmHelpers.formatIndoDate(endDate)}');
    } else {
      final opt = _quickPeriodOptions.firstWhere((o) => o['id'] == _quickPeriod);
      chips.add('${opt['label']} (${VisitRmHelpers.formatIndoDate(startDate)} – ${VisitRmHelpers.formatIndoDate(endDate)})');
    }

    // Wilayah chip
    if (_activeRole == 'admin' && _selectedWil.isNotEmpty) {
      final kw = kDefaultKanwils.firstWhere((k) => k.id == _selectedWil, orElse: () => kDefaultKanwils[0]);
      chips.add(kw.name);
    }

    // Cabang chip
    if (_selectedCab.isNotEmpty && _activeRole != 'pinca' && _activeRole != 'rm') {
      chips.add('KC $_selectedCab');
    }

    // RM chip
    if (_selectedRm.isNotEmpty && _activeRole != 'rm') {
      final r = kDefaultRms.firstWhere((rm) => rm.id == _selectedRm, orElse: () => const RmModel(id: '', nama: '', jab: '', cab: ''));
      chips.add(r.nama);
    }

    // Stage chip
    if (_selectedStage.isNotEmpty) {
      final info = VisitRmHelpers.getStageInfo(_selectedStage);
      chips.add('Stage ${info.label}');
    }

    if (_selectedKat.isNotEmpty) chips.add(_selectedKat);
    if (_selectedEnt.isNotEmpty) chips.add(_selectedEnt);
    if (_selectedHvc.isNotEmpty) chips.add(_selectedHvc == 'hvc' ? 'HVC' : 'Non HVC');
    if (_selectedSumber.isNotEmpty) chips.add(_selectedSumber);
    if (_selectedCob.isNotEmpty) chips.add(_selectedCob);
    if (_selectedLob.isNotEmpty) chips.add(_selectedLob);
    if (_selectedToc.isNotEmpty) chips.add(_selectedToc);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips.map((t) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.blueLightBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            t,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.navyMbis,
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- View tabs (Per Kunjungan vs Per RM) ---
  Widget _buildViewTabs(int reviewedCount) {
    return Row(
      children: [
        _buildViewTabButton('list', 'Per Kunjungan'),
        const SizedBox(width: 6),
        _buildViewTabButton('rm', 'Per RM'),
        const Spacer(),
        Text(
          '$reviewedCount ditinjau',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildViewTabButton(String mode, String label) {
    final isSelected = _viewMode == mode;
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navyMbis : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? AppColors.navyMbis : AppColors.borderDefault,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? AppColors.surfaceWhite : AppColors.textDark,
          ),
        ),
      ),
    );
  }

  // --- Visit List (Per Kunjungan) ---
  Widget _buildVisitList(
    VisitMonitorState vmState,
    Map<String, List<VisitModel>> dateGroups,
  ) {
    // 1. Loading state (initial loading)
    if (vmState.isLoadingVisits && !vmState.isPaging && dateGroups.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderDivider),
        ),
        child: Column(
          children: const [
            CircularProgressIndicator(color: AppColors.navyMbis, strokeWidth: 2.5),
            SizedBox(height: 14),
            Text(
              'Memuat daftar kunjungan...',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // 2. Negative case: Error state with Retry button
    if (vmState.visitsError != null && dateGroups.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.alertBorder),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 36, color: AppColors.orangeDark),
            const SizedBox(height: 10),
            const Text(
              'Gagal Memuat Kunjungan',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              vmState.visitsError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => _fetchApiData(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navyMbis,
                foregroundColor: AppColors.surfaceWhite,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    // 3. Empty state
    if (dateGroups.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderDivider),
        ),
        child: const Text(
          'Tidak ada kunjungan sesuai filter.',
          style: TextStyle(fontSize: 14, color: AppColors.textMuted),
        ),
      );
    }

    // 4. Data state: List grouped by date + Pagination bar
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...dateGroups.entries.map((entry) {
          final date = entry.key;
          final visits = entry.value;
          final dateHeader = VisitRmHelpers.getDateLabel(date, _todayStr, _yesterdayStr);

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header row
                Padding(
                  padding: const EdgeInsets.only(left: 2, right: 2, bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateHeader,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navyMbis,
                        ),
                      ),
                      Text(
                        '${visits.length} kunjungan',
                        style: const TextStyle(fontSize: 12, color: AppColors.iconDropdown),
                      ),
                    ],
                  ),
                ),
                // Group card
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderDivider),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visits.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.bgDisabled,
                    ),
                    itemBuilder: (context, idx) {
                      final v = visits[idx];
                      final rm = kDefaultRms.firstWhere(
                        (r) => r.id == v.rmId,
                        orElse: () => const RmModel(id: '', nama: '-', jab: '', cab: '-'),
                      );
                      final isReviewed = VisitReviewStore.instance.isReviewed(v.id);

                      return VisitItemCard(
                        visit: v,
                        rm: rm,
                        isReviewed: isReviewed,
                        onTap: () => _openDetail(v),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }),
        _buildPaginationBar(vmState),
      ],
    );
  }

  // --- Pagination Bar ---
  Widget _buildPaginationBar(VisitMonitorState vmState) {
    final page = vmState.visitsPage;
    if (page.totalPages <= 1) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Halaman ${page.page + 1} dari ${page.totalPages} (${page.totalElements} data)',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                onPressed: page.hasPrevious && !vmState.isPaging
                    ? () => ref.read(visitMonitorProvider.notifier).goToPage(page.page - 1)
                    : null,
              ),
              if (vmState.isPaging)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navyMbis),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                onPressed: page.hasNext && !vmState.isPaging
                    ? () => ref.read(visitMonitorProvider.notifier).goToPage(page.page + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }


  // --- RM List (Per RM) ---
  Widget _buildRmList(VisitMonitorState vmState) {
    // 1. Loading state (negative/async handling)
    if (vmState.isInitialLoadingRms) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.navyMbis),
            SizedBox(height: 12),
            Text(
              'Memuat data RM...',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    // 2. Negative case: Error state with retry
    if (vmState.hasRmsError) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.alertBorder),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: AppColors.alertTitle, size: 40),
            const SizedBox(height: 10),
            const Text(
              'Gagal Memuat Data RM',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppColors.textDark),
            ),
            const SizedBox(height: 6),
            Text(
              vmState.rmsError ?? 'Terjadi kesalahan sistem saat memuat data RM',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => ref.read(visitMonitorProvider.notifier).loadRms(page: 0),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navyMbis,
                foregroundColor: AppColors.surfaceWhite,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );
    }

    // 3. API Data available
    if (vmState.rmsPage.content.isNotEmpty) {
      final rows = vmState.rmsPage.content;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderDivider),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.bgDisabled,
              ),
              itemBuilder: (context, idx) {
                final rmRow = rows[idx];
                final count = rmRow.visitCount;
                final hasVisits = count > 0;
                final lastText = hasVisits && rmRow.lastVisitAt != null
                    ? 'Terakhir: ${VisitRmHelpers.formatDateTime(rmRow.lastVisitAt!)} · ${rmRow.lastCustomerName ?? '-'}'
                    : (hasVisits && rmRow.lastCustomerName != null
                        ? 'Terakhir: ${rmRow.lastCustomerName}'
                        : 'Belum ada visit pada periode ini');

                return InkWell(
                  onTap: () {
                    // Filter by this RM and switch to Per Kunjungan
                    setState(() {
                      _selectedRm = rmRow.rmId;
                      _viewMode = 'list';
                    });
                    _fetchApiData();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        // Badge with count
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: hasVisits ? AppColors.blueLightBg : AppColors.badgeP2Bg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                  color: hasVisits ? AppColors.navyMbis : AppColors.alertTitle,
                                ),
                              ),
                              Text(
                                'visit',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: hasVisits ? AppColors.navyMbis : AppColors.alertTitle,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // RM info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rmRow.rmName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Text(
                                '${rmRow.jabatan ?? "RM Bisnis"} · ${rmRow.officeName ?? ""}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                lastText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textLabel,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Reviewed count
                        if (hasVisits)
                          Text(
                            '${rmRow.reviewedCount}/$count ditinjau',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.greenTotal,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Pagination for RM list
          _buildRmPaginationBar(vmState),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Ketuk nama RM untuk melihat daftar kunjungannya.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        ],
      );
    }

    // 4. Empty state (sesuai prototype)
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: const Text(
        'Tidak ada kunjungan sesuai filter.',
        style: TextStyle(fontSize: 14, color: AppColors.textMuted),
      ),
    );
  }

  // --- RM Pagination Bar ---
  Widget _buildRmPaginationBar(VisitMonitorState vmState) {
    final page = vmState.rmsPage;
    if (page.totalPages <= 1) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Halaman ${page.page + 1} dari ${page.totalPages} (${page.totalElements} RM)',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                onPressed: page.hasPrevious && !vmState.isPagingRms
                    ? () => ref.read(visitMonitorProvider.notifier).goToRmsPage(page.page - 1)
                    : null,
              ),
              if (vmState.isPagingRms)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navyMbis),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                onPressed: page.hasNext && !vmState.isPagingRms
                    ? () => ref.read(visitMonitorProvider.notifier).goToRmsPage(page.page + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }


  // --- Detail Screen Navigation ---
  void _openDetail(VisitModel v) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VisitRmDetailScreen(
          visitId: v.id,
          activeRoleLabel: 'RM',
        ),
      ),
    );
  }
}
