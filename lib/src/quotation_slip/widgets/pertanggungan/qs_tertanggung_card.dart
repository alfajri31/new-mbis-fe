import 'package:flutter/material.dart';

import '../common/qs_section_card.dart';
import '../../../../theme/app_theme.dart';
import '../../qs_form_state.dart';
import 'qs_pertanggungan_fields.dart';

/// Card Section 5: Orang yang Dipertanggungkan
class QsTertanggungCard extends StatelessWidget {
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

  static const _chKerja = [
    'Karyawan',
    'Wiraswasta',
    'PNS / BUMN',
    'Ibu Rumah Tangga',
    'Sopir',
    'Pekerja Tambang',
  ];

  static const _kelasInfo = [
    {
      'v': 1,
      'title': 'Kelas 1 — Pekerjaan kantor',
      'desc':
          'Orang-orang yang melakukan pekerjaan di kantor atau sering tinggal / berada di kantor seperti: direktur, akuntan, sekretaris, karyawan administrasi, dsb.',
      'rates': 'Rate standar: A 0.05% · A/B 0.10% · C 0.15%',
    },
    {
      'v': 2,
      'title': 'Kelas 2 — Sering bepergian / dinas luar',
      'desc':
          'Orang-orang dari kelas 1 yang sering bepergian / dinas luar, seperti: bagian penjualan, ibu rumah tangga, pimpinan proyek, manajer atau karyawan lapangan yang tidak terlibat langsung dalam pekerjaan, dan sejenisnya.',
      'rates': 'Rate standar: A 0.08% · A/B 0.15% · C 0.20%',
    },
    {
      'v': 3,
      'title': 'Kelas 3 — Memakai alat / sarana kerja',
      'desc':
          'Orang-orang yang dalam pekerjaannya memerlukan alat-alat atau sarana lainnya untuk mendukung kegiatannya seperti: dokter gigi, ahli bedah, paramedis, sopir, mekanik, petugas laboratorium atau manajer lapangan yang terlibat langsung dalam proses pekerjaan, dan sejenisnya.',
      'rates': 'Rate standar: A 0.12% · A/B 0.25% · C 0.30%',
    },
    {
      'v': 4,
      'title': 'Kelas 4 — Pekerjaan berat & berbahaya (ajukan manual)',
      'desc':
          'Orang-orang yang melakukan pekerjaan berat dan berbahaya berkaitan dengan tempat tugasnya, seperti: pekerja tambang, pekerja bangunan ketinggian, penyelam, dsb.',
      'rates': 'Memerlukan persetujuan Underwriting khusus',
    },
  ];

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
  });

  @override
  Widget build(BuildContext context) {
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
              final lahir = tglLahir!;
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
              usiaError!,
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _chKerja.map((chip) {
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
          DropdownButtonFormField<int>(
            initialValue: klasifikasiPeserta,
            isExpanded: true,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
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
                borderSide:
                    const BorderSide(color: AppColors.orangeMbis, width: 2.0),
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
            items: _kelasInfo.map((k) {
              final val = k['v'] as int;
              final title = k['title'] as String;
              return DropdownMenuItem<int>(
                value: val,
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
          if (saranKelas != null &&
              saranKelas != klasifikasiPeserta) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.alertBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.alertBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Saran sistem: Kelas $saranKelas berdasarkan pekerjaan "${pekerjaanCtrl.text}"',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.alertText,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      onKlasifikasiChanged(saranKelas);
                      onFieldChanged?.call();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.orangeMbis,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 0),
                      minimumSize: const Size(0, 34),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Pakai',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
          if (klasifikasiPeserta == 4) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorBannerBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.errorBannerBorder),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18, color: AppColors.redRequired),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Harap ajukan secara manual',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.errorBannerTitle,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Kelas 4 (pekerjaan berat & berbahaya) tidak dapat dibuat melalui QS di aplikasi. Silakan ajukan penawaran secara manual ke underwriting.',
                          style: TextStyle(
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
          ] else if (klasifikasiPeserta != null) ...[
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final item = _kelasInfo.firstWhere(
                  (x) => x['v'] == klasifikasiPeserta);
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgInfoBanner,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Golongan / ${item['title']}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navyMbis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['desc'] as String,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textLabel,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['rates'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navyMbis,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ],
    );
  }
}
