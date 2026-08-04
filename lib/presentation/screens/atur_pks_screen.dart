import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../utils/input_formatters.dart';
import '../../src/agent/agent_repository.dart';
import '../../core/providers/repository_providers.dart';
import '../widgets/back_app_bar.dart';
import '../widgets/field_label.dart';
import '../widgets/missing_fields_notice.dart';

/// Form "Atur PKS": nomor + periode PKS + **rate komisi per grup** (LOB / Asuransi
/// Mikro). Semua rate wajib diisi (persen). Angka ini jadi sumber utama perhitungan
/// komisi agen (per grup produk deal) di backend.
class AturPksScreen extends ConsumerStatefulWidget {
  final AgentModel agent;
  const AturPksScreen({super.key, required this.agent});

  @override
  ConsumerState<AturPksScreen> createState() => _AturPksScreenState();
}

class _AturPksScreenState extends ConsumerState<AturPksScreen> {
  final _numberCtrl = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  List<CommissionGroupModel> _groups = const [];
  final Map<String, TextEditingController> _rateCtrls = {};

  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  AutovalidateMode _autoval = AutovalidateMode.disabled;

  AgentRepository get _repo => ref.read(agentRepoProvider);

  @override
  void initState() {
    super.initState();
    _numberCtrl.text = widget.agent.pksNumber;
    _start = DateTime.tryParse(widget.agent.pksStart);
    _end = DateTime.tryParse(widget.agent.pksEnd);
    _load();
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    for (final c in _rateCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final groups = await _repo.getCommissionGroups();
      final rates = await _repo.getCommissionRates(widget.agent.id);
      for (final g in groups) {
        _rateCtrls[g.code] = TextEditingController(text: _pctText(rates[g.code]));
      }
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  /// Pecahan (0.15) → teks persen ("15").
  String _pctText(double? frac) {
    if (frac == null) return '';
    final p = (frac * 10000).round() / 100;
    return p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toString();
  }

  String? _iso(DateTime? d) => d == null
      ? null
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _start : _end) ?? now,
      firstDate: DateTime(2015),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => isStart ? _start = picked : _end = picked);
  }

  Future<void> _save() async {
    setState(() => _autoval = AutovalidateMode.onUserInteraction);
    final messenger = ScaffoldMessenger.of(context);
    final missing = <String>[];
    if (_numberCtrl.text.trim().isEmpty) missing.add('Nomor PKS');

    final groupRates = <Map<String, dynamic>>[];
    for (final g in _groups) {
      final txt = _rateCtrls[g.code]!.text.trim();
      final pct = double.tryParse(txt);
      if (txt.isEmpty || pct == null) {
        missing.add('Rate ${g.name}');
        continue;
      }
      if (pct < 0 || pct > 100) {
        missing.add('Rate ${g.name} (0–100)');
        continue;
      }
      groupRates.add({'groupCode': g.code, 'groupName': g.name, 'rate': pct / 100});
    }

    if (missing.isNotEmpty) {
      showMissingFieldsNotice(messenger, missing);
      return;
    }

    setState(() => _saving = true);
    try {
      await _repo.setPks(
        widget.agent.id,
        pksNumber: _numberCtrl.text.trim(),
        pksStart: _iso(_start),
        pksEnd: _iso(_end),
        groupRates: groupRates,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      messenger.showSnackBar(const SnackBar(
        content: Text('PKS & rate komisi tersimpan.'),
        backgroundColor: AppColors.successGreen,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: const BackAppBar(title: 'Atur PKS'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _errorView()
              : _form(),
      bottomNavigationBar: (_loading || _loadError != null) ? null : _saveBar(),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_loadError!, textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => setState(() {
                _loading = true;
                _loadError = null;
                _load();
              }),
              child: const Text('Coba lagi'),
            ),
          ]),
        ),
      );

  Widget _form() {
    // Kelompokkan grup rate berdasar COB agar rapi.
    final byCob = <String, List<CommissionGroupModel>>{};
    for (final g in _groups) {
      byCob.putIfAbsent(g.cobName, () => []).add(g);
    }
    return Form(
      autovalidateMode: _autoval,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _sectionCard('Informasi PKS', [
            fieldLabel('Nomor PKS *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _numberCtrl,
              style: AppInput.fieldText,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              decoration: _dec(hint: 'mis. PKS/2026/001'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _dateBtn('Mulai', _start, () => _pickDate(true))),
              const SizedBox(width: 10),
              Expanded(child: _dateBtn('Selesai', _end, () => _pickDate(false))),
            ]),
          ]),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 6),
            child: Text('Rate Komisi per Produk (sesuai PKS)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Semua wajib diisi (persen). Nilai ini dipakai menghitung komisi agen per produk.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ),
          for (final entry in byCob.entries)
            _sectionCard(entry.key, [
              for (int i = 0; i < entry.value.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _rateField(entry.value[i]),
              ],
            ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _rateField(CommissionGroupModel g) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      fieldLabel('${g.name} *'),
      const SizedBox(height: 6),
      TextFormField(
        controller: _rateCtrls[g.code],
        style: AppInput.fieldText,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: const [DecimalInputFormatter()],
        validator: (v) {
          final s = (v ?? '').trim();
          if (s.isEmpty) return 'Wajib diisi';
          final p = double.tryParse(s);
          if (p == null) return 'Angka tidak valid';
          if (p < 0 || p > 100) return '0–100';
          return null;
        },
        decoration: _dec(hint: 'mis. 15', suffixText: '%'),
      ),
    ]);
  }

  Widget _dateBtn(String label, DateTime? d, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
        alignment: Alignment.centerLeft,
      ),
      child: Text('$label: ${d == null ? '—' : _iso(d)}',
          style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  InputDecoration _dec({String? hint, String? suffixText}) => InputDecoration(
        hintText: hint,
        suffixText: suffixText,
        isDense: true,
        filled: true,
        fillColor: AppColors.bgScreen,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.radiusMd, borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: AppRadius.radiusMd, borderSide: const BorderSide(color: AppColors.primaryNavy, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: AppRadius.radiusMd, borderSide: const BorderSide(color: AppColors.errorRed)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: AppRadius.radiusMd, borderSide: const BorderSide(color: AppColors.errorRed, width: 1.5)),
      );

  Widget _saveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 10, AppSpacing.lg, 16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
            ),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                : const Text('Simpan PKS', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
