import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

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

  String _formatFileSize(int bytes) {
    if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    final kb = (bytes / 1024).round();
    return '${kb < 1 ? 1 : kb} KB';
  }

  @override
  void initState() {
    super.initState();
    // Default prototype: 15 September 2026
    _tglPenerbitan =
        widget.tglPenerbitan != null &&
            (widget.tglPenerbitan!.year != DateTime.now().year ||
                widget.tglPenerbitan!.month != DateTime.now().month ||
                widget.tglPenerbitan!.day != DateTime.now().day)
        ? widget.tglPenerbitan!
        : DateTime(2026, 9, 15);
    _masaBerlaku =
        widget.masaBerlaku != null &&
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

  static const _klausulaStandar = [
    'Cyber Risk Exclusion Clause - NMA 2915',
    'Industries, Seepage, Pollution and Contamination Clause – NMA 1685 (Sudden and Accidental)',
    'Information Technology Hazards Clarification Clause - NMA 2912',
    'Transmission and Distribution Line Exclusion Clause',
    'Sanction Limitation and Exclusion Clause',
    'War and Civil War Exclusion Clause - NMA 464',
    'Electronic Date Recognition Endorsement A - NMA 2800 11/12/1997',
    'Nuclear Energy Risk Exclusion Clause 1994 - NMA 1975',
    'Terrorism and Sabotage Exclusion Clause',
    'Extra Contractual Obligations Exclusion Endorsement',
    'LMA 5396 Communicable Disease Exclusion Clause',
    'Klausula Risiko Mengendarai Sepeda Motor dan Sejenisnya',
    'Premium Payment Warranty Clause',
  ];

  static const _kondisiStandar = [
    'Klaim wajib dilaporkan kepada Penanggung dalam jangka waktu yang ditentukan dalam polis.',
    'Setiap penambahan atau pengurangan peserta wajib diinformasikan kepada Penanggung.',
    'Premi harus terlebih dahulu dilunasi dengan jatuh tempo sebagaimana yang tercantum dalam polis sebelum pertanggungan aktif berlaku.',
  ];

  static const _warantiStandar = [
    'Tidak melakukan aktivitas/olahraga yang berisiko tinggi.',
    'Tidak melakukan pekerjaan dengan tingkat risiko yang lebih tinggi dari yang telah diinformasikan dan disetujui.',
  ];

  static const _pengecualianStandar = [
    'Perang, kerusuhan, terorisme, dan tindakan permusuhan.',
    'Bunuh diri, percobaan bunuh diri, atau tindakan yang disengaja.',
    'Tindakan melanggar hukum serta pengaruh alkohol atau obat-obatan terlarang.',
    'Olahraga, pekerjaan, atau aktivitas berisiko tinggi yang tidak disetujui Penanggung.',
    'Kematian/Cidera Badan akibat Penyakit/pre-existing condition dan sebab alami.',
    'Pengecualian lainnya yang tercantum dalam polis.',
  ];

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Klausula Card
          _buildKlausulaCard(),
          const SizedBox(height: 14),

          // 2. Kondisi Card
          _buildStandardListCard(
            title: 'Kondisi',
            subtitle: 'Standar, tercantum di lampiran QS',
            items: _kondisiStandar,
          ),
          const SizedBox(height: 14),

          // 3. Waranti Card
          _buildStandardListCard(
            title: 'Waranti',
            subtitle: 'Standar, tercantum di lampiran QS',
            items: _warantiStandar,
          ),
          const SizedBox(height: 14),

          // 4. Pengecualian Card
          _buildStandardListCard(
            title: 'Pengecualian',
            subtitle: 'Standar, tercantum di lampiran QS',
            items: _pengecualianStandar,
          ),
          const SizedBox(height: 14),

          // 5. Penerbitan Card
          _buildPenerbitanCard(),
          const SizedBox(height: 14),

          // 6. Masa Berlaku Penawaran Card
          _buildMasaBerlakuCard(),
          const SizedBox(height: 14),

          // 7. Dokumen Pendukung Card
          _buildDokumenPendukungCard(),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Sections
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildKlausulaCard() {
    return _buildCard([
      Row(
        children: [
          _buildSectionIcon(Icons.format_list_bulleted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Klausula',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_klausulaStandar.length} klausula standar · semua tercentang, tidak dapat diubah',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.blueLightBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_outline, size: 12, color: AppColors.navyMbis),
                SizedBox(width: 4),
                Text(
                  'Terkunci',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navyMbis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      InkWell(
        onTap: () => setState(() => _showKlausula = !_showKlausula),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderDefault, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.format_list_bulleted,
                size: 16,
                color: AppColors.navyMbis,
              ),
              const SizedBox(width: 6),
              Text(
                _showKlausula
                    ? 'Tutup daftar (${_klausulaStandar.length})'
                    : 'Lihat daftar (${_klausulaStandar.length})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navyMbis,
                ),
              ),
            ],
          ),
        ),
      ),
      if (_showKlausula) ...[
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderDivider),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: _klausulaStandar.asMap().entries.map((entry) {
              final isLast = entry.key == _klausulaStandar.length - 1;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgDisabledCard,
                  border: isLast
                      ? null
                      : const Border(
                          bottom: BorderSide(color: AppColors.bgDisabled),
                        ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLockedCheckbox(),
                    const SizedBox(width: 10),
                    Container(
                      width: 22,
                      margin: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${entry.key + 1}.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
      const SizedBox(height: 12),
      const Text(
        'Klausula mengikuti ketentuan standar dan otomatis tercantum di lampiran QS.',
        style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
      ),
    ]);
  }

  Widget _buildStandardListCard({
    required String title,
    required String subtitle,
    required List<String> items,
  }) {
    return _buildCard([
      Row(
        children: [
          _buildSectionIcon(Icons.format_list_bulleted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderDivider),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: items.asMap().entries.map((entry) {
            final isLast = entry.key == items.length - 1;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.bgDisabledCard,
                border: isLast
                    ? null
                    : const Border(
                        bottom: BorderSide(color: AppColors.bgDisabled),
                      ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLockedCheckbox(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    ]);
  }

  Widget _buildPenerbitanCard() {
    return _buildCard([
      Row(
        children: [
          _buildSectionIcon(Icons.edit_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Penerbitan',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'PT Asuransi Kredit Indonesia',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildInputField(
              label: 'Kota',
              controller: widget.kotaCtrl,
              placeholder: 'cth. Padang',
              isRequired: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildDatePickerField(
              label: 'Tanggal',
              value: _tglPenerbitan,
              onChanged: (d) {
                if (d != null) {
                  setState(() => _tglPenerbitan = d);
                  widget.onTglPenerbitanChanged(d);
                }
              },
              placeholder: 'dd/mm/yyyy',
              isRequired: true,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _buildInputField(
        label: 'Cabang',
        controller: widget.cabangCtrl,
        placeholder: 'cth. PADANG',
        isRequired: true,
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildInputField(
              label: 'Penandatangan',
              controller: widget.penandatanganCtrl,
              placeholder: 'Nama',
              isRequired: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildInputField(
              label: 'Jabatan',
              controller: widget.jabatanCtrl,
              placeholder: 'cth. Pemimpin Cabang',
              isRequired: true,
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _buildMasaBerlakuCard() {
    final baseDate = _tglPenerbitan;
    return _buildCard([
      Row(
        children: [
          _buildSectionIcon(Icons.calendar_today_outlined),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Masa Berlaku Penawaran',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _buildDatePickerField(
        label: 'Berlaku sampai dengan',
        value: _masaBerlaku,
        onChanged: (d) {
          if (d != null) {
            setState(() => _masaBerlaku = d);
            widget.onMasaBerlakuChanged(d);
          }
        },
        placeholder: 'dd/mm/yyyy',
        isRequired: true,
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [7, 14].map((days) {
          final target = baseDate.add(Duration(days: days));
          final isSelected =
              _masaBerlaku.year == target.year &&
              _masaBerlaku.month == target.month &&
              _masaBerlaku.day == target.day;

          return InkWell(
            onTap: () {
              setState(() => _masaBerlaku = target);
              widget.onMasaBerlakuChanged(target);
            },
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.blueLightBg : AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected
                      ? AppColors.navyMbis
                      : AppColors.borderDefault,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '+$days hari',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.navyMbis
                          : AppColors.textLabel,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 12),
      const Text(
        'Penawaran bukan bukti bahwa risiko telah dijamin.',
        style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
      ),
    ]);
  }

  Widget _buildDokumenPendukungCard() {
    final activeFileName = _pickedFileName ?? widget.namaFile;

    return _buildCard([
      Row(
        children: [
          _buildSectionIcon(Icons.description_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text.rich(
                  TextSpan(
                    text: 'Dokumen Pendukung ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                    children: [
                      TextSpan(
                        text: '(opsional)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Untuk penerbitan polis dan/atau persetujuan UW. Tidak wajib.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      const Text(
        'KTP Pemegang Polis / PIC',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textLabel,
        ),
      ),
      const SizedBox(height: 8),
      if (activeFileName != null) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.bgUploadSuccess,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderUploadSuccess),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✓ $activeFileName',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _pickedFileSize != null
                          ? _formatFileSize(_pickedFileSize!)
                          : '120 KB',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _pickedFileName = null;
                    _pickedFileSize = null;
                  });
                  widget.onHapusFile?.call();
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.redRequired,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text(
                  'Hapus',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ] else ...[
        InkWell(
          onTap: _handleUploadDocument,
          borderRadius: BorderRadius.circular(12),
          child: CustomPaint(
            painter: DashedRectPainter(
              color: AppColors.borderUploadDashed,
              strokeWidth: 1.5,
              gap: 5.0,
            ),
            child: Container(
              height: 46,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.bgUploadBox,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.keyboard_arrow_up,
                    size: 18,
                    color: AppColors.navyMbis,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Unggah KTP (JPG/PNG/PDF, maks. 5 MB)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyMbis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ]);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Common UI Building Blocks
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildSectionIcon(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.blueLightBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: AppColors.navyMbis),
    );
  }

  Widget _buildLockedCheckbox() {
    return Container(
      width: 22,
      height: 22,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: AppColors.iconCheckMuted,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.iconCheckMuted, width: 1.5),
      ),
      child: const Icon(Icons.check, size: 14, color: AppColors.surfaceWhite),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    bool isRequired = false,
  }) {
    return FormField<String>(
      initialValue: controller.text,
      validator: isRequired
          ? (_) => controller.text.trim().isEmpty ? 'Wajib diisi' : null
          : null,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLabel,
                ),
                children: isRequired
                    ? const [
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: AppColors.redRequired,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: field.hasError
                      ? AppColors.redRequired
                      : AppColors.borderDefault,
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: controller,
                onChanged: (val) {
                  field.didChange(val);
                },
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blueInputText,
                ),
                cursorColor: AppColors.orangeMbis,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  hintText: placeholder,
                  hintStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.normal,
                    color: AppColors.textPlaceholder,
                  ),
                ),
              ),
            ),
            if (field.hasError) ...[
              const SizedBox(height: 4),
              Text(
                field.errorText!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.redRequired,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
    required String placeholder,
    bool isRequired = false,
  }) {
    return FormField<DateTime>(
      key: ValueKey(value),
      initialValue: value,
      validator: isRequired
          ? (_) => value == null ? 'Wajib diisi' : null
          : null,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLabel,
                ),
                children: isRequired
                    ? const [
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: AppColors.redRequired,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: value ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: Theme.of(
                        ctx,
                      ).colorScheme.copyWith(primary: AppColors.navyMbis),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  onChanged(picked);
                  field.didChange(picked);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: field.hasError
                        ? AppColors.redRequired
                        : AppColors.borderDefault,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value != null
                            ? '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}'
                            : placeholder,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: value != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: value != null
                              ? AppColors.blueInputText
                              : AppColors.textPlaceholder,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: AppColors.iconDropdown,
                    ),
                  ],
                ),
              ),
            ),
            if (field.hasError) ...[
              const SizedBox(height: 4),
              Text(
                field.errorText!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.redRequired,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
