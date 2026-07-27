import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/repository_providers.dart';
import '../../theme/app_theme.dart';
import '../../src/app.dart';
import '../../src/nav.dart';
import '../../src/network/api_client.dart';
import '../../src/reference/reference_repository.dart';
import '../../src/assistant/assistant_repository.dart' show AiField;
import '../../src/assistant/ai_activity_admin_repository.dart';
import '../providers/kelola_aktivitas_ai_provider.dart';
import 'kelola_model_ai_screen.dart';
import 'kelola_kuota_ai_screen.dart';

/// ADMIN — Kelola Aktivitas AI. Daftar aktivitas + buat/edit dengan merakit komponen.
class KelolaAktivitasAiScreen extends ConsumerStatefulWidget {
  const KelolaAktivitasAiScreen({super.key});

  @override
  ConsumerState<KelolaAktivitasAiScreen> createState() => _KelolaAktivitasAiScreenState();
}

class _KelolaAktivitasAiScreenState extends ConsumerState<KelolaAktivitasAiScreen> {
  // State data/loading dikelola KelolaAktivitasAiNotifier. Getter berikut
  // memproksinya agar seluruh kode build/aksi di bawah tetap memakai nama lama.
  KelolaAktivitasAiState get _st => ref.read(kelolaAktivitasAiProvider);
  KelolaAktivitasAiNotifier get _notifier =>
      ref.read(kelolaAktivitasAiProvider.notifier);

  AiActivityAdminRepository get _repo => ref.read(aiActivityAdminRepoProvider);
  bool get _ready => _st.ready;
  bool get _loading => _st.loading;
  String? get _error => _st.error;
  List<AiComponent> get _components => _st.components;
  List<AdminActivity> get _activities => _st.activities;

  @override
  void initState() {
    super.initState();
    // Bootstrap notifier setelah frame pertama (samakan timing lama). Repo kini
    // dibaca notifier dari aiActivityAdminRepoProvider — tak perlu context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start();
    });
  }

  /// Muat ulang daftar via notifier (dipakai editor-return, toggle, delete, retry).
  Future<void> _load() => _notifier.load();

  Future<void> _openEditor([AdminActivity? existing]) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => AktivitasAiEditScreen(
        repo: _repo,
        components: _components,
        existing: existing,
      ),
    ));
    if (saved == true) _load();
  }

  Future<void> _toggle(AdminActivity a, bool enabled) async {
    try {
      await _repo.update(a.id!, a.copyWith(enabled: enabled));
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.errorRed));
      }
    }
  }

  Future<void> _delete(AdminActivity a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
        scrollable: true,
        title: const Text('Hapus Aktivitas'),
        content: Text('Hapus aktivitas "${a.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus', style: TextStyle(color: AppColors.errorRed))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.delete(a.id!);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.errorRed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(kelolaAktivitasAiProvider);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: AppBar(
        backgroundColor: AppColors.primaryNavy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => safePop(context)),
        title: const Text('Kelola Aktivitas AI',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.speed_outlined),
            tooltip: 'Kelola Kuota AI',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KelolaKuotaAiScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.memory),
            tooltip: 'Kelola Model AI',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KelolaModelAiScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: _ready
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primaryNavy,
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Aktivitas', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: !_ready || _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, style: const TextStyle(color: AppColors.errorRed)),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
                  ]),
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    const Text('Aktivitas yang bisa dijalankan RM. Aktif/nonaktifkan, atau rakit yang baru.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 14),
                    if (_activities.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 44),
                        child: Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.auto_awesome_outlined,
                                size: 44, color: AppColors.grayStage.withValues(alpha: 0.4)),
                            const SizedBox(height: 14),
                            const Text('Belum ada aktivitas AI',
                                style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                          ]),
                        ),
                      )
                    else
                      for (final a in _activities) ...[
                        _activityRow(a),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
    );
  }

  Widget _activityRow(AdminActivity a) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Text(a.icon ?? '🤖', style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(a.name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ),
                if (a.builtIn) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.navyBg, borderRadius: AppRadius.radiusXs),
                    child: const Text('Bawaan',
                        style: TextStyle(fontSize: 10, color: AppColors.primaryNavy, fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
              if ((a.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(a.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ]),
          ),
          Switch(
            value: a.enabled,
            activeThumbColor: AppColors.primaryNavy,
            onChanged: (v) => _toggle(a, v),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            onSelected: (v) {
              if (v == 'edit') _openEditor(a);
              if (v == 'delete') _delete(a);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              if (!a.builtIn)
                const PopupMenuItem(
                    value: 'delete', child: Text('Hapus', style: TextStyle(color: AppColors.errorRed))),
            ],
          ),
        ]),
      ),
    );
  }
}

// ===========================================================================

/// Builder: rakit aktivitas dari komponen (tanpa prompt) + atur field & kelayakan.
class AktivitasAiEditScreen extends StatefulWidget {
  final AiActivityAdminRepository repo;
  final List<AiComponent> components;
  final AdminActivity? existing;

  const AktivitasAiEditScreen({
    super.key,
    required this.repo,
    required this.components,
    this.existing,
  });

  @override
  State<AktivitasAiEditScreen> createState() => _AktivitasAiEditScreenState();
}

class _FieldDraft {
  final TextEditingController label;
  String type;
  bool required;
  final TextEditingController options;
  final TextEditingController help;
  _FieldDraft({String label = '', this.type = 'TEXT', this.required = false, String options = '', String help = ''})
      : label = TextEditingController(text: label),
        options = TextEditingController(text: options),
        help = TextEditingController(text: help);
  void dispose() {
    label.dispose();
    options.dispose();
    help.dispose();
  }
}

class _AktivitasAiEditScreenState extends State<AktivitasAiEditScreen> {
  static const Map<String, String> _sourceLabels = {
    'CUSTOMER': 'Data Customer',
    'PRODUCT_CATALOG': 'Katalog Produk',
    'WEB_SEARCH': 'Web',
    'VISIT_NOTES': 'Catatan Visit',
  };
  // Opsi status & entitas customer: param CUSTOMER_STATE / ENTITY_CATEGORY
  // (admin-editable di Kelola Master Data). Fallback bila param belum termuat.
  List<String> _states = const ['CIF', 'TEMPORARY'];
  List<String> _entities = const ['BUMN', 'Swasta', 'BLU'];
  bool _optionsLoaded = false;

  late TextEditingController _name;
  late TextEditingController _icon;
  late TextEditingController _desc;
  late TextEditingController _sort;
  bool _enabled = true;
  final Set<String> _tasks = {};
  final List<_FieldDraft> _fields = [];
  bool _reqNoPipeline = false;
  final Set<String> _allowedStates = {};
  final Set<String> _allowedEntities = {};
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _icon = TextEditingController(text: e?.icon ?? '🤖');
    _desc = TextEditingController(text: e?.description ?? '');
    _sort = TextEditingController(text: '${e?.sortOrder ?? 0}');
    _enabled = e?.enabled ?? true;
    if (e != null) {
      _tasks.addAll(e.tasks);
      for (final f in e.fields) {
        _fields.add(_FieldDraft(
          label: f.label,
          type: f.type,
          required: f.required,
          options: f.options.join(', '),
          help: f.help ?? '',
        ));
      }
      final el = e.eligibility;
      if (el != null) {
        _reqNoPipeline = el.requireNoActivePipeline;
        _allowedStates.addAll(el.allowedStates);
        _allowedEntities.addAll(el.allowedEntityCategories);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_optionsLoaded) return;
    _optionsLoaded = true;
    _loadOptions();
  }

  /// Load admin-editable status/entity options (fallback stays on failure/empty).
  Future<void> _loadOptions() async {
    try {
      final refRepo = ReferenceRepository(apiClient: ApiClient(session: MbisApp.of(context)?.session));
      final states = await refRepo.parameters('CUSTOMER_STATE');
      final entities = await refRepo.parameters('ENTITY_CATEGORY');
      if (!mounted) return;
      setState(() {
        if (states.isNotEmpty) _states = states.map((p) => p.key).toList();
        if (entities.isNotEmpty) _entities = entities.map((p) => p.value).toList();
      });
    } catch (_) {/* keep fallback */}
  }

  @override
  void dispose() {
    _name.dispose();
    _icon.dispose();
    _desc.dispose();
    _sort.dispose();
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  /// Data sources derived from the selected task components (union).
  List<String> get _derivedSources {
    final set = <String>{};
    for (final c in widget.components.where((c) => _tasks.contains(c.key))) {
      set.addAll(c.defaultSources);
    }
    return set.toList();
  }

  List<AiField> _buildFields() {
    final out = <AiField>[];
    final used = <String>{};
    for (var i = 0; i < _fields.length; i++) {
      final d = _fields[i];
      final label = d.label.text.trim();
      if (label.isEmpty) continue;
      var key = label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
      if (key.isEmpty) key = 'field_$i';
      while (used.contains(key)) {
        key = '${key}_$i';
      }
      used.add(key);
      out.add(AiField(
        key: key,
        label: label,
        type: d.type,
        required: d.required,
        options: d.type == 'CHIPS'
            ? d.options.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
            : const [],
        help: d.help.text.trim().isEmpty ? null : d.help.text.trim(),
      ));
    }
    return out;
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_name.text.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Nama aktivitas wajib diisi.')));
      return;
    }
    if (_tasks.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Pilih minimal satu komponen Tujuan.')));
      return;
    }
    final eligibility = (_reqNoPipeline || _allowedStates.isNotEmpty || _allowedEntities.isNotEmpty)
        ? AiEligibilityModel(
            requireNoActivePipeline: _reqNoPipeline,
            allowedStates: _allowedStates.toList(),
            allowedEntityCategories: _allowedEntities.toList(),
          )
        : null;
    final activity = AdminActivity(
      id: widget.existing?.id,
      name: _name.text.trim(),
      description: _desc.text.trim(),
      icon: _icon.text.trim().isEmpty ? '🤖' : _icon.text.trim(),
      enabled: _enabled,
      sortOrder: int.tryParse(_sort.text.trim()) ?? 0,
      tasks: _tasks.toList(),
      sources: const [], // backend derives from tasks
      fields: _buildFields(),
      eligibility: eligibility,
      builtIn: widget.existing?.builtIn ?? false,
    );
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await widget.repo.update(activity.id!, activity);
      } else {
        await widget.repo.create(activity);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        messenger.showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.errorRed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: AppBar(
        backgroundColor: AppColors.primaryNavy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(_isEdit ? 'Edit Aktivitas' : 'Aktivitas Baru',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '...' : 'Simpan',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _section(
            icon: Icons.badge_outlined,
            title: 'Identitas',
            subtitle: 'Nama, ikon, dan status aktivitas.',
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 64, child: _input(_icon, 'Ikon')),
                const SizedBox(width: 10),
                Expanded(child: _input(_name, 'Nama aktivitas')),
              ]),
              const SizedBox(height: 12),
              _input(_desc, 'Deskripsi singkat', maxLines: 2),
              const SizedBox(height: 12),
              Row(children: [
                SizedBox(width: 96, child: _input(_sort, 'Urutan', number: true)),
                const SizedBox(width: 12),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Aktif untuk RM',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Tampil di Asisten AI', style: TextStyle(fontSize: 11)),
                    value: _enabled,
                    activeThumbColor: AppColors.primaryNavy,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                ),
              ]),
            ],
          ),
          _section(
            icon: Icons.auto_awesome_outlined,
            title: 'Komponen Tujuan',
            subtitle: 'Pilih satu atau lebih. Tidak perlu menulis prompt.',
            children: [
              for (final c in widget.components) _componentTile(c),
              if (_derivedSources.isNotEmpty) ...[
                const SizedBox(height: 4),
                const Text('Sumber data (otomatis)',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in _derivedSources)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: AppColors.navyBg, borderRadius: AppRadius.radiusFull),
                        child: Text(_sourceLabels[s] ?? s,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.primaryNavy, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ],
            ],
          ),
          _section(
            icon: Icons.quiz_outlined,
            title: 'Pertanyaan ke RM',
            subtitle: 'Yang harus diisi RM saat menjalankan. Opsional.',
            children: [
              if (_fields.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('Belum ada pertanyaan.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.grayStage)),
                ),
              for (var i = 0; i < _fields.length; i++) _fieldEditor(i),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _fields.add(_FieldDraft())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah pertanyaan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryNavy,
                    side: const BorderSide(color: AppColors.primaryNavy),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                  ),
                ),
              ),
            ],
          ),
          _section(
            icon: Icons.filter_alt_outlined,
            title: 'Kelayakan Customer',
            subtitle: 'Batasi kapan aktivitas ini boleh dijalankan. Opsional.',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Hanya customer tanpa pipeline aktif',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: _reqNoPipeline,
                activeThumbColor: AppColors.primaryNavy,
                onChanged: (v) => setState(() => _reqNoPipeline = v),
              ),
              const SizedBox(height: 10),
              _miniLabel('Hanya untuk state'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in _states)
                  FilterChip(
                    label: Text(s),
                    selected: _allowedStates.contains(s),
                    onSelected: (v) =>
                        setState(() => v ? _allowedStates.add(s) : _allowedStates.remove(s)),
                  ),
              ]),
              const SizedBox(height: 14),
              _miniLabel('Hanya untuk entitas'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in _entities)
                  FilterChip(
                    label: Text(s),
                    selected: _allowedEntities.contains(s),
                    onSelected: (v) =>
                        setState(() => v ? _allowedEntities.add(s) : _allowedEntities.remove(s)),
                  ),
              ]),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// A titled section container — one clean card per part of the form.
  Widget _section({
    required IconData icon,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: AppColors.navyBg, borderRadius: AppRadius.radiusSm),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: AppColors.primaryNavy),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11.5, height: 1.35, color: AppColors.textSecondary)),
                ],
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          ...children,
        ]),
      ),
    );
  }

  /// A selectable "Tujuan" component tile (checkbox-style, tap anywhere).
  Widget _componentTile(AiComponent c) {
    final selected = _tasks.contains(c.key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.radiusMd,
        child: InkWell(
          borderRadius: AppRadius.radiusMd,
          onTap: () => setState(() => selected ? _tasks.remove(c.key) : _tasks.add(c.key)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.navyBg : AppColors.bgScreen,
              borderRadius: AppRadius.radiusMd,
              border: Border.all(
                  color: selected ? AppColors.primaryNavy : AppColors.border,
                  width: selected ? 1.3 : 1),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  size: 20, color: selected ? AppColors.primaryNavy : AppColors.grayStage),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.label,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  if (c.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(c.description,
                        style: const TextStyle(
                            fontSize: 11.5, height: 1.35, color: AppColors.textSecondary)),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _miniLabel(String t) => Text(t,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary));

  Widget _fieldEditor(int i) {
    final d = _fields[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgScreen,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _input(d.label, 'Label pertanyaan')),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.errorRed),
            onPressed: () => setState(() {
              _fields.removeAt(i).dispose();
            }),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: d.type,
              isExpanded: true,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              icon: const Icon(Icons.expand_more_rounded, size: 20, color: AppColors.grayStage),
              decoration: _fieldDecoration(),
              items: const [
                DropdownMenuItem(value: 'CHIPS', child: Text('Pilihan (chip)')),
                DropdownMenuItem(value: 'MULTICHIPS', child: Text('Pilihan ganda (multi-chip)')),
                DropdownMenuItem(value: 'TEXT', child: Text('Teks pendek')),
                DropdownMenuItem(value: 'TEXTAREA', child: Text('Teks panjang')),
              ],
              onChanged: (v) => setState(() => d.type = v ?? 'TEXT'),
            ),
          ),
          const SizedBox(width: 8),
          const Text('Wajib', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Switch(
            value: d.required,
            activeThumbColor: AppColors.primaryNavy,
            onChanged: (v) => setState(() => d.required = v),
          ),
        ]),
        if (d.type == 'CHIPS') ...[
          const SizedBox(height: 10),
          _input(d.options, 'Opsi (pisahkan dengan koma)'),
        ],
        const SizedBox(height: 10),
        _input(d.help, 'Teks bantuan (opsional)'),
      ]),
    );
  }

  /// Shared minimalist field decoration: white surface, subtle border, navy focus.
  InputDecoration _fieldDecoration({String? label, String? hint}) {
    OutlineInputBorder side(Color col, [double w = 1]) => OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: BorderSide(color: col, width: w),
        );
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      floatingLabelStyle: const TextStyle(fontSize: 13, color: AppColors.primaryNavy),
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: AppColors.grayStage),
      isDense: true,
      filled: true,
      fillColor: AppColors.surfaceWhite,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: side(AppColors.border),
      enabledBorder: side(AppColors.border),
      focusedBorder: side(AppColors.primaryNavy, 1.5),
    );
  }

  Widget _input(TextEditingController c, String label, {int maxLines = 1, bool number = false}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      keyboardType: number ? TextInputType.number : null,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: _fieldDecoration(label: label),
    );
  }
}
