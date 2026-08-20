import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../src/dashboard/dashboard_repository.dart';
import '../../src/common/file_opener.dart';
import '../../core/providers/repository_providers.dart';
import '../providers/export_provider.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/max_width_body.dart';
import '../widgets/rm_picker_sheet.dart';

/// "Ekspor Data" — unduh Pipeline & Visit sebagai Excel untuk rentang tanggal
/// pilihan. Tersedia untuk semua user; datanya digerbangi server sesuai scope
/// (RM → miliknya, atasan → subtree cabang). Atasan bisa mempersempit dengan
/// filter wilayah/cabang/RM.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  // UI-ephemeral (tetap di widget): rentang tanggal & filter/scope pilihan user.
  late DateTime _from;
  late DateTime _to;
  String? _regionId;
  String? _branchId;
  String? _rmId;
  String? _rmName;

  // State backend/async dikelola ExportNotifier. Getter berikut memproksinya
  // agar seluruh kode build/widget di bawah tetap memakai nama lama tanpa diubah.
  ExportState get _es => ref.read(exportProvider);
  ExportNotifier get _notifier => ref.read(exportProvider.notifier);

  bool get _isSupervisor => _es.isSupervisor;
  String? get _busyDataset => _es.busyDataset; // 'pipelines' | 'visits' | null

  // Supervisor scope options (loaded from /api/dashboard/scope-offices).
  List<ScopeOffice> get _offices => _es.offices;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1); // awal bulan berjalan
    _to = DateTime(now.year, now.month, now.day);
    // Bootstrap notifier setelah frame pertama (samakan timing lama). Sesi &
    // peran supervisor dibaca notifier dari sessionProvider — tak perlu context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start();
    });
  }

  List<ScopeOffice> get _regions =>
      _offices.where((o) => o.type == 'REGIONAL').toList();

  List<ScopeOffice> get _branches => _offices
      .where((o) =>
          o.type == 'BRANCH' && (_regionId == null || o.parentId == _regionId))
      .toList();

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryNavy,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_to.isBefore(_from)) _from = _to;
      }
    });
  }

  Future<void> _openRmPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RmPickerSheet(
        repo: ref.read(dashboardRepoProvider),
        regionId: _regionId,
        branchId: _branchId,
        onSelected: (rm) => setState(() {
          _rmId = rm?.id;
          _rmName = rm?.name;
        }),
      ),
    );
  }

  Future<void> _download(String dataset) async {
    try {
      final f = await _notifier.download(
        dataset,
        from: _from,
        to: _to,
        regionId: _regionId,
        branchId: _branchId,
        rmId: _rmId,
      );
      final ok = await downloadBytes(f.bytes,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', f.fileName);
      if (mounted) {
        _snack(ok
            ? 'Data berhasil diekspor (${f.fileName})'
            : 'Unduhan tidak didukung di perangkat ini', error: !ok);
      }
    } catch (e) {
      if (mounted) _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    } finally {
      _notifier.doneExport();
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.errorRed : AppColors.successGreen,
    ));
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(exportProvider);
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    final busy = _busyDataset != null;
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(
          title: 'Ekspor Data', showBack: true, contentMaxWidth: MaxWidthBody.defaultMaxWidth),
      body: MaxWidthBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg, topInset + AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
          children: [
            Text(
              _isSupervisor
                  ? 'Unduh data Pipeline & Visit sebagai Excel. Data mengikuti '
                      'cakupan Anda; persempit dengan filter wilayah/cabang/RM bila perlu.'
                  : 'Unduh data Pipeline & Visit milik Anda sebagai Excel untuk '
                      'rentang tanggal terpilih.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildRangeCard(busy),
            if (_isSupervisor) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildFilterCard(busy),
            ],
            const SizedBox(height: AppSpacing.lg),
            _buildDownloadCard(
              dataset: 'pipelines',
              title: 'Data Pipeline',
              description:
                  'Seluruh pipeline: RM, sumber bisnis, COB/LOB, TSI/plafond, '
                  'premi, dan status. Difilter berdasarkan tanggal dibuat.',
              icon: Icons.account_tree_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildDownloadCard(
              dataset: 'visits',
              title: 'Data Kunjungan (Visit)',
              description:
                  'Aktivitas kunjungan: pipeline, GPS, foto, deskripsi, dan '
                  'rencana follow up. Difilter berdasarkan tanggal aktivitas.',
              icon: Icons.place_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeCard(bool busy) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radius2Xl,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level2],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rentang Tanggal',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                  child: _dateField(
                      'Dari', _from, busy ? null : () => _pickDate(true))),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                  child: _dateField(
                      'Sampai', _to, busy ? null : () => _pickDate(false))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard(bool busy) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radius2Xl,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level2],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter (opsional)',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.md),
          if (_regions.isNotEmpty || _branches.isNotEmpty)
            Row(
              children: [
                if (_regions.isNotEmpty)
                  Expanded(
                    child: _scopeDropdown(
                      hint: 'Semua wilayah',
                      value: _regionId,
                      options: _regions,
                      onChanged: busy
                          ? null
                          : (v) => setState(() {
                                _regionId = v;
                                _branchId = null;
                                _rmId = null;
                                _rmName = null;
                              }),
                    ),
                  ),
                if (_regions.isNotEmpty && _branches.isNotEmpty)
                  const SizedBox(width: 10),
                if (_branches.isNotEmpty)
                  Expanded(
                    child: _scopeDropdown(
                      hint: 'Semua cabang',
                      value: _branchId,
                      options: _branches,
                      onChanged: busy
                          ? null
                          : (v) => setState(() {
                                _branchId = v;
                                _rmId = null;
                                _rmName = null;
                              }),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          _buildRmPickerField(busy),
        ],
      ),
    );
  }

  Widget _scopeDropdown({
    required String hint,
    required String? value,
    required List<ScopeOffice> options,
    required ValueChanged<String?>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.bgScreen,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: value,
          hint: Text(hint,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis),
          items: [
            DropdownMenuItem<String?>(
                value: null,
                child: Text(hint, style: const TextStyle(fontSize: 13))),
            ...options.map((o) => DropdownMenuItem<String?>(
                  value: o.id,
                  child: Text(o.name,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildRmPickerField(bool busy) {
    final label = _rmName ?? 'Semua RM';
    final selected = _rmId != null;
    return InkWell(
      onTap: busy ? null : _openRmPicker,
      borderRadius: AppRadius.radiusMd,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgScreen,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_search_rounded,
                size: 18, color: AppColors.grayStage),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary)),
            ),
            if (selected)
              GestureDetector(
                onTap: busy
                    ? null
                    : () => setState(() {
                          _rmId = null;
                          _rmName = null;
                        }),
                child: const Icon(Icons.close_rounded,
                    size: 16, color: AppColors.grayStage),
              )
            else
              const Icon(Icons.expand_more_rounded,
                  size: 18, color: AppColors.grayStage),
          ],
        ),
      ),
    );
  }

  Widget _dateField(String label, DateTime value, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.radiusLg,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: AppRadius.radiusLg),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          suffixIcon: const Icon(Icons.calendar_today_outlined,
              size: 18, color: AppColors.primaryNavy),
        ),
        child: Text(_fmt(value),
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
      ),
    );
  }

  Widget _buildDownloadCard({
    required String dataset,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final busyThis = _busyDataset == dataset;
    final busyAny = _busyDataset != null;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radius2Xl,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level2],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.orangeLight,
              borderRadius: AppRadius.radius2Xl,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 26, color: AppColors.primaryNavy),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(description,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5)),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: busyAny ? null : () => _download(dataset),
                    icon: busyThis
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download_outlined, size: 18),
                    label: Text(busyThis ? 'Mengekspor...' : 'Unduh Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.radiusLg),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
