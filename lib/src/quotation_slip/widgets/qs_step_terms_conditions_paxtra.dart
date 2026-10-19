import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import 'terms_conditions/paxtra_deductible_card.dart';
import 'terms_conditions/paxtra_klausula_card.dart';
import 'terms_conditions/paxtra_tambahan_section_card.dart';
import 'terms_conditions/qs_tc_constants.dart';
import 'terms_conditions/qs_tc_dokumen_pendukung_card.dart';
import 'terms_conditions/qs_tc_masa_berlaku_card.dart';
import 'terms_conditions/qs_tc_penerbitan_card.dart';

/// Tab 3 – Terms & Conditions, Penerbitan, Dokumen Pendukung khusus produk PA Xtra.
class QsStepTermsConditionsPaXtra extends StatefulWidget {
  final GlobalKey<FormState> formKey;

  // Penerbitan
  final TextEditingController kotaCtrl;
  final TextEditingController cabangCtrl;
  final TextEditingController penandatanganCtrl;
  final TextEditingController jabatanCtrl;
  final DateTime? tglPenerbitan;
  final ValueChanged<DateTime?> onTglPenerbitanChanged;

  // Masa berlaku
  final DateTime? masaBerlaku;
  final ValueChanged<DateTime?> onMasaBerlakuChanged;

  // PA Xtra T/C tambahan
  final TextEditingController klausulTambahanCtrl;
  final TextEditingController kondisiTambahanCtrl;
  final TextEditingController warantiTambahanCtrl;
  final TextEditingController pengecualianTambahanCtrl;
  final TextEditingController deductibleCtrl;

  // Dokumen
  final String? namaFile;
  final VoidCallback onPilihFile;
  final VoidCallback? onHapusFile;

  const QsStepTermsConditionsPaXtra({
    super.key,
    required this.formKey,
    required this.kotaCtrl,
    required this.cabangCtrl,
    required this.penandatanganCtrl,
    required this.jabatanCtrl,
    required this.tglPenerbitan,
    required this.onTglPenerbitanChanged,
    required this.masaBerlaku,
    required this.onMasaBerlakuChanged,
    required this.klausulTambahanCtrl,
    required this.kondisiTambahanCtrl,
    required this.warantiTambahanCtrl,
    required this.pengecualianTambahanCtrl,
    required this.deductibleCtrl,
    required this.namaFile,
    required this.onPilihFile,
    required this.onHapusFile,
  });

  @override
  State<QsStepTermsConditionsPaXtra> createState() =>
      _QsStepTermsConditionsPaXtraState();
}

class _QsStepTermsConditionsPaXtraState
    extends State<QsStepTermsConditionsPaXtra> {
  bool _showKlausula = false;

  final _draftKlausulCtrl = TextEditingController();
  final _draftKondisiCtrl = TextEditingController();
  final _draftWarantiCtrl = TextEditingController();
  final _draftPengecualianCtrl = TextEditingController();

  late DateTime _tglPenerbitan;
  late DateTime _masaBerlaku;

  String? _pickedFileName;
  int? _pickedFileSize;
  Uint8List? _pickedFileBytes;
  String? _pickedFilePath;

  List<String> _klausulTambahanList = [];
  List<String> _kondisiTambahanList = [];
  List<String> _warantiTambahanList = [];
  List<String> _pengecualianTambahanList = [];

  Future<void> _handleUploadDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      const maxSizeBytes = 5 * 1024 * 1024; // 5 MB

      if (file.size > maxSizeBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Ukuran file melebihi batas maksimal 5 MB. Silakan pilih file lain.',
              ),
              backgroundColor: AppColors.redRequired,
            ),
          );
        }
        return;
      }

      setState(() {
        _pickedFileName = file.name;
        _pickedFileSize = file.size;
        _pickedFileBytes = file.bytes;
        _pickedFilePath = file.path;
      });

      widget.onPilihFile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih dokumen: $e'),
            backgroundColor: AppColors.redRequired,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initListsFromControllers();

    // Default prototype: 15 September 2026
    _tglPenerbitan = widget.tglPenerbitan != null &&
            (widget.tglPenerbitan!.year != DateTime.now().year ||
                widget.tglPenerbitan!.month != DateTime.now().month ||
                widget.tglPenerbitan!.day != DateTime.now().day)
        ? widget.tglPenerbitan!
        : DateTime(2026, 9, 15);
    _masaBerlaku = widget.masaBerlaku != null &&
            (widget.masaBerlaku!.year != DateTime.now().year ||
                widget.masaBerlaku!.month != DateTime.now().month ||
                widget.masaBerlaku!.day != DateTime.now().day)
        ? widget.masaBerlaku!
        : DateTime(2026, 9, 29);

    if (widget.kotaCtrl.text.isEmpty) {
      widget.kotaCtrl.text = 'Padang';
    }
    if (widget.cabangCtrl.text.isEmpty) {
      widget.cabangCtrl.text = 'PADANG';
    }
    if (widget.penandatanganCtrl.text.isEmpty) {
      widget.penandatanganCtrl.text = 'Sarno';
    }
    if (widget.jabatanCtrl.text.isEmpty) {
      widget.jabatanCtrl.text = 'Pemimpin Cabang';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onTglPenerbitanChanged(_tglPenerbitan);
      widget.onMasaBerlakuChanged(_masaBerlaku);
    });
  }

  @override
  void didUpdateWidget(covariant QsStepTermsConditionsPaXtra oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tglPenerbitan != null &&
        widget.tglPenerbitan != oldWidget.tglPenerbitan) {
      _tglPenerbitan = widget.tglPenerbitan!;
    }
    if (widget.masaBerlaku != null &&
        widget.masaBerlaku != oldWidget.masaBerlaku) {
      _masaBerlaku = widget.masaBerlaku!;
    }
  }

  void _initListsFromControllers() {
    if (widget.klausulTambahanCtrl.text.trim().isNotEmpty) {
      _klausulTambahanList = widget.klausulTambahanCtrl.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (widget.kondisiTambahanCtrl.text.trim().isNotEmpty) {
      _kondisiTambahanList = widget.kondisiTambahanCtrl.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (widget.warantiTambahanCtrl.text.trim().isNotEmpty) {
      _warantiTambahanList = widget.warantiTambahanCtrl.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (widget.pengecualianTambahanCtrl.text.trim().isNotEmpty) {
      _pengecualianTambahanList = widget.pengecualianTambahanCtrl.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
  }

  void _syncController(TextEditingController ctrl, List<String> list) {
    ctrl.text = list.join('\n');
    setState(() {});
  }

  @override
  void dispose() {
    _draftKlausulCtrl.dispose();
    _draftKondisiCtrl.dispose();
    _draftWarantiCtrl.dispose();
    _draftPengecualianCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeFileName = _pickedFileName ?? widget.namaFile;

    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Deductible Card
          PaXtraDeductibleCard(
            deductibleCtrl: widget.deductibleCtrl,
          ),
          const SizedBox(height: 14),

          // 2. Klausula Card & Tambahan
          PaXtraKlausulaCard(
            standardKlausula: kPaxtraKlausulaStandar,
            isExpanded: _showKlausula,
            onToggleExpand: () =>
                setState(() => _showKlausula = !_showKlausula),
            klausulTambahanList: _klausulTambahanList,
            draftKlausulCtrl: _draftKlausulCtrl,
            onAddKlausul: () {
              final text = _draftKlausulCtrl.text.trim();
              if (text.isNotEmpty) {
                _klausulTambahanList.add(text);
                _draftKlausulCtrl.clear();
                _syncController(
                    widget.klausulTambahanCtrl, _klausulTambahanList);
              }
            },
            onRemoveKlausul: (idx) {
              _klausulTambahanList.removeAt(idx);
              _syncController(
                  widget.klausulTambahanCtrl, _klausulTambahanList);
            },
          ),
          const SizedBox(height: 14),

          // 3. Kondisi Card & Tambahan
          PaXtraTambahanSectionCard(
            title: 'Kondisi',
            subtitle: 'Standar tercentang & terkunci · tambahan boleh diisi',
            standardItems: kPaxtraKondisiStandar,
            tambahanTitle: 'Pilihan Kondisi Tambahan',
            draftPlaceholder: 'Tulis tambahan…',
            draftCtrl: _draftKondisiCtrl,
            items: _kondisiTambahanList,
            onAdd: () {
              final text = _draftKondisiCtrl.text.trim();
              if (text.isNotEmpty) {
                _kondisiTambahanList.add(text);
                _draftKondisiCtrl.clear();
                _syncController(
                    widget.kondisiTambahanCtrl, _kondisiTambahanList);
              }
            },
            onRemove: (idx) {
              _kondisiTambahanList.removeAt(idx);
              _syncController(
                  widget.kondisiTambahanCtrl, _kondisiTambahanList);
            },
          ),
          const SizedBox(height: 14),

          // 4. Waranti Card & Tambahan
          PaXtraTambahanSectionCard(
            title: 'Waranti',
            subtitle: 'Standar tercentang & terkunci · tambahan boleh diisi',
            standardItems: kPaxtraWarantiStandar,
            tambahanTitle: 'Pilihan Waranti Tambahan',
            draftPlaceholder: 'Tulis tambahan…',
            draftCtrl: _draftWarantiCtrl,
            items: _warantiTambahanList,
            onAdd: () {
              final text = _draftWarantiCtrl.text.trim();
              if (text.isNotEmpty) {
                _warantiTambahanList.add(text);
                _draftWarantiCtrl.clear();
                _syncController(
                    widget.warantiTambahanCtrl, _warantiTambahanList);
              }
            },
            onRemove: (idx) {
              _warantiTambahanList.removeAt(idx);
              _syncController(
                  widget.warantiTambahanCtrl, _warantiTambahanList);
            },
          ),
          const SizedBox(height: 14),

          // 5. Pengecualian Card & Tambahan
          PaXtraTambahanSectionCard(
            title: 'Pengecualian',
            subtitle: 'Standar tercentang & terkunci · tambahan boleh diisi',
            standardItems: kPaxtraPengecualianStandar,
            tambahanTitle: 'Pilihan Pengecualian Tambahan',
            draftPlaceholder: 'Tulis tambahan…',
            draftCtrl: _draftPengecualianCtrl,
            items: _pengecualianTambahanList,
            onAdd: () {
              final text = _draftPengecualianCtrl.text.trim();
              if (text.isNotEmpty) {
                _pengecualianTambahanList.add(text);
                _draftPengecualianCtrl.clear();
                _syncController(widget.pengecualianTambahanCtrl,
                    _pengecualianTambahanList);
              }
            },
            onRemove: (idx) {
              _pengecualianTambahanList.removeAt(idx);
              _syncController(widget.pengecualianTambahanCtrl,
                  _pengecualianTambahanList);
            },
          ),
          const SizedBox(height: 14),

          // 6. Penerbitan Card
          QsTcPenerbitanCard(
            kotaCtrl: widget.kotaCtrl,
            tglPenerbitan: _tglPenerbitan,
            onTglPenerbitanChanged: (d) {
              setState(() => _tglPenerbitan = d);
              widget.onTglPenerbitanChanged(d);
            },
            cabangCtrl: widget.cabangCtrl,
            penandatanganCtrl: widget.penandatanganCtrl,
            jabatanCtrl: widget.jabatanCtrl,
          ),
          const SizedBox(height: 14),

          // 7. Masa Berlaku Penawaran Card
          QsTcMasaBerlakuCard(
            masaBerlaku: _masaBerlaku,
            baseDate: _tglPenerbitan,
            onMasaBerlakuChanged: (d) {
              setState(() => _masaBerlaku = d);
              widget.onMasaBerlakuChanged(d);
            },
            quickDays: const [7, 14],
          ),
          const SizedBox(height: 14),

          // 8. Dokumen Pendukung Card
          QsTcDokumenPendukungCard(
            activeFileName: activeFileName,
            activeFileSize: _pickedFileSize,
            activeFileBytes: _pickedFileBytes,
            activeFilePath: _pickedFilePath,
            onUploadDocument: _handleUploadDocument,
            onHapusDocument: () {
              setState(() {
                _pickedFileName = null;
                _pickedFileSize = null;
                _pickedFileBytes = null;
                _pickedFilePath = null;
              });
              widget.onHapusFile?.call();
            },
          ),
        ],
      ),
    );
  }
}
