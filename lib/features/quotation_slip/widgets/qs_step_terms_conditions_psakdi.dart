import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import 'terms_conditions/qs_tc_constants.dart';
import 'terms_conditions/qs_tc_dokumen_pendukung_card.dart';
import 'terms_conditions/qs_tc_klausula_card.dart';
import 'terms_conditions/qs_tc_masa_berlaku_card.dart';
import 'terms_conditions/qs_tc_penerbitan_card.dart';
import 'terms_conditions/qs_tc_standard_list_card.dart';

/// Tab 3 – Terms & Conditions, Penerbitan, Dokumen Pendukung khusus produk PSAKDI.
/// 100% identik dengan prototype Web (Prototype_QS_M-BIS.html).
class QsStepTermsConditionsPsakdi extends StatefulWidget {
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

  // Dokumen
  final String? namaFile;
  final VoidCallback onPilihFile;
  final VoidCallback? onHapusFile;

  const QsStepTermsConditionsPsakdi({
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
    required this.namaFile,
    required this.onPilihFile,
    required this.onHapusFile,
  });

  @override
  State<QsStepTermsConditionsPsakdi> createState() =>
      _QsStepTermsConditionsPsakdiState();
}

class _QsStepTermsConditionsPsakdiState
    extends State<QsStepTermsConditionsPsakdi> {
  bool _showKlausula = false;

  late DateTime _tglPenerbitan;
  late DateTime _masaBerlaku;

  String? _pickedFileName;
  int? _pickedFileSize;
  Uint8List? _pickedFileBytes;
  String? _pickedFilePath;

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
    // Default prototype: 15 September 2026
    _tglPenerbitan = widget.tglPenerbitan ?? DateTime.now();
    _masaBerlaku = widget.masaBerlaku ?? DateTime.now().add(const Duration(days: 14));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onTglPenerbitanChanged(_tglPenerbitan);
      widget.onMasaBerlakuChanged(_masaBerlaku);
    });
  }

  @override
  void didUpdateWidget(covariant QsStepTermsConditionsPsakdi oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    final activeFileName = _pickedFileName ?? widget.namaFile;

    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Klausula Card
          QsTcKlausulaCard(
            klausulaList: kPsakdiKlausulaStandar,
            isExpanded: _showKlausula,
            onToggleExpand: () => setState(() => _showKlausula = !_showKlausula),
          ),
          const SizedBox(height: 14),

          // 2. Kondisi Card
          const QsTcStandardListCard(
            title: 'Kondisi',
            subtitle: 'Standar, tercantum di lampiran QS',
            items: kPsakdiKondisiStandar,
          ),
          const SizedBox(height: 14),

          // 3. Waranti Card
          const QsTcStandardListCard(
            title: 'Waranti',
            subtitle: 'Standar, tercantum di lampiran QS',
            items: kPsakdiWarantiStandar,
          ),
          const SizedBox(height: 14),

          // 4. Pengecualian Card
          const QsTcStandardListCard(
            title: 'Pengecualian',
            subtitle: 'Standar, tercantum di lampiran QS',
            items: kPsakdiPengecualianStandar,
          ),
          const SizedBox(height: 14),

          // 5. Penerbitan Card
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

          // 6. Masa Berlaku Penawaran Card
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

          // 7. Dokumen Pendukung Card
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
