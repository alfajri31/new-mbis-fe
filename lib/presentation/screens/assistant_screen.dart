import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/debouncer.dart';
import '../../theme/app_theme.dart';
import '../../src/assistant/assistant_repository.dart';
import '../../src/customer/customer_repository.dart';
import '../providers/assistant_provider.dart';
import '../widgets/ai_result_view.dart';
import '../widgets/assistant/activity_card.dart';
import '../widgets/assistant/assistant_bubble.dart';
import '../widgets/assistant/assistant_disclaimer.dart';
import '../widgets/assistant/assistant_error_box.dart';
import '../widgets/assistant/assistant_limit_box.dart';
import '../widgets/assistant/assistant_loading_view.dart';
import '../widgets/assistant/assistant_mascot.dart';
import '../widgets/assistant/cache_banner.dart';

/// AI Assistant — guided/wizard over admin-composed activities (RM-only).
///
/// Dibuka dengan customer ter-preselect (dari Customer Detail) atau tanpa customer
/// (dari Tools — picker dulu). Alur: pilih aktivitas → isi field yang admin tentukan →
/// jalankan → jawaban tampil sebagai chat (Markdown) → RM bisa "Simpan ke customer".
class AssistantScreen extends ConsumerStatefulWidget {
  final String? customerId;
  final String? customerName;

  const AssistantScreen({super.key, this.customerId, this.customerName});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

enum _Step { pickCustomer, activityList, form, result }

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  // Wizard step (navigasi UI) tetap di widget.
  _Step _step = _Step.activityList;
  // Identitas customer terpilih (dipicu picker/param) — dipakai UI & diteruskan
  // ke method notifier; bukan state backend.
  String? _custId;
  String? _custName;

  // UI-ephemeral (tetap di widget): kolom cari, controller teks per-field, nilai
  // chip/multi-chip yang diedit user.
  final _searchCtrl = TextEditingController();
  // Menunda panggilan pencarian customer ke server sampai user berhenti mengetik.
  final _searchDebounce = Debouncer();
  final Map<String, TextEditingController> _textCtrls = {};
  final Map<String, String> _chipValues = {};

  // State bisnis/async dikelola AssistantNotifier. Getter berikut memproksinya
  // agar seluruh kode build/widget di bawah tetap memakai nama lama tanpa diubah.
  AssistantState get _as => ref.read(assistantProvider);
  AssistantNotifier get _notifier => ref.read(assistantProvider.notifier);

  bool get _ready => _as.ready;
  bool get _canRun => _as.canRun;
  List<CustomerListModel> get _custResults => _as.custResults;
  bool get _custLoading => _as.custLoading;
  List<AiActivity> get _activities => _as.activities;
  bool get _activitiesLoading => _as.activitiesLoading;
  String? get _activitiesError => _as.activitiesError;
  AiActivity? get _activity => _as.activity;
  String? get _formError => _as.formError;
  bool get _limitReached => _as.limitReached;
  bool get _running => _as.running;
  AiRunResult? get _result => _as.result;
  bool get _saving => _as.saving;
  bool get _saved => _as.saved;
  bool get _fromCache => _as.fromCache;
  String? get _cachedAt => _as.cachedAt;

  @override
  void initState() {
    super.initState();
    _custId = widget.customerId;
    _custName = widget.customerName;
    // Picker adalah langkah awal bila tak ada customer ter-preselect (dulu di-set
    // di dalam post-frame; body tetap spinner sampai `ready`, jadi ekuivalen).
    if (_custId == null) _step = _Step.pickCustomer;
    // Bootstrap notifier setelah frame pertama (samakan timing lama). Peran dibaca
    // notifier dari sessionProvider — tak perlu context/MbisApp.of.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start(customerId: _custId);
    });
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchCtrl.dispose();
    for (final c in _textCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // Pencarian customer → delegasi ke notifier (hasil/loading dipindah utuh),
  // di-debounce agar tidak memanggil server tiap ketukan.
  void _searchCustomers(String q) =>
      _searchDebounce.run(() => _notifier.searchCustomers(q));

  /// Muat aktivitas untuk customer aktif. Step (nav) di-set di sini; data/loading
  /// dipindah ke notifier.
  void _loadActivities() {
    setState(() => _step = _Step.activityList);
    _notifier.loadActivities(_custId!);
  }

  void _openActivity(AiActivity a) {
    // Controller & chip input = UI: dispose/buat ulang di widget.
    for (final c in _textCtrls.values) {
      c.dispose();
    }
    _textCtrls.clear();
    _chipValues.clear();
    for (final f in a.fields) {
      if (f.type == 'TEXT' || f.type == 'TEXTAREA') {
        _textCtrls[f.key] = TextEditingController();
      }
    }
    // Data aktivitas + hasil/cache dipindah ke notifier; step ikut hasil cache.
    _notifier.openActivity(a);
    setState(() {
      _step = _as.fromCache ? _Step.result : _Step.form;
    });
  }

  /// Leaves the cached view to run a fresh call — this is where tokens are spent.
  void _rerunFromCache() {
    _notifier.rerunFromCache();
    setState(() => _step = _Step.form);
  }

  Future<void> _run() async {
    final a = _activity!;
    final inputs = <String, String>{};
    for (final f in a.fields) {
      String value = '';
      if (f.type == 'CHIPS' || f.type == 'MULTICHIPS') {
        value = _chipValues[f.key] ?? '';
      } else {
        value = _textCtrls[f.key]?.text.trim() ?? '';
      }
      if (f.required && value.isEmpty) {
        _notifier.setFormError('"${f.label}" wajib diisi.');
        return;
      }
      if (value.isNotEmpty) inputs[f.key] = value;
    }
    final ok = await _notifier.run(custId: _custId!, activity: a, inputs: inputs);
    if (!mounted) return;
    if (ok) setState(() => _step = _Step.result);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await _notifier.save(_custId!);
    if (!mounted) return;
    if (error == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Rangkuman disimpan ke customer.'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(assistantProvider);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: AppBar(
        backgroundColor: AppColors.primaryNavy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            const AssistantMascot(size: 28),
            const SizedBox(width: 8),
            const Text(
              'Tanya Dubi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : _running
          ? const AssistantLoadingView()
          : switch (_step) {
              _Step.pickCustomer => _buildPicker(),
              _Step.activityList => _buildActivityList(),
              _Step.form => _buildForm(),
              _Step.result => _buildResult(),
            },
    );
  }

  // --- pick customer -----------------------------------------------------

  Widget _buildPicker() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _searchCustomers,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Cari customer',
              hintStyle: const TextStyle(color: AppColors.grayStage, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.grayStage, size: 20),
              prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 0),
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceWhite,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              border: OutlineInputBorder(
                borderRadius: AppRadius.radiusFull,
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.radiusFull,
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.radiusFull,
                borderSide: const BorderSide(color: AppColors.primaryNavy, width: 1.5),
              ),
            ),
          ),
        ),
        if (_custLoading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _custResults.isEmpty
              ? const Center(
                  child: Text(
                    'Tidak ada customer ditemukan.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xs,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  itemCount: _custResults.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final c = _custResults[i];
                    return Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: AppRadius.radiusLg,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _custId = c.id;
                              _custName = c.name;
                            });
                            _loadActivities();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        c.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        c.entityCategory ?? '-',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right,
                                    color: AppColors.grayStage),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- activity list -----------------------------------------------------

  Widget _buildActivityList() {
    if (_activitiesLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_activitiesError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _activitiesError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.errorRed),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loadActivities,
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AssistantBubble(
          text:
              'Pilih aktivitas yang ingin saya bantu untuk '
              '${_custName ?? 'customer ini'}.',
        ),
        const SizedBox(height: 6),
        if (widget.customerId == null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _step = _Step.pickCustomer),
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: const Text('Ganti customer'),
            ),
          ),
        const SizedBox(height: 8),
        if (_activities.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_outlined,
                      size: 44, color: AppColors.grayStage.withValues(alpha: 0.4)),
                  const SizedBox(height: 14),
                  const Text(
                    'Belum ada aktivitas AI yang aktif',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          for (final a in _activities) ...[
            ActivityCard(
              activity: a,
              enabled: a.eligible && _canRun,
              onTap: () => _openActivity(a),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  // --- form (dynamic fields) ---------------------------------------------

  Widget _buildForm() {
    final a = _activity!;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AssistantBubble(
          text: a.description?.isNotEmpty == true
              ? a.description!
              : 'Isi keterangan berikut lalu jalankan.',
        ),
        const SizedBox(height: 14),
        if (a.fields.isEmpty)
          const Text(
            'Tidak ada input yang perlu diisi. Tekan Jalankan.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        for (final f in a.fields) ...[
          _fieldWidget(f),
          const SizedBox(height: 16),
        ],
        if (_limitReached) ...[
          const AssistantLimitBox(),
          const SizedBox(height: 14),
        ] else if (_formError != null) ...[
          AssistantErrorBox(text: _formError!),
          const SizedBox(height: 14),
        ],
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadius.radiusMd,
            boxShadow: const [AppShadows.level3],
          ),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _run,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: Colors.white,
                elevation: 0,
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
              ),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Jalankan'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _step = _Step.activityList),
            child: const Text('← Aktivitas lain'),
          ),
        ),
      ],
    );
  }

  Widget _fieldWidget(AiField f) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(f.label, required: f.required),
        if ((f.help ?? '').isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            f.help!,
            style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 10),
        if (f.type == 'CHIPS')
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: f.options
                .map(
                  (o) => ChoiceChip(
                    label: Text(o),
                    selected: _chipValues[f.key] == o,
                    onSelected: (sel) => setState(() {
                      if (sel) {
                        _chipValues[f.key] = o;
                      } else {
                        _chipValues.remove(f.key);
                      }
                    }),
                  ),
                )
                .toList(),
          )
        else if (f.type == 'MULTICHIPS')
          _multiChips(f)
        else
          TextField(
            controller: _textCtrls[f.key],
            maxLines: f.type == 'TEXTAREA' ? 4 : 1,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: _inputDecoration(
              hint: f.type == 'TEXTAREA' ? 'Tulis di sini…' : null,
            ),
          ),
      ],
    );
  }

  /// Multi-select chips (MULTICHIPS): value stored as a comma-joined string in [_chipValues].
  Widget _multiChips(AiField f) {
    final selected = (_chipValues[f.key] ?? '')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: f.options
          .map(
            (o) => FilterChip(
              label: Text(o),
              selected: selected.contains(o),
              onSelected: (sel) => setState(() {
                if (sel) {
                  selected.add(o);
                } else {
                  selected.remove(o);
                }
                if (selected.isEmpty) {
                  _chipValues.remove(f.key);
                } else {
                  _chipValues[f.key] = selected.join(', ');
                }
              }),
            ),
          )
          .toList(),
    );
  }

  /// Minimalist, consistent field label (with an optional required asterisk).
  Widget _fieldLabel(String text, {bool required = false}) {
    return Text.rich(
      TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: 0.1,
        ),
        children: required
            ? const [TextSpan(text: ' *', style: TextStyle(color: AppColors.errorRed))]
            : null,
      ),
    );
  }

  /// Shared minimalist input styling: white surface, subtle border, navy focus.
  InputDecoration _inputDecoration({String? hint}) {
    OutlineInputBorder side(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.grayStage),
      isDense: true,
      filled: true,
      fillColor: AppColors.surfaceWhite,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: side(AppColors.border),
      enabledBorder: side(AppColors.border),
      focusedBorder: side(AppColors.primaryNavy, 1.5),
    );
  }

  // --- result (chat) -----------------------------------------------------

  Widget _buildResult() {
    final r = _result!;
    final a = _activity;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              // Context header: which activity produced this.
              Row(
                children: [
                  const AssistantMascot(size: 30, dark: true),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      a?.name ?? r.activityName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_fromCache) CacheBanner(cachedAt: _cachedAt),
              AiResultView(result: r.result, sources: r.sources),
              const SizedBox(height: 12),
              const AssistantDisclaimer(
                text:
                    'Hasil dibuat oleh AI dan dapat keliru — mohon verifikasi sebelum dipakai.',
              ),
            ],
          ),
        ),
        // Action bar.
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceWhite,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _step = _Step.activityList),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryNavy,
                      side: const BorderSide(color: AppColors.primaryNavy, width: 1.5),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusMd,
                      ),
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Aktivitas lain'),
                  ),
                ),
                const SizedBox(width: 10),
                // A cached result is already saved, so the primary action becomes
                // a fresh run (which spends a token); a fresh result offers Save.
                Expanded(
                  child: _fromCache
                      ? ElevatedButton.icon(
                          onPressed: _canRun ? _rerunFromCache : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryNavy,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                            minimumSize: const Size.fromHeight(52),
                          ),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Jalankan ulang',
                              maxLines: 1, softWrap: false, overflow: TextOverflow.fade),
                        )
                      : ElevatedButton.icon(
                          onPressed: _saved || _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _saved
                                ? AppColors.successGreen
                                : AppColors.primaryNavy,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.radiusMd,
                            ),
                            minimumSize: const Size.fromHeight(52),
                          ),
                          icon: Icon(_saved ? Icons.check_circle_outline : Icons.bookmark_add_outlined, size: 18),
                          label: Text(
                            _saved ? 'Tersimpan' : 'Simpan',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
