import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../common/qs_section_card.dart';
import '../../../../theme/app_theme.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../qs_form_state.dart';
import 'repositories/pekerjaan_repository.dart';
import 'qs_pertanggungan_fields.dart';

/// Card Section 5: Orang yang Dipertanggungkan
class QsTertanggungCard extends ConsumerStatefulWidget {
  final QsProduct product;
  final QsType type;
  final bool dataSamaPolis;
  final ValueChanged<bool> onDataSamaPolisChanged;
  final String namaPolis;
  final TextEditingController namaTertanggungCtrl;
  final TextEditingController noKtpCtrl;
  final DateTime? tglLahir;
  final ValueChanged<DateTime?> onTglLahirChanged;
  final TextEditingController tglLahirGroupCtrl;
  final DateTime refDate;
  final String? usiaError;
  final TextEditingController pekerjaanCtrl;
  final ValueChanged<String> onPekerjaanChanged;
  final int? saranKelas;
  final int? klasifikasiPeserta;
  final ValueChanged<int?> onKlasifikasiChanged;
  final VoidCallback? onFieldChanged;
  final PekerjaanController? pekerjaanController;


  const QsTertanggungCard({
    super.key,
    required this.product,
    required this.type,
    required this.dataSamaPolis,
    required this.onDataSamaPolisChanged,
    required this.namaPolis,
    required this.namaTertanggungCtrl,
    required this.noKtpCtrl,
    required this.tglLahir,
    required this.onTglLahirChanged,
    required this.tglLahirGroupCtrl,
    required this.refDate,
    required this.usiaError,
    required this.pekerjaanCtrl,
    required this.onPekerjaanChanged,
    required this.saranKelas,
    required this.klasifikasiPeserta,
    required this.onKlasifikasiChanged,
    this.onFieldChanged,
    this.pekerjaanController,
  });

  @override
  ConsumerState<QsTertanggungCard> createState() => _QsTertanggungCardState();
}

class _QsTertanggungCardState extends ConsumerState<QsTertanggungCard> {
  late final PekerjaanController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.pekerjaanController != null) {
      _controller = widget.pekerjaanController!;
      _ownsController = false;
    } else {
      _controller = PekerjaanController(
        repository: ref.read(pekerjaanRepoProvider),
      );
      _ownsController = true;
    }
    // Langsung get dari API setiap kali card/layar dibuka
    _controller.loadPekerjaan();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final type = widget.type;
    final dataSamaPolis = widget.dataSamaPolis;
    final onDataSamaPolisChanged = widget.onDataSamaPolisChanged;
    final namaPolis = widget.namaPolis;
    final namaTertanggungCtrl = widget.namaTertanggungCtrl;
    final noKtpCtrl = widget.noKtpCtrl;
    final tglLahir = widget.tglLahir;
    final onTglLahirChanged = widget.onTglLahirChanged;
    final tglLahirGroupCtrl = widget.tglLahirGroupCtrl;
    final refDate = widget.refDate;
    final usiaError = widget.usiaError;
    final pekerjaanCtrl = widget.pekerjaanCtrl;
    final onPekerjaanChanged = widget.onPekerjaanChanged;
    final saranKelas = widget.saranKelas;
    final klasifikasiPeserta = widget.klasifikasiPeserta;
    final onKlasifikasiChanged = widget.onKlasifikasiChanged;
    final onFieldChanged = widget.onFieldChanged;
    final isSingle = type == QsType.single;

    return QsSectionCard(
      icon: Icons.person_outline,
      title: 'Orang yang Dipertanggungkan',
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Data orang yang dipertanggungkan sama dengan Pemegang Polis?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLabel,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                QsPillButton(
                  label: 'Ya',
                  isSelected: dataSamaPolis,
                  activeColor: AppColors.greenTotal,
                  onTap: () {
                    onDataSamaPolisChanged(true);
                    if (namaPolis.isNotEmpty) {
                      namaTertanggungCtrl.text = namaPolis;
                    }
                    onFieldChanged?.call();
                  },
                ),
                const SizedBox(width: 6),
                QsPillButton(
                  label: 'Tidak',
                  isSelected: !dataSamaPolis,
                  activeColor: AppColors.redRequired,
                  onTap: () {
                    onDataSamaPolisChanged(false);
                    onFieldChanged?.call();
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        QsTextInputField(
          label: isSingle ? 'Nama' : 'Nama / Kelompok Peserta',
          required: true,
          controller: namaTertanggungCtrl,
          placeholder:
              isSingle ? 'Nama sesuai KTP' : 'mis. Karyawan/wati, Siswa/Siswi',
          onChanged: (_) => onFieldChanged?.call(),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
        ),
        QsTextInputField(
          label: 'Nomor KTP (NIK)',
          required: isSingle,
          controller: noKtpCtrl,
          placeholder: '16 digit NIK',
          keyboardType: isSingle ? TextInputType.number : TextInputType.text,
          maxLength: isSingle ? 16 : null,
          onChanged: (_) => onFieldChanged?.call(),
          validator: (v) {
            if (isSingle) {
              if (v == null || v.trim().isEmpty) return 'Wajib diisi';
            }
            return null;
          },
        ),
        Builder(builder: (context) {
          final len = noKtpCtrl.text.length;
          final isWarning = isSingle && len > 0 && len != 16;
          return Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: Text(
              !isSingle
                  ? 'Untuk Group boleh diisi TBA atau -'
                  : '$len/16 digit${isWarning ? ' · NIK umumnya 16 digit, mohon cek kembali' : ''}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: !isSingle
                    ? AppColors.textMuted
                    : (isWarning ? AppColors.warningNik : AppColors.textMuted),
              ),
            ),
          );
        }),
        if (isSingle) ...[
          QsDatePickerField(
            label: 'Tanggal Lahir',
            required: true,
            value: tglLahir,
            onChanged: (d) {
              onTglLahirChanged(d);
              onFieldChanged?.call();
            },
          ),
          if (tglLahir != null) ...[
            Builder(builder: (context) {
              final lahir = tglLahir;
              int totalMonths = (refDate.year - lahir.year) * 12 +
                  (refDate.month - lahir.month);
              if (refDate.day < lahir.day) totalMonths--;
              final y = totalMonths ~/ 12;
              final r = (totalMonths % 12 + 12) % 12;
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Usia $y tahun $r bulan pada tanggal mulai pertanggungan',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              );
            }),
          ],
          if (usiaError != null) ...[
            const SizedBox(height: 4),
            Text(
              usiaError,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.redRequired,
              ),
            ),
          ],
        ] else ...[
          QsTextInputField(
            label: 'Tanggal Lahir',
            required: false,
            controller: tglLahirGroupCtrl,
            placeholder: 'TBA',
          ),
          const Padding(
            padding: EdgeInsets.only(top: 2, bottom: 8),
            child: Text(
              'Untuk Group boleh diisi TBA atau -',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            QsLabelText('Pekerjaan', required: isSingle),
            const SizedBox(height: 6),
            TextFormField(
              controller: pekerjaanCtrl,
              cursorColor: AppColors.orangeMbis,
              onChanged: (v) {
                onPekerjaanChanged(v);
                onFieldChanged?.call();
              },
              validator: (v) {
                if (isSingle) {
                  if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                }
                return null;
              },
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.blueInputText,
              ),
              decoration: InputDecoration(
                hintText: 'Pilih atau ketik pekerjaan',
                counterText: '',
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPlaceholder,
                  fontWeight: FontWeight.w400,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.borderDefault, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.borderDefault, width: 1.5),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide:
                      BorderSide(color: AppColors.orangeMbis, width: 2.0),
                ),
                errorBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide:
                      BorderSide(color: AppColors.redRequired, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                // 1. Loading State (Shimmer Skeletonizer)
                if (_controller.isLoading) {
                  return const _PekerjaanSkeletonChips();
                }

                // 2. Negative Case (Error / Gagal Memuat)
                if (_controller.hasError) {
                  return Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.errorBannerBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.errorBannerBorder,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 16,
                          color: AppColors.redRequired,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _controller.error ?? 'Gagal memuat pekerjaan',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.errorBannerText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _controller.loadPekerjaan(),
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.refresh,
                                  size: 14,
                                  color: AppColors.orangeMbis,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Coba lagi',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.orangeMbis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // 3. Empty State (tidak ada item dari response API)
                if (_controller.items.isEmpty) {
                  return const SizedBox.shrink();
                }

                // 4. Success State (Render Chips dari API)
                final chKerja = _controller.items;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: chKerja.map((chip) {
                    final isSel = pekerjaanCtrl.text == chip;
                    return QsQuickChip(
                      label: chip,
                      isSelected: isSel,
                      onTap: () {
                        pekerjaanCtrl.text = chip;
                        onPekerjaanChanged(chip);
                        onFieldChanged?.call();
                      },
                    );
                  }).toList(),
                );
              },
            ),
            if (saranKelas == 4) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.errorBannerBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.errorBannerBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 18, color: AppColors.redRequired),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Harap ajukan secara manual',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.errorBannerTitle,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pekerjaan “${pekerjaanCtrl.text}” termasuk Kelas 4 (pekerjaan berat & berbahaya). QS tidak dapat dilanjutkan walaupun perhitungan Mutlak/Flat.',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.errorBannerText,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),

        // Klasifikasi Peserta (PSAKDI only)
        if (product == QsProduct.psakdi) ...[
          const SizedBox(height: 14),
          const QsLabelText('Klasifikasi Peserta', required: true),
          const SizedBox(height: 6),
          ref.watch(psakdiClassificationsProvider).when(
            loading: () => Skeletonizer(
              enabled: true,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.borderDefault, width: 1.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                child: const Text('Memuat klasifikasi peserta...'),
              ),
            ),
            error: (err, _) => Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.errorBannerBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.errorBannerBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 18, color: AppColors.redRequired),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Gagal memuat klasifikasi peserta',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.errorBannerText),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(psakdiClassificationsProvider),
                    child: const Text('Coba Lagi',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            data: (classList) {
              final selectedClass = classList
                  .where((c) => c.classValue == klasifikasiPeserta)
                  .firstOrNull;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedClass != null ? klasifikasiPeserta : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.borderDefault, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.borderDefault, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.orangeMbis, width: 2.0),
                      ),
                    ),
                    hint: const Text(
                      'Pilih klasifikasi peserta',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blueInputText,
                    ),
                    items: classList.map((c) {
                      final title = c.manualOnly
                          ? '${c.name} — (ajukan manual)'
                          : c.name;
                      return DropdownMenuItem<int>(
                        value: c.classValue,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      onKlasifikasiChanged(val);
                      onFieldChanged?.call();
                    },
                  ),
                  if (selectedClass != null && selectedClass.manualOnly) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorBannerBg,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppColors.errorBannerBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              size: 18, color: AppColors.redRequired),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Harap ajukan secara manual',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.errorBannerTitle,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  selectedClass.description.isNotEmpty
                                      ? selectedClass.description
                                      : 'Pekerjaan ini tidak dapat dibuat melalui QS di aplikasi. Silakan ajukan penawaran secara manual ke underwriting.',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.errorBannerText,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (selectedClass != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgInfoBanner,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Golongan / ${selectedClass.name}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navyMbis,
                            ),
                          ),
                          if (selectedClass.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              selectedClass.description,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textLabel,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Widget skeleton loading shimmer untuk pilihan chip pekerjaan
class _PekerjaanSkeletonChips extends StatelessWidget {
  const _PekerjaanSkeletonChips();

  static const _placeholders = [
    'Loading',
    'Loading',
    'Loading',
    'Loading',
    'Loading',
    'Loading',
  ];

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _placeholders.map((label) {
          return QsQuickChip(
            label: label,
            isSelected: false,
            onTap: () {},
          );
        }).toList(),
      ),
    );
  }
}
