import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../providers/export_my_visits_provider.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/max_width_body.dart';

/// RM "Ekspor Kunjungan Saya" — unduh Excel data kunjungan milik RM yang login
/// saja, untuk rentang tanggal pilihan (item 11, after-piloting feedback).
/// Format sama dengan export admin (/api/admin/export/visits), tapi endpoint
/// (/api/export/visits/me) menggerbang datanya ke kunjungan RM itu sendiri.
class ExportMyVisitsScreen extends ConsumerStatefulWidget {
  const ExportMyVisitsScreen({super.key});

  @override
  ConsumerState<ExportMyVisitsScreen> createState() =>
      _ExportMyVisitsScreenState();
}

class _ExportMyVisitsScreenState extends ConsumerState<ExportMyVisitsScreen> {
  // Rentang tanggal pilihan tetap UI-ephemeral (di widget). Flag async
  // `exporting` dikelola ExportMyVisitsNotifier; getter di bawah memproksinya
  // agar kode build/widget tetap memakai nama lama `_busy` tanpa diubah.
  late DateTime _from;
  late DateTime _to;

  bool get _busy => ref.read(exportMyVisitsProvider).exporting;
  ExportMyVisitsNotifier get _notifier =>
      ref.read(exportMyVisitsProvider.notifier);

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
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_to.isBefore(_from)) _from = _to;
      }
    });
  }

  Future<void> _download() async {
    final result = await _notifier.download(_from, _to);
    if (mounted) _snack(result.message, error: result.error);
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
    // Berlangganan flag async → rebuild otomatis saat berubah (ganti setState).
    ref.watch(exportMyVisitsProvider);
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: 'Ekspor Kunjungan Saya', showBack: true),
      body: MaxWidthBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg, topInset + AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
          children: [
            const Text(
              'Unduh data kunjungan Anda sendiri sebagai file Excel untuk rentang '
              'tanggal terpilih',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildRangeCard(),
            const SizedBox(height: AppSpacing.lg),
            _buildDownloadCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeCard() {
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
              Expanded(child: _dateField('Dari', _from, () => _pickDate(true))),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _dateField('Sampai', _to, () => _pickDate(false))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime value, VoidCallback onTap) {
    return InkWell(
      onTap: _busy ? null : onTap,
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

  Widget _buildDownloadCard() {
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
            child: const Icon(Icons.place_outlined, size: 26, color: AppColors.primaryNavy),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Data Kunjungan (Visit) Saya',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                const Text(
                    'Aktivitas kunjungan Anda: pipeline, GPS, foto, deskripsi, dan '
                    'rencana follow up. Difilter berdasarkan tanggal aktivitas.',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5)),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _download,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download_outlined, size: 18),
                    label: Text(_busy ? 'Mengekspor...' : 'Unduh Excel'),
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
