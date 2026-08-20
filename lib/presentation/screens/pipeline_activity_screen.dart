import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../src/nav.dart';
import '../../utils/format.dart';
import '../../utils/schedule_status.dart';
import '../../src/app.dart';
import '../../src/network/api_client.dart';
import '../../src/pipeline/pipeline_repository.dart';
import '../../src/pipeline/pipeline_timeline.dart';
import '../../src/visit/visit_repository.dart';
import '../providers/pipeline_activity_provider.dart';
import '../widgets/max_width_body.dart';
import '../widgets/state_views.dart';
import '../widgets/timeline_entry_card.dart';
// Deferred: the visit-detail sheet renders a mini-map (flutter_map), so it's
// loaded on demand to keep the map library out of the initial bundle.
import '../widgets/visit_detail_sheet.dart' deferred as vds;

/// Full schedule + merged history for a pipeline. Schedules can be filtered by
/// status and marked done; the pipeline detail only shows the open ones. The
/// Riwayat tab merges stage changes, field edits, and visits into one timeline.
class PipelineActivityScreen extends ConsumerStatefulWidget {
  final String pipelineId;

  /// Which tab to open initially: 0 = Jadwal, 1 = Riwayat.
  final int initialTab;
  const PipelineActivityScreen({
    super.key,
    required this.pipelineId,
    this.initialTab = 0,
  });

  @override
  ConsumerState<PipelineActivityScreen> createState() =>
      _PipelineActivityScreenState();
}

class _PipelineActivityScreenState
    extends ConsumerState<PipelineActivityScreen> {
  // UI-only (tetap di widget): ApiClient dipakai sheet detail kunjungan.
  late ApiClient _apiClient;

  // State bisnis/async dikelola PipelineActivityNotifier. Getter berikut
  // memproksinya agar kode build/widget di bawah tetap memakai nama lama.
  PipelineActivityState get _pas => ref.read(pipelineActivityProvider);
  PipelineActivityNotifier get _notifier =>
      ref.read(pipelineActivityProvider.notifier);

  bool get _loading => _pas.loading;
  String? get _error => _pas.error;
  List<PipelineScheduleModel> get _schedules => _pas.schedules;
  List<VisitModel> get _visits => _pas.visits;
  List<PipelineHistoryModel> get _history => _pas.history;
  String get _filter => _pas.filter; // ALL | OPEN | DONE
  bool get _showEdits => _pas.showEdits;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // ApiClient untuk sheet detail kunjungan tetap dibuat dari sesi (UI).
      _apiClient = ApiClient(session: MbisApp.of(context)?.session);
      // Data (repos via provider) diserahkan ke notifier.
      _notifier.start(pipelineId: widget.pipelineId);
    });
  }

  Future<void> _fetch() => _notifier.fetch();

  Future<void> _markDone(PipelineScheduleModel s) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _notifier.markDone(s);
      messenger.showSnackBar(
        const SnackBar(content: Text('Jadwal ditandai selesai')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(pipelineActivityProvider);
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        backgroundColor: AppColors.bgScreen,
        appBar: AppBar(
          backgroundColor: AppColors.primaryNavy,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => safePop(context),
          ),
          title: const Text(
            'Jadwal & Riwayat',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppColors.secondaryOrange,
            tabs: [
              Tab(text: 'Jadwal'),
              Tab(text: 'Riwayat'),
            ],
          ),
        ),
        body: _loading
            ? const SkeletonList(itemCount: 6)
            : _error != null
            ? ErrorStateView(message: _error!, onRetry: _fetch)
            // Tanpa batas lebar, di layar 1920 badge terdampar di ujung kiri dan
            // tanggal di ujung kanan dengan ~1.700 px kosong di antaranya. Dibatasi
            // ke kolom yang sama dengan konsol admin supaya kartunya terbaca.
            : MaxWidthBody(
                child: TabBarView(
                  children: [_buildJadwalTab(), _buildRiwayatTab()],
                ),
              ),
      ),
    );
  }

  Widget _buildJadwalTab() {
    final filtered = _schedules.where((s) {
      if (_filter == 'ALL') return true;
      return s.status.toUpperCase() == _filter;
    }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: Row(
            children: [
              for (final f in const ['ALL', 'OPEN', 'DONE'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      f == 'ALL' ? 'Semua' : (f == 'OPEN' ? 'Open' : 'Selesai'),
                    ),
                    selected: _filter == f,
                    onSelected: (_) => _notifier.setFilter(f),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: _filter == f
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                    selectedColor: AppColors.primaryNavy,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: EmptyStateView(
                    icon: Icons.event_busy,
                    title: 'Tidak ada jadwal',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _scheduleCard(filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _scheduleCard(PipelineScheduleModel s) {
    final isDone = s.status.toUpperCase() == 'DONE';
    // Badge dari helper bersama, sama seperti kartu di detail pipeline. Sebelumnya
    // layar ini menulis status MENTAH ("Open"), sehingga satu jadwal yang sama terbaca
    // "Terlambat" di detail pipeline tetapi "Open" di sini — dua sebutan berbeda untuk
    // baris yang persis sama.
    final badge = pipelineScheduleBadge(status: s.status, isoDate: s.date);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badge.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badge.icon, size: 12, color: badge.color),
                    const SizedBox(width: 4),
                    Text(
                      badge.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badge.color,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.calendar_today,
                size: 13,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                AppFormat.dateOnly(s.date),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.access_time,
                size: 13,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                AppFormat.timeOnly(s.date),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Agenda + aksinya satu baris. Sebelumnya tombol berdiri di barisnya
          // sendiri rata kanan, jadi ia menggantung jauh dari teks yang dirujuknya.
          Row(
            children: [
              Expanded(
                child: Text(
                  s.title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
              if (!isDone) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _markDone(s),
                  icon: const Icon(
                    Icons.check,
                    size: 16,
                    color: AppColors.successGreen,
                  ),
                  label: const Text(
                    'Tandai selesai',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.successGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.successGreen),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiwayatTab() {
    final entries = mergePipelineTimeline(
      history: _history,
      visits: _visits,
      includeEdits: _showEdits,
    );
    // Count from the unfiltered source: the toggle must stay visible (and honest
    // about how many are hidden) precisely when edits are being filtered out.
    final editCount = _history.where((h) => h.isEdit).length;

    return Column(
      children: [
        if (editCount > 0) _buildEditToggle(editCount),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: EmptyStateView(
                    icon: Icons.history,
                    title: _showEdits || editCount == 0
                        ? 'Belum ada riwayat'
                        : 'Hanya ada riwayat perubahan data',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: entries.length,
                  itemBuilder: (_, i) => _entryCard(entries[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildEditToggle(int editCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _showEdits
                  ? 'Menampilkan $editCount perubahan data'
                  : '$editCount perubahan data disembunyikan',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Switch(
            value: _showEdits,
            activeThumbColor: AppColors.primaryNavy,
            onChanged: (v) => _notifier.setShowEdits(v),
          ),
        ],
      ),
    );
  }

  Widget _entryCard(TimelineEntry e) {
    final visit = e.visit;
    return TimelineEntryCard(
      entry: e,
      onTap: visit == null
          ? null
          : () async {
              await vds.loadLibrary();
              if (!mounted) return;
              // Kunjungan bisa diedit dari sheet-nya; muat ulang supaya kartu
              // riwayat & jadwal follow-up ikut menampilkan hasilnya.
              final changed = await vds.showVisitDetail(context, _apiClient, visit);
              if (changed && mounted) await _fetch();
            },
    );
  }
}
