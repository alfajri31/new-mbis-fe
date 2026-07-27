import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../src/nav.dart';
import '../../src/assistant/ai_activity_admin_repository.dart';
import '../../core/providers/repository_providers.dart';
import '../providers/kelola_model_ai_provider.dart';

/// Provider label + badge colour inferred from a model code's prefix — mirrors the backend
/// `AiProvider.fromCode` routing so every supported provider is recognised (not just Claude/Gemini).
/// Unknown prefixes fall back to Anthropic/Claude, exactly like the server default.
({String label, Color color}) providerBadge(String code) {
  final c = code.trim().toLowerCase();
  bool p(List<String> prefixes) => prefixes.any(c.startsWith);
  if (p(['gemini'])) return (label: 'Gemini', color: const Color(0xFF1A73E8));
  if (p(['gpt', 'chatgpt', 'o1', 'o3', 'o4'])) {
    return (label: 'OpenAI', color: const Color(0xFF10A37F));
  }
  if (p(['grok'])) return (label: 'Grok', color: const Color(0xFF111827));
  if (p(['deepseek'])) return (label: 'DeepSeek', color: const Color(0xFF4D6BFE));
  if (p(['mistral', 'ministral', 'magistral', 'codestral', 'pixtral', 'devstral'])) {
    return (label: 'Mistral', color: const Color(0xFFF2542D));
  }
  if (p(['qwen', 'qwq'])) return (label: 'Qwen', color: const Color(0xFF7C3AED));
  if (p(['kimi', 'moonshot'])) return (label: 'Moonshot', color: const Color(0xFF4338CA));
  if (p(['minimax', 'abab'])) return (label: 'MiniMax', color: const Color(0xFFE11D48));
  // claude-* and anything unmatched → Anthropic (server default).
  return (label: 'Claude', color: const Color(0xFFB8663B));
}

/// ADMIN — Kelola Model AI. Pilih SATU model aktif yang dipakai semua Asisten AI RM;
/// tambah/ubah/hapus model. RM tidak memilih model — model aktif di sini yang dipakai.
class KelolaModelAiScreen extends ConsumerStatefulWidget {
  const KelolaModelAiScreen({super.key});

  @override
  ConsumerState<KelolaModelAiScreen> createState() => _KelolaModelAiScreenState();
}

class _KelolaModelAiScreenState extends ConsumerState<KelolaModelAiScreen> {
  // State bisnis/async dikelola KelolaModelAiNotifier. Getter berikut memproksinya
  // agar seluruh kode build/aksi di bawah tetap memakai nama lama tanpa diubah.
  KelolaModelAiState get _ms => ref.read(kelolaModelAiProvider);
  KelolaModelAiNotifier get _notifier => ref.read(kelolaModelAiProvider.notifier);

  // Repo untuk aksi tulis (aktifkan/hapus/simpan) — dulu dibuat dari sesi context.
  AiModelAdminRepository get _repo => ref.read(aiModelAdminRepoProvider);

  bool get _ready => _ms.ready;
  bool get _loading => _ms.loading;
  String? get _error => _ms.error;
  List<AdminAiModel> get _models => _ms.models;

  @override
  void initState() {
    super.initState();
    // Bootstrap notifier setelah frame pertama (samakan timing lama). Repo kini
    // dibaca notifier dari provider — tak perlu context/session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start();
    });
  }

  // Muat ulang daftar → delegasi ke notifier (logika data/loading dipindah utuh).
  Future<void> _load() => _notifier.reload();

  Future<void> _activate(AdminAiModel m) async {
    if (m.enabled) return; // already the active model
    try {
      await _repo.activate(m.code);
      _load();
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _delete(AdminAiModel m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
        scrollable: true,
        title: const Text('Hapus Model'),
        content: Text('Hapus model "${m.label}" (${m.code})?'),
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
      await _repo.delete(m.code);
      _load();
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _openEditor([AdminAiModel? existing]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ModelEditDialog(repo: _repo, existing: existing),
    );
    if (saved == true) _load();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.errorRed));
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(kelolaModelAiProvider);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: AppBar(
        backgroundColor: AppColors.primaryNavy,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => safePop(context)),
        title: const Text('Kelola Model AI',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: _ready
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primaryNavy,
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Model', style: TextStyle(color: Colors.white)),
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
                    const Text(
                        'Pilih satu model aktif — model ini yang dipakai untuk semua Asisten AI. '
                        'RM tidak memilih model sendiri.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 14),
                    if (_models.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text('Belum ada model.',
                              style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      )
                    else
                      for (final m in _models) ...[
                        _modelRow(m),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
    );
  }

  Widget _modelRow(AdminAiModel m) {
    final active = m.enabled;
    // Provider is inferred from the code prefix (mirrors the backend AiProvider routing).
    final provider = providerBadge(m.code);
    return Container(
      decoration: BoxDecoration(
        color: active ? AppColors.navyBg : AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
            color: active ? AppColors.primaryNavy : AppColors.border,
            width: active ? 1.5 : 1),
        boxShadow: const [AppShadows.level1],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.radiusLg,
        child: InkWell(
          borderRadius: AppRadius.radiusLg,
          onTap: active ? null : () => _activate(m),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 4, 12),
            child: Row(children: [
              // Single-active selector: only one model can be active at a time.
              Icon(
                active ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: active ? AppColors.primaryNavy : AppColors.grayStage,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(m.label,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: provider.color, borderRadius: AppRadius.radiusXs),
                      child: Text(provider.label,
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                    if (active) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.primaryNavy, borderRadius: AppRadius.radiusXs),
                        child: const Text('Aktif',
                            style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ],
                    if (m.builtIn) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: AppRadius.radiusXs),
                        child: const Text('Bawaan',
                            style: TextStyle(fontSize: 10, color: AppColors.primaryNavy, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(m.code,
                      style: const TextStyle(fontSize: 11, color: AppColors.grayStage, fontFamily: 'monospace')),
                  if ((m.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(m.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ]),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                onSelected: (v) {
                  if (v == 'edit') _openEditor(m);
                  if (v == 'delete') _delete(m);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (!m.builtIn)
                    const PopupMenuItem(
                        value: 'delete', child: Text('Hapus', style: TextStyle(color: AppColors.errorRed))),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================

/// Dialog tambah/edit model. Kode model hanya bisa diatur saat menambah baru.
class _ModelEditDialog extends StatefulWidget {
  final AiModelAdminRepository repo;
  final AdminAiModel? existing;

  const _ModelEditDialog({required this.repo, this.existing});

  @override
  State<_ModelEditDialog> createState() => _ModelEditDialogState();
}

class _ModelEditDialogState extends State<_ModelEditDialog> {
  late TextEditingController _code;
  late TextEditingController _label;
  late TextEditingController _desc;
  late TextEditingController _sort;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _code = TextEditingController(text: e?.code ?? '');
    _label = TextEditingController(text: e?.label ?? '');
    _desc = TextEditingController(text: e?.description ?? '');
    _sort = TextEditingController(text: '${e?.sortOrder ?? 0}');
  }

  @override
  void dispose() {
    _code.dispose();
    _label.dispose();
    _desc.dispose();
    _sort.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final code = _code.text.trim();
    final label = _label.text.trim();
    if (!_isEdit && code.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Kode model wajib diisi.')));
      return;
    }
    if (label.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Nama tampilan wajib diisi.')));
      return;
    }
    final model = AdminAiModel(
      code: _isEdit ? widget.existing!.code : code,
      label: label,
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      // Active state isn't set here — it's chosen from the list via "aktifkan".
      enabled: widget.existing?.enabled ?? false,
      sortOrder: int.tryParse(_sort.text.trim()) ?? 0,
      builtIn: widget.existing?.builtIn ?? false,
    );
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await widget.repo.update(model.code, model);
      } else {
        await widget.repo.create(model);
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
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Model' : 'Model Baru'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _input(_code, 'Kode model',
              enabled: !_isEdit,
              hint: 'mis. gemini-2.5-flash / claude-haiku-4-5-20251001'),
          const SizedBox(height: 6),
          const Text(
            'Provider dipilih otomatis dari awalan kode: claude- (Anthropic), gemini- (Google), '
            'gpt-/o1-/o3- (OpenAI), grok- (xAI), deepseek-, mistral-, qwen-, kimi-/moonshot-, '
            'minimax-. Masing-masing butuh API key provider tersebut diaktifkan di server.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          _input(_label, 'Nama tampilan'),
          const SizedBox(height: 10),
          _input(_desc, 'Deskripsi (opsional)', maxLines: 2),
          const SizedBox(height: 10),
          Row(children: [
            SizedBox(width: 90, child: _input(_sort, 'Urutan', number: true)),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Pilih model aktif dari daftar setelah menyimpan.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
          ]),
        ]),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Batal')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNavy),
          child: Text(_saving ? '...' : 'Simpan', style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _input(TextEditingController c, String label,
      {int maxLines = 1, bool number = false, bool enabled = true, String? hint}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      enabled: enabled,
      keyboardType: number ? TextInputType.number : null,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 13),
        isDense: true,
        filled: true,
        fillColor: enabled ? AppColors.bgScreen : AppColors.grayBg,
        border: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
