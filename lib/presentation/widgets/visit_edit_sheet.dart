import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../src/visit/visit_repository.dart';
import 'field_label.dart';

/// Formulir perbaikan catatan kunjungan yang sudah tersimpan.
///
/// Hanya tiga hal yang bisa diubah: deskripsi aktivitas, rencana tindak lanjut,
/// dan tanggal follow-up. **Tag lokasi dan foto sengaja tidak ada di sini** —
/// keduanya bukan catatan melainkan bukti bahwa RM benar-benar berada di tempat
/// itu pada saat itu, dan kehilangan seluruh nilainya begitu bisa diganti
/// setelah fakta. Sheet ini menyebutkannya terang-terangan supaya pemakai tidak
/// mengira tombolnya lupa dipasang.
///
/// Mengembalikan [VisitModel] hasil simpan, atau null bila dibatalkan.
Future<VisitModel?> showVisitEditSheet(
  BuildContext context,
  VisitRepository repo,
  VisitModel visit,
) {
  return showModalBottomSheet<VisitModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _VisitEditSheet(repo: repo, visit: visit),
  );
}

class _VisitEditSheet extends StatefulWidget {
  const _VisitEditSheet({required this.repo, required this.visit});

  final VisitRepository repo;
  final VisitModel visit;

  @override
  State<_VisitEditSheet> createState() => _VisitEditSheetState();
}

class _VisitEditSheetState extends State<_VisitEditSheet> {
  /// schedules.action_plan = varchar(255); backend menolak yang lebih panjang.
  static const int _maxActionPlan = 255;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _notes;
  late final TextEditingController _actionPlan;
  DateTime? _tanggal;
  TimeOfDay? _jam;
  bool _saving = false;
  String? _followUpError;

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController(text: widget.visit.notes ?? '');
    _actionPlan = TextEditingController(text: widget.visit.actionPlan ?? '');
    final followup = widget.visit.nextFollowupDate;
    // Backend mengirim waktu lokal polos ("2026-08-20T14:30"), jadi DateTime.parse
    // menghasilkan waktu dinding yang sama — tanpa konversi zona.
    final parsed = followup != null ? DateTime.tryParse(followup) : null;
    if (parsed != null) {
      _tanggal = DateTime(parsed.year, parsed.month, parsed.day);
      _jam = TimeOfDay(hour: parsed.hour, minute: parsed.minute);
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    _actionPlan.dispose();
    super.dispose();
  }

  /// Tanggal dan jam harus lengkap atau kosong dua-duanya: tanggal tanpa jam
  /// tidak bisa jadi jadwal yang bisa dihitung mundur oleh pengingat, dan jam
  /// tanpa tanggal akan dibuang diam-diam. Sama dengan aturan di layar catat.
  bool get _followUpIncomplete => (_tanggal == null) != (_jam == null);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    // Kunjungan lama bisa punya follow-up yang tanggalnya sudah lewat. Kalau
    // firstDate dipatok "hari ini" seperti di layar catat, tanggal tersimpan itu
    // berada di luar rentang dan picker melempar assert.
    final earliest = _tanggal != null && _tanggal!.isBefore(now) ? _tanggal! : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal ?? now,
      firstDate: DateTime(earliest.year, earliest.month, earliest.day),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _tanggal = picked;
        _followUpError = null;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _jam ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _jam = picked;
        _followUpError = null;
      });
    }
  }

  void _clearFollowUp() => setState(() {
        _tanggal = null;
        _jam = null;
        _followUpError = null;
      });

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_followUpIncomplete) {
      setState(() => _followUpError = 'Isi tanggal dan jam, atau kosongkan keduanya');
      return;
    }

    // Waktu dinding lokal tanpa offset — konvensi yang dipakai endpoint kunjungan
    // (berbeda dari endpoint jadwal yang justru minta UTC).
    String? followupIso;
    if (_tanggal != null && _jam != null) {
      followupIso = DateTime(
        _tanggal!.year,
        _tanggal!.month,
        _tanggal!.day,
        _jam!.hour,
        _jam!.minute,
      ).toIso8601String();
    }

    setState(() => _saving = true);
    try {
      final updated = await widget.repo.updateVisit(
        visitId: widget.visit.id,
        notes: _notes.text.trim(),
        nextFollowupDate: followupIso,
        actionPlan: _actionPlan.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.errorRed,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final followUpLabel = _tanggal == null
        ? 'Pilih tanggal'
        : '${_tanggal!.day}/${_tanggal!.month}/${_tanggal!.year}';
    final jamLabel = _jam == null ? 'Pilih jam' : _jam!.format(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit Aktivitas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'Tag lokasi, foto, jenis, dan waktu kejadian tidak bisa diubah — '
                'keempatnya bukti kunjungan.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              fieldLabel('Deskripsi Aktivitas'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notes,
                maxLines: 4,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Hasil pembicaraan, kebutuhan nasabah, dsb.',
                  hintStyle:
                      const TextStyle(fontSize: 13, color: AppColors.grayStage),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
                ),
              ),
              const SizedBox(height: 12),
              fieldLabel('Rencana Tindak Lanjut'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _actionPlan,
                maxLength: _maxActionPlan,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'mis. kirim penawaran revisi',
                  hintStyle:
                      const TextStyle(fontSize: 13, color: AppColors.grayStage),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
                ),
              ),
              const SizedBox(height: 4),
              fieldLabel('Follow Up'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _pickDate,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(followUpLabel,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _pickTime,
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text(jamLabel,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
              if (_tanggal != null || _jam != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _saving ? null : _clearFollowUp,
                    icon: const Icon(Icons.close, size: 15),
                    label: const Text('Hapus follow-up',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
              if (_followUpError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_followUpError!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.errorRed)),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
