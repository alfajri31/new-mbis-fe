import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../src/nav.dart';
import '../../utils/format.dart';
import '../../src/app.dart';
import '../../core/providers/repository_providers.dart';
import '../../src/dashboard/dashboard_repository.dart';
import '../../src/pipeline/pipeline_repository.dart';
import '../providers/semua_jadwal_provider.dart';
import '../widgets/state_views.dart';

/// Full list of the RM's open schedules (the dashboard shows only the nearest few).
class SemuaJadwalScreen extends ConsumerStatefulWidget {
  const SemuaJadwalScreen({super.key});

  @override
  ConsumerState<SemuaJadwalScreen> createState() => _SemuaJadwalScreenState();
}

class _SemuaJadwalScreenState extends ConsumerState<SemuaJadwalScreen>
    with RouteAware {
  // State bisnis/async dikelola SemuaJadwalNotifier. Getter berikut memproksinya
  // agar seluruh kode build/widget di bawah tetap memakai nama lama tanpa diubah.
  SemuaJadwalState get _ss => ref.read(semuaJadwalProvider);
  SemuaJadwalNotifier get _notifier => ref.read(semuaJadwalProvider.notifier);

  bool get _loading => _ss.loading;
  String? get _error => _ss.error;
  List<DashboardSchedule> get _schedules => _ss.schedules;
  List<DateGroup> get _groups => _ss.groups;
  String? get _selectedDateKey => _ss.selectedDateKey;

  // Repo tulis (edit/batal jadwal) tetap dipakai dari widget karena aksinya
  // berbasis navigasi/sheet/snackbar; ambil dari provider bersama.
  PipelineRepository get _pipelineRepo => ref.read(pipelineRepoProvider);

  @override
  void initState() {
    super.initState();
    // Bootstrap notifier setelah frame pertama (samakan timing lama). Sesi &
    // repo dibaca notifier dari provider bersama — tak perlu context.
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

  /// Refresh when returning from a pushed screen — e.g. after adding a new
  /// schedule in Pipeline Detail, so it shows up here without a manual reload.
  /// Silent so the list stays visible (no skeleton flash) while it refetches.
  @override
  void didPopNext() {
    _fetch(silent: true);
  }

  @override
  void dispose() {
    MbisApp.routeObserver.unsubscribe(this);
    super.dispose();
  }

  // Muat/segarkan data → delegasi ke SemuaJadwalNotifier (logika dipindah utuh).
  Future<void> _fetch({bool silent = false}) => _notifier.fetch(silent: silent);

  // Pilih chip tanggal (client-side filter) → delegasi ke notifier.
  void _selectDate(String? key) => _notifier.selectDate(key);

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(semuaJadwalProvider);
    return Scaffold(
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
          'Semua Jadwal Kunjungan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const SkeletonList(itemCount: 6);
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          ErrorStateView(message: _error!, onRetry: _fetch),
        ],
      );
    }
    if (_schedules.isEmpty) {
      return const Center(
        child: EmptyStateView(
          icon: Icons.calendar_today_outlined,
          title: 'Belum ada jadwal kunjungan',
        ),
      );
    }
    final visibleGroups = _selectedDateKey == null
        ? _groups
        : _groups.where((g) => g.key == _selectedDateKey).toList();
    return Column(
      children: [
        _dateSelector(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetch,
            child: visibleGroups.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 80),
                      EmptyStateView(
                        icon: Icons.event_busy_outlined,
                        title: 'Tidak ada kunjungan di tanggal ini',
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: visibleGroups.length,
                    itemBuilder: (context, i) => _dateSection(visibleGroups[i]),
                  ),
          ),
        ),
      ],
    );
  }

  /// Horizontal strip of selectable dates above the list. "Semua" shows every
  /// date; tapping a date filters the agenda to just that day. Only dates that
  /// actually have visits appear as chips.
  Widget _dateSelector() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        height: 76,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 12,
          ),
          children: [
            _selectorChip(
              selected: _selectedDateKey == null,
              onTap: () => _selectDate(null),
              child: const Center(child: Text('Semua')),
            ),
            for (final g in _groups)
              _selectorChip(
                selected: _selectedDateKey == g.key,
                onTap: () => _selectDate(g.key),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppFormat.weekdayShort(g.date),
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppFormat.dayMonth(g.date),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
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

  Widget _selectorChip({
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    final fg = selected ? Colors.white : AppColors.primaryNavy;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 64,
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryNavy : AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primaryNavy : AppColors.border,
            ),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _dateSection(DateGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dateHeader(group),
        ...group.items.map(_scheduleCard),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _dateHeader(DateGroup group) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Row(
        children: [
          const Icon(
            Icons.event_outlined,
            size: 16,
            color: AppColors.primaryNavy,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              group.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryNavy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${group.items.length} kunjungan',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduleCard(DashboardSchedule item) {
    final isOverdue = (item.status ?? '').toLowerCase() == 'overdue';
    final color = isOverdue ? AppColors.errorRed : AppColors.primaryNavy;
    return GestureDetector(
      onTap: item.pipelineId == null
          ? null
          : () => context.go('/dashboard/pipeline/${item.pipelineId!}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(
            color: isOverdue
                ? AppColors.errorRed.withValues(alpha: 0.25)
                : AppColors.border,
          ),
          boxShadow: const [AppShadows.level1],
        ),
        child: Row(
          children: [
            // Time (jam) shown prominently on the left — the date lives in the
            // section header above, so each card only needs its time.
            Container(
              width: 54,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time, color: color, size: 16),
                  const SizedBox(height: 2),
                  Text(
                    AppFormat.timeOnly(item.scheduleDateTime),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.customerName ?? 'Customer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.title ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (item.countdownLabel != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          isOverdue
                              ? Icons.warning_amber_rounded
                              : Icons.timelapse,
                          size: 12,
                          color: color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.countdownLabel!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Reschedule or cancel this plan. The card tap still opens the
            // pipeline; the menu consumes its own tap so the two don't conflict.
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                size: 18,
                color: AppColors.primaryNavy,
              ),
              tooltip: 'Aksi jadwal',
              padding: EdgeInsets.zero,
              onSelected: (v) {
                if (v == 'edit') _editSchedule(item);
                if (v == 'cancel') _cancelSchedule(item);
                if (v == 'done') _completeSchedule(item);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'done',
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: AppColors.successGreen,
                      ),
                      SizedBox(width: 10),
                      Text('Tandai selesai'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_calendar_outlined,
                        size: 18,
                        color: AppColors.primaryNavy,
                      ),
                      SizedBox(width: 10),
                      Text('Ubah jadwal'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_busy_outlined,
                        size: 18,
                        color: AppColors.errorRed,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Batalkan jadwal',
                        style: TextStyle(color: AppColors.errorRed),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.grayStage,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the reschedule sheet pre-filled with the schedule's current values,
  /// saves the edit, then refreshes the list.
  Future<void> _editSchedule(DashboardSchedule item) async {
    final result = await showModalBottomSheet<_ScheduleEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _EditScheduleSheet(
        initialAgenda: item.title ?? '',
        initialDateTime: DateTime.tryParse(
          item.scheduleDateTime ?? '',
        )?.toLocal(),
      ),
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _pipelineRepo.updateSchedule(
        item.id,
        agenda: result.agenda,
        scheduleDateTime: result.dateTime,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Jadwal diperbarui')),
      );
      _fetch();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  /// Tutup jadwal yang sudah dikerjakan (DONE). Sama seperti pembatalan, jadwalnya
  /// keluar dari daftar ini (yang hanya menampilkan rencana OPEN) tetapi catatannya
  /// tetap tersimpan — bedanya ini menandai "sudah dilakukan", bukan "tidak jadi".
  Future<void> _completeSchedule(DashboardSchedule item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Tandai jadwal selesai?'),
        content: Text(
          'Jadwal "${item.title ?? 'kunjungan'}"${item.customerName != null ? ' untuk ${item.customerName}' : ''} '
          'akan ditandai selesai dan hilang dari daftar. Lanjutkan?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Kembali'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Tandai selesai',
              style: TextStyle(
                color: AppColors.successGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _pipelineRepo.setScheduleStatus(item.id, 'DONE');
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Jadwal ditandai selesai')),
      );
      _fetch(silent: true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  /// Soft-delete: mark the schedule CANCELLED. It then drops out of this list
  /// (which only shows OPEN plans) but the record is kept for audit.
  Future<void> _cancelSchedule(DashboardSchedule item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
        scrollable: true,
        title: const Text('Batalkan jadwal?'),
        content: Text(
          'Jadwal "${item.title ?? 'kunjungan'}"${item.customerName != null ? ' untuk ${item.customerName}' : ''} '
          'akan dibatalkan dan hilang dari daftar. Lanjutkan?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Kembali'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Batalkan jadwal',
              style: TextStyle(
                color: AppColors.errorRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _pipelineRepo.setScheduleStatus(item.id, 'CANCELLED');
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Jadwal dibatalkan')),
      );
      _fetch(silent: true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }
}

/// Result of [_EditScheduleSheet] — the new date-time and agenda.
class _ScheduleEditResult {
  final DateTime dateTime;
  final String agenda;
  _ScheduleEditResult(this.dateTime, this.agenda);
}

/// Reschedule sheet: pre-filled date + time pickers and an agenda field.
/// Mirrors the "Jadwalkan Visit" sheet in pipeline_detail_screen, but seeded
/// with the existing values for editing.
class _EditScheduleSheet extends StatefulWidget {
  final String initialAgenda;
  final DateTime? initialDateTime;
  const _EditScheduleSheet({required this.initialAgenda, this.initialDateTime});

  @override
  State<_EditScheduleSheet> createState() => _EditScheduleSheetState();
}

class _EditScheduleSheetState extends State<_EditScheduleSheet> {
  DateTime? _date;
  TimeOfDay? _time;
  late final TextEditingController _agendaCtrl;
  bool _showErrors = false; // inline required-field validation

  @override
  void initState() {
    super.initState();
    _agendaCtrl = TextEditingController(text: widget.initialAgenda);
    final dt = widget.initialDateTime;
    if (dt != null) {
      _date = DateTime(dt.year, dt.month, dt.day);
      _time = TimeOfDay(hour: dt.hour, minute: dt.minute);
    }
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
    final dt = DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
    );
    Navigator.of(context).pop(_ScheduleEditResult(dt, _agendaCtrl.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _date == null
        ? 'Pilih tanggal'
        : AppFormat.dateOnly(_date);
    final timeLabel = _time == null ? 'Pilih waktu' : _time!.format(context);
    final agendaEmpty = _agendaCtrl.text.trim().isEmpty;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      // Isi sheet bisa lebih tinggi dari layar (mis. daftar chip kategori,
      // atau keyboard terbuka di layar pendek) -> harus bisa di-scroll,
      // kalau tidak muncul garis kuning 'BOTTOM OVERFLOWED BY ... PIXELS'.
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ubah Jadwal',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
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
                        final initial = _date ?? now;
                        // Allow keeping an already-past (overdue) date: firstDate
                        // must not exceed initialDate or showDatePicker asserts.
                        final earliest = now.subtract(const Duration(days: 1));
                        final first = initial.isBefore(earliest)
                            ? initial
                            : earliest;
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initial,
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
                        child: Text(
                          'Tanggal wajib diisi',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.errorRed,
                          ),
                        ),
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
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _time ?? TimeOfDay.now(),
                        );
                        if (picked != null) setState(() => _time = picked);
                      },
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text(timeLabel, overflow: TextOverflow.ellipsis),
                    ),
                    if (_showErrors && _time == null)
                      const Padding(
                        padding: EdgeInsets.only(left: 4, top: 4),
                        child: Text(
                          'Waktu wajib diisi',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.errorRed,
                          ),
                        ),
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
              hintStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.grayStage,
              ),
              isDense: true,
              border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
              errorText: _showErrors && agendaEmpty
                  ? 'Agenda wajib diisi'
                  : null,
              errorStyle: const TextStyle(
                fontSize: 11,
                color: AppColors.errorRed,
              ),
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
              child: const Text(
                'Simpan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
