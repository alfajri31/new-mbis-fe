import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/visit_rm/visit_rm_models.dart'
    show KanwilModel, kDefaultKanwils;
import '../../theme/app_theme.dart';
import '../providers/export_data_provider.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/max_width_body.dart';

/// Admin "Ekspor Data" console — unduh Excel report kinerja (customer / pipeline /
/// visit) untuk rentang tanggal dan kantor pilihan. Entry point-nya di hub Kelola; endpoint
/// backend (/api/admin/export/* atau /api/export/*) tetap yang menggerbang aksesnya (ADMIN only).
class ExportDataScreen extends ConsumerStatefulWidget {
  const ExportDataScreen({super.key});

  @override
  ConsumerState<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends ConsumerState<ExportDataScreen> {
  // Rentang tanggal = pilihan UI pengguna → tetap di widget (dengan setState).
  late DateTime _from;
  late DateTime _to;

  // Filter Kantor Wilayah dan Kantor Cabang sesuai prototype baru
  String? _selectedWil;
  String? _selectedCab;

  // Flag async "sedang mengunduh" dikelola ExportDataNotifier. Getter berikut
  // memproksinya agar kode build/widget di bawah tetap memakai nama lama.
  ExportDataNotifier get _notifier => ref.read(exportDataProvider.notifier);
  String? get _busyDataset => ref.read(exportDataProvider).busyDataset;

  bool get _isDateBad => _to.isBefore(_from);

  bool get _hasOffice =>
      (_selectedWil != null && _selectedWil!.isNotEmpty) ||
      (_selectedCab != null && _selectedCab!.isNotEmpty);

  KanwilModel? get _currentKanwil =>
      _selectedWil == null || _selectedWil!.isEmpty
          ? null
          : kDefaultKanwils.where((k) => k.id == _selectedWil).firstOrNull;

  List<String> get _currentCabangList {
    final w = _currentKanwil;
    if (w != null) return w.cab;
    return kDefaultKanwils.expand((k) => k.cab).toList();
  }

  String get _cabHint {
    final w = _currentKanwil;
    if (w != null) {
      return 'Menampilkan ${w.cab.length} kantor cabang di ${w.name}.';
    }
    return 'Pilih kantor wilayah untuk mempersempit daftar cabang.';
  }

  String get _summaryText {
    final dStr = '${_fmt(_from)} – ${_fmt(_to)}';
    final w = _currentKanwil;
    final wn = w != null ? w.name : 'Semua kantor wilayah';
    String cn;
    if (_selectedCab != null && _selectedCab!.isNotEmpty) {
      cn = 'KC $_selectedCab';
    } else if (w != null) {
      cn = 'semua cabang di ${w.name}';
    } else {
      cn = 'semua kantor cabang';
    }
    return '$dStr · $wn · $cn';
  }

  static const _datasets = <_Dataset>[
    _Dataset(
      key: 'customers',
      label: 'Data Customer',
      desc: 'Profil customer: kategori, entitas, HVC, NIB/NPWP, alamat, '
          'lokasi peta, dan kontak PIC. Difilter berdasarkan tanggal dibuat.',
      icon: Icons.people_outline,
      bg: AppColors.navyBg,
    ),
    _Dataset(
      key: 'pipelines',
      label: 'Data Pipeline',
      desc: 'Pipeline per RM & kantor: sumber bisnis, COB/LOB/TOC, estimasi '
          'TSI & premi, rate, proyek, dan tender. Difilter berdasarkan tanggal dibuat.',
      icon: Icons.stacked_line_chart,
      bg: AppColors.greenLight,
    ),
    _Dataset(
      key: 'visits',
      label: 'Data Kunjungan (Visit)',
      desc: 'Aktivitas kunjungan: RM, pipeline, GPS, foto, deskripsi, dan '
          'rencana follow up. Difilter berdasarkan tanggal aktivitas.',
      icon: Icons.place_outlined,
      bg: AppColors.orangeLight,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1); // awal bulan berjalan
    _to = DateTime(now.year, now.month, now.day);
  }

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
      } else {
        _to = picked;
      }
    });
  }

  void _onWilChanged(String? val) {
    setState(() {
      _selectedWil = val;
      if (val != null && val.isNotEmpty) {
        final w = kDefaultKanwils.where((k) => k.id == val).firstOrNull;
        if (w != null && _selectedCab != null && !w.cab.contains(_selectedCab)) {
          _selectedCab = null;
        }
      }
    });
  }

  void _onCabChanged(String? val) {
    setState(() {
      _selectedCab = val;
    });
  }

  void _resetOffice() {
    setState(() {
      _selectedWil = null;
      _selectedCab = null;
    });
  }

  Future<void> _download(_Dataset d) async {
    if (_isDateBad) {
      _snack('Periksa rentang tanggal terlebih dahulu', error: true);
      return;
    }
    final outcome = await _notifier.download(
      d.key,
      _from,
      _to,
      regionId: _selectedWil,
      branchId: _selectedCab,
    );
    if (!mounted) return;
    if (outcome.ok) {
      _snack('${d.label} berhasil diekspor (${outcome.fileName})');
    } else if (outcome.error != null) {
      _snack(outcome.error!, error: true);
    } else {
      _snack('Unduhan tidak didukung di perangkat ini', error: true);
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
    // Berlangganan state notifier → rebuild otomatis saat busy berubah (ganti setState).
    ref.watch(exportDataProvider);
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
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
            const Text(
              'Unduh report kinerja sebagai file Excel untuk rentang tanggal dan kantor terpilih.',
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.45),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildRangeCard(),
            const SizedBox(height: AppSpacing.lg),
            for (final d in _datasets) ...[
              _buildDatasetCard(d),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRangeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E7EF)),
        boxShadow: const [AppShadows.level2],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Rentang Tanggal ──
          const Text(
            'Rentang Tanggal',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _dateField('Dari', _from, () => _pickDate(true), isBad: _isDateBad),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dateField('Sampai', _to, () => _pickDate(false), isBad: _isDateBad),
              ),
            ],
          ),
          if (_isDateBad) ...[
            const SizedBox(height: 6),
            const Text(
              'Tanggal "Sampai" harus sama atau setelah tanggal "Dari".',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFFC8322F),
              ),
            ),
          ],

          const SizedBox(height: 20),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEF1F6)),
          const SizedBox(height: 18),

          // ── 2. Kantor (Wilayah & Cabang) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kantor',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_hasOffice)
                InkWell(
                  onTap: _busyDataset != null ? null : _resetOffice,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      'Reset',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFC25A17),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Dropdown 1: Kantor Wilayah
          _buildOfficeDropdown<String?>(
            label: 'Kantor Wilayah',
            value: _selectedWil,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Semua kantor wilayah'),
              ),
              ...kDefaultKanwils.map(
                (k) => DropdownMenuItem<String?>(
                  value: k.id,
                  child: Text(k.name),
                ),
              ),
            ],
            onChanged: _onWilChanged,
          ),
          const SizedBox(height: 14),

          // Dropdown 2: Kantor Cabang
          _buildOfficeDropdown<String?>(
            label: 'Kantor Cabang',
            value: _selectedCab,
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  _currentKanwil != null
                      ? 'Semua cabang di ${_currentKanwil!.name}'
                      : 'Semua kantor cabang',
                ),
              ),
              ..._currentCabangList.map(
                (c) => DropdownMenuItem<String?>(
                  value: c,
                  child: Text('KC $c'),
                ),
              ),
            ],
            onChanged: _onCabChanged,
          ),
          const SizedBox(height: 6),
          Text(
            _cabHint,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF5A6475),
              height: 1.4,
            ),
          ),

          const SizedBox(height: 18),

          // ── 3. Info Box / Summary ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF4FB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Color(0xFF0E2B53),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'Data yang diunduh: ',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF15223B),
                        height: 1.45,
                      ),
                      children: [
                        TextSpan(
                          text: _summaryText,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
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

  Widget _buildOfficeDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      key: ValueKey('${label}_$value'),
      initialValue: value,
      items: items,
      onChanged: _busyDataset != null ? null : onChanged,
      isExpanded: true,
      icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryNavy),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF5A6475), fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF15223B), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF15223B), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryNavy, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      style: const TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF15223B),
      ),
    );
  }

  Widget _dateField(String label, DateTime value, VoidCallback onTap,
      {bool isBad = false}) {
    final borderColor = isBad ? const Color(0xFFC8322F) : const Color(0xFF15223B);
    return InkWell(
      onTap: _busyDataset != null ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isBad ? const Color(0xFFC8322F) : const Color(0xFF5A6475),
            fontSize: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isBad ? const Color(0xFFC8322F) : AppColors.primaryNavy,
              width: 1.5,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          suffixIcon: Icon(Icons.calendar_today_outlined,
              size: 18, color: isBad ? const Color(0xFFC8322F) : AppColors.primaryNavy),
        ),
        child: Text(_fmt(value),
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: isBad ? const Color(0xFFC8322F) : const Color(0xFF15223B),
            )),
      ),
    );
  }

  Widget _buildDatasetCard(_Dataset d) {
    final busy = _busyDataset == d.key;
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
              color: d.bg,
              borderRadius: AppRadius.radius2Xl,
            ),
            alignment: Alignment.center,
            child: Icon(d.icon, size: 26, color: AppColors.primaryNavy),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.label,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(d.desc,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5)),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: _busyDataset != null ? null : () => _download(d),
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download_outlined, size: 18),
                    label: Text(busy ? 'Mengekspor...' : 'Unduh Excel'),
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

class _Dataset {
  final String key;
  final String label;
  final String desc;
  final IconData icon;
  final Color bg;

  const _Dataset({
    required this.key,
    required this.label,
    required this.desc,
    required this.icon,
    required this.bg,
  });
}
