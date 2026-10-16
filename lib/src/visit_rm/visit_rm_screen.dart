import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import 'visit_rm_models.dart';
import 'visit_rm_detail_screen.dart';

class VisitRmScreen extends StatefulWidget {
  const VisitRmScreen({super.key});

  @override
  State<VisitRmScreen> createState() => _VisitRmScreenState();
}

class _VisitRmScreenState extends State<VisitRmScreen> {
  // Prototype reference date: 2026-09-23
  static const String _todayStr = '2026-09-23';
  static const String _yesterdayStr = '2026-09-22';

  // Role simulator: 'pinca', 'pinwil', 'admin'
  String _activeRole = 'pinca';

  // Filter state
  String _quickPeriod = '30'; // 'today', '7', '30', 'month', 'custom'
  String _customDari = '2026-08-25';
  String _customSampai = '2026-09-23';
  String _selectedWil = '';
  String _selectedCab = '';
  String _selectedRm = '';
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

  // --- Role simulation options ---
  static const List<Map<String, String>> _roleOptions = [
    {'id': 'pinca', 'label': 'Pinca KC Padang'},
    {'id': 'pinwil', 'label': 'Pinwil Kanwil 1'},
    {'id': 'admin', 'label': 'Admin'},
  ];

  static const List<Map<String, String>> _quickPeriodOptions = [
    {'id': 'today', 'label': 'Hari ini'},
    {'id': '7', 'label': '7 hari'},
    {'id': '30', 'label': '30 hari'},
    {'id': 'month', 'label': 'Bulan ini'},
    {'id': 'custom', 'label': 'Pilih rentang'},
  ];

  String get _activeRoleLabel {
    return _roleOptions.firstWhere((r) => r['id'] == _activeRole)['label']!;
  }

  String get _scopeText {
    if (_activeRole == 'pinca') return 'KC Padang';
    if (_activeRole == 'pinwil') return 'Kanwil 1 · Padang, Pekanbaru, Medan';
    return 'Semua Kanwil / KC';
  }

  List<String> get _scopedBranches {
    if (_activeRole == 'pinca') return ['Padang'];
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
    if (_activeRole != 'pinca' && _selectedCab.isNotEmpty) count++;
    if (_selectedRm.isNotEmpty) count++;
    return count;
  }

  void _resetFilters() {
    setState(() {
      _quickPeriod = '30';
      _customDari = '2026-08-25';
      _customSampai = '2026-09-23';
      _selectedWil = '';
      _selectedCab = '';
      _selectedRm = '';
      _searchQuery = '';
      _searchController.clear();
      _showIdle = false;
    });
  }

  void _onRoleChanged(String roleId) {
    setState(() {
      _activeRole = roleId;
      _selectedWil = '';
      _selectedCab = roleId == 'pinca' ? 'Padang' : '';
      _selectedRm = '';
      _showIdle = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final branchesInScope = _scopedBranches;

    // Branches filtered by dropdown (if selected)
    final effectiveBranches = _activeRole == 'pinca'
        ? ['Padang']
        : (_selectedCab.isNotEmpty && branchesInScope.contains(_selectedCab)
            ? [_selectedCab]
            : branchesInScope);

    // RMs in current branch scope
    final rmsInBranchScope = kDefaultRms
        .where((r) => effectiveBranches.contains(r.cab))
        .toList();

    // RMs filtered by specific RM dropdown
    final effectiveRms = _selectedRm.isNotEmpty
        ? rmsInBranchScope.where((r) => r.id == _selectedRm).toList()
        : rmsInBranchScope;

    final effectiveRmIds = effectiveRms.map((r) => r.id).toSet();

    // Date range
    final (startDate, endDate) = _getDateRange();

    // Filtered visits
    final inPeriodVisits = kDefaultVisits.where((v) {
      if (!effectiveRmIds.contains(v.rmId)) return false;
      return v.tanggal.compareTo(startDate) >= 0 && v.tanggal.compareTo(endDate) <= 0;
    }).toList();

    // Search query filter
    final q = _searchQuery.trim().toLowerCase();
    final filteredVisits = inPeriodVisits.where((v) {
      if (q.isEmpty) return true;
      final rm = kDefaultRms.firstWhere((r) => r.id == v.rmId, orElse: () => const RmModel(id: '', nama: '', jab: '', cab: ''));
      return v.perusahaan.toLowerCase().contains(q) || rm.nama.toLowerCase().contains(q);
    }).toList();

    // Sort newest date & time first
    filteredVisits.sort((a, b) => (b.tanggal + b.jam).compareTo(a.tanggal + a.jam));

    // Calculate metrics
    final totalVisit = inPeriodVisits.length;
    final activeRmIds = inPeriodVisits.map((v) => v.rmId).toSet();
    final idleRms = effectiveRms.where((r) => !activeRmIds.contains(r.id)).toList();
    final activeRmCount = effectiveRms.length - idleRms.length;
    final avgPerRm = effectiveRms.isNotEmpty
        ? (totalVisit / effectiveRms.length).toStringAsFixed(1).replaceAll('.', ',')
        : '0';

    // Group visits by date
    final dateGroups = <String, List<VisitModel>>{};
    for (final v in filteredVisits) {
      dateGroups.putIfAbsent(v.tanggal, () => []).add(v);
    }

    // Total reviewed count
    final reviewedCount = inPeriodVisits.where((v) => VisitReviewStore.instance.isReviewed(v.id)).length;

    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: _buildAppBar(context, filteredVisits.length),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Prototype role simulator banner
              _buildRoleSimulatorBanner(),
              const SizedBox(height: 12),

              // Search bar and Filter toggle button
              _buildSearchAndFilterBar(),
              const SizedBox(height: 12),

              // Expandable Filter card
              if (_showFilter) ...[
                _buildFilterCard(branchesInScope, rmsInBranchScope),
                const SizedBox(height: 12),
              ],

              // Active filter chips row
              _buildActiveFilterChips(startDate, endDate),
              const SizedBox(height: 12),

              // 4 Metrics cards
              _buildMetricsRow(totalVisit, activeRmCount, idleRms.length, avgPerRm),
              const SizedBox(height: 12),

              // Expandable Idle RM list
              if (_showIdle) ...[
                _buildIdleRmCard(idleRms),
                const SizedBox(height: 12),
              ],

              // View Tab toggle ("Per Kunjungan" vs "Per RM")
              _buildViewTabs(reviewedCount),
              const SizedBox(height: 14),

              // Main content list
              _viewMode == 'list'
                  ? _buildVisitList(dateGroups)
                  : _buildRmList(effectiveRms, inPeriodVisits),
            ],
          ),
        ),
      ),
    );
  }

  // --- AppBar ---
  PreferredSizeWidget _buildAppBar(BuildContext context, int exportCount) {
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
            context.go('/kelola');
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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Mengunduh Visit_RM.xlsx ($exportCount kunjungan, sesuai filter)'),
                  backgroundColor: AppColors.navyMbis,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.file_download_outlined, size: 18, color: AppColors.greenTotal),
            label: const Text(
              'Excel',
              style: TextStyle(
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

  // --- Role simulator banner ---
  Widget _buildRoleSimulatorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.alertBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.orangeMbis,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Simulasi login (khusus prototype)',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.alertTitle,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _roleOptions.map((opt) {
              final isSelected = opt['id'] == _activeRole;
              return ChoiceChip(
                label: Text(opt['label']!),
                selected: isSelected,
                onSelected: (val) {
                  if (val) _onRoleChanged(opt['id']!);
                },
                selectedColor: AppColors.navyMbis,
                backgroundColor: AppColors.surfaceWhite,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppColors.surfaceWhite : AppColors.textDark,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(
                    color: isSelected ? AppColors.navyMbis : AppColors.borderDefault,
                    width: 1.5,
                  ),
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              );
            }).toList(),
          ),
        ],
      ),
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
          onPressed: () => setState(() => _showFilter = !_showFilter),
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

  // --- Expandable Filter Card ---
  Widget _buildFilterCard(List<String> branchesInScope, List<RmModel> rmsInBranchScope) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDivider),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Period quick pills
          const Text(
            'Periode kunjungan',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textLabel,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _quickPeriodOptions.map((opt) {
              final isSelected = opt['id'] == _quickPeriod;
              return ChoiceChip(
                label: Text(opt['label']!),
                selected: isSelected,
                onSelected: (val) {
                  if (val) setState(() => _quickPeriod = opt['id']!);
                },
                selectedColor: AppColors.navyMbis,
                backgroundColor: AppColors.surfaceWhite,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppColors.surfaceWhite : AppColors.textDark,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(
                    color: isSelected ? AppColors.navyMbis : AppColors.borderDefault,
                    width: 1.5,
                  ),
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              );
            }).toList(),
          ),

          // Custom date pickers if 'custom'
          if (_quickPeriod == 'custom') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dari', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(height: 4),
                      _buildDateField(
                        value: _customDari,
                        onChanged: (val) => setState(() => _customDari = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sampai', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(height: 4),
                      _buildDateField(
                        value: _customSampai,
                        onChanged: (val) => setState(() => _customSampai = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // Wilayah Dropdown (Admin only)
          if (_activeRole == 'admin') ...[
            const Text(
              'Kantor Wilayah',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textLabel,
              ),
            ),
            const SizedBox(height: 4),
            _buildDropdown<String>(
              value: _selectedWil,
              items: [
                const DropdownMenuItem(value: '', child: Text('Semua Kanwil')),
                ...kDefaultKanwils.map((k) => DropdownMenuItem(value: k.id, child: Text(k.name))),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedWil = val ?? '';
                  _selectedCab = '';
                  _selectedRm = '';
                });
              },
            ),
            const SizedBox(height: 12),
          ],

          // Cabang Dropdown
          const Text(
            'Cabang',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textLabel,
            ),
          ),
          const SizedBox(height: 4),
          _buildDropdown<String>(
            value: _activeRole == 'pinca' ? 'Padang' : _selectedCab,
            enabled: _activeRole != 'pinca',
            items: [
              if (_activeRole != 'pinca')
                const DropdownMenuItem(value: '', child: Text('Semua Cabang')),
              ...branchesInScope.map((c) => DropdownMenuItem(value: c, child: Text('KC $c'))),
            ],
            onChanged: (val) {
              setState(() {
                _selectedCab = val ?? '';
                _selectedRm = '';
              });
            },
          ),
          if (_activeRole == 'pinca') ...[
            const SizedBox(height: 2),
            const Text(
              'Pinca hanya melihat cabangnya sendiri',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 12),

          // RM Dropdown
          const Text(
            'Nama RM',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textLabel,
            ),
          ),
          const SizedBox(height: 4),
          _buildDropdown<String>(
            value: _selectedRm,
            items: [
              const DropdownMenuItem(value: '', child: Text('Semua RM')),
              ...rmsInBranchScope.map((r) => DropdownMenuItem(
                    value: r.id,
                    child: Text('${r.nama} · ${r.cab}'),
                  )),
            ],
            onChanged: (val) => setState(() => _selectedRm = val ?? ''),
          ),
          const SizedBox(height: 16),

          // Action buttons: Reset & Tutup
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    onPressed: _resetFilters,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.borderDefault, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      foregroundColor: AppColors.textLabel,
                    ),
                    child: const Text('Reset', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () => setState(() => _showFilter = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navyMbis,
                      foregroundColor: AppColors.surfaceWhite,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Tutup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault, width: 1.5),
      ),
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () async {
          final parts = value.split('-');
          final initial = parts.length == 3
              ? DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]))
              : DateTime(2026, 9, 23);
          final picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          );
          if (picked != null) {
            final y = picked.year.toString().padLeft(4, '0');
            final m = picked.month.toString().padLeft(2, '0');
            final d = picked.day.toString().padLeft(2, '0');
            onChanged('$y-$m-$d');
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              VisitRmHelpers.formatIndoDate(value),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.iconDropdown),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    bool enabled = true,
  }) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: enabled ? AppColors.surfaceWhite : AppColors.bgDisabled,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.iconDropdown),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: enabled ? AppColors.textDark : AppColors.textDisabled,
          ),
        ),
      ),
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
    if (_selectedCab.isNotEmpty && _activeRole != 'pinca') {
      chips.add('KC $_selectedCab');
    }

    // RM chip
    if (_selectedRm.isNotEmpty) {
      final r = kDefaultRms.firstWhere((rm) => rm.id == _selectedRm, orElse: () => const RmModel(id: '', nama: '', jab: '', cab: ''));
      chips.add(r.nama);
    }

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

  // --- Metrics 4-cards grid ---
  Widget _buildMetricsRow(int total, int activeRm, int idleRm, String avg) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildMetricItem(
              number: '$total',
              label: 'Total Visit',
              numColor: AppColors.navyMbis,
              bgColor: AppColors.surfaceWhite,
              borderColor: AppColors.borderDivider,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricItem(
              number: '$activeRm',
              label: 'RM Aktif',
              numColor: AppColors.navyMbis,
              bgColor: AppColors.surfaceWhite,
              borderColor: AppColors.borderDivider,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricItem(
              number: '$idleRm',
              label: 'RM Belum Visit ›',
              numColor: AppColors.orangeDark,
              bgColor: AppColors.alertBg,
              borderColor: AppColors.alertBorder,
              onTap: () => setState(() => _showIdle = !_showIdle),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricItem(
              number: avg,
              label: 'Rata-rata / RM',
              numColor: AppColors.navyMbis,
              bgColor: AppColors.surfaceWhite,
              borderColor: AppColors.borderDivider,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String number,
    required String label,
    required Color numColor,
    required Color bgColor,
    required Color borderColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                number,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: numColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: onTap != null ? AppColors.alertTitle : AppColors.textMuted,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Expandable Idle RM list card ---
  Widget _buildIdleRmCard(List<RmModel> idleRms) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border.all(color: AppColors.alertBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'RM belum melakukan visit pada periode ini',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.alertTitle,
            ),
          ),
          const SizedBox(height: 8),
          if (idleRms.isEmpty)
            const Text(
              'Semua RM sudah visit.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            )
          else
            ...idleRms.map((rm) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.badgeIdleDivider)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppColors.badgeP2Bg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_outline, size: 18, color: AppColors.alertTitle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rm.nama,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            '${rm.jab} · KC ${rm.cab}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
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
  Widget _buildVisitList(Map<String, List<VisitModel>> dateGroups) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: dateGroups.entries.map((entry) {
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
                    final stageInfo = VisitRmHelpers.getStageInfo(v.stage);
                    final isReviewed = VisitReviewStore.instance.isReviewed(v.id);

                    return InkWell(
                      onTap: () => _openDetail(v),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Avatar circle with camera badge
                            _buildAvatarWithBadge(v),
                            const SizedBox(width: 12),

                            // Company, Time/Cabang, and Badges
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    v.perusahaan,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${v.jam} · KC ${rm.cab}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: stageInfo.bg,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          stageInfo.label,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: stageInfo.fg,
                                          ),
                                        ),
                                      ),
                                      if (isReviewed)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.badgeP1Bg,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            '✓ Ditinjau',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.greenTotal,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // RM name and Pipeline Value
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  rm.nama,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textLabel,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  VisitRmHelpers.formatRupiah(v.nilai),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navyMbis,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                const Text(
                                  'Nilai pipeline',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.iconDropdown,
                                  ),
                                ),
                              ],
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
      }).toList(),
    );
  }

  Widget _buildAvatarWithBadge(VisitModel v) {
    if (!v.foto) {
      return const SizedBox(width: 52, height: 52);
    }
    final initials = VisitRmHelpers.getCompanyInitials(v.perusahaan);
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: VisitRmHelpers.getAvatarGradient(v.id),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.surfaceWhite,
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderDivider),
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                size: 11,
                color: AppColors.navyMbis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- RM List (Per RM) ---
  Widget _buildRmList(List<RmModel> rms, List<VisitModel> inPeriodVisits) {
    // Build rows with visit count
    final rows = rms.map((rm) {
      final visits = inPeriodVisits.where((v) => v.rmId == rm.id).toList();
      visits.sort((a, b) => (b.tanggal + b.jam).compareTo(a.tanggal + a.jam));
      final revCount = visits.where((v) => VisitReviewStore.instance.isReviewed(v.id)).length;
      return (rm: rm, visits: visits, revCount: revCount);
    }).toList();

    rows.sort((a, b) => b.visits.length.compareTo(a.visits.length));

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
              final row = rows[idx];
              final rm = row.rm;
              final count = row.visits.length;
              final hasVisits = count > 0;
              final lastText = hasVisits
                  ? 'Terakhir: ${VisitRmHelpers.formatIndoDate(row.visits.first.tanggal)} · ${row.visits.first.perusahaan}'
                  : 'Belum ada visit pada periode ini';

              return InkWell(
                onTap: () {
                  // Filter by this RM and switch to Per Kunjungan
                  setState(() {
                    _selectedRm = rm.id;
                    _viewMode = 'list';
                  });
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
                              rm.nama,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              '${rm.jab} · KC ${rm.cab}',
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
                          '${row.revCount}/$count ditinjau',
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

  // --- Detail Screen Navigation ---
  void _openDetail(VisitModel v) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VisitRmDetailScreen(
          visitId: v.id,
          activeRoleLabel: _activeRoleLabel,
        ),
      ),
    );
  }
}
