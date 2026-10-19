import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/qs_section_card.dart';
import '../../../../theme/app_theme.dart';
import 'qs_pertanggungan_fields.dart';

/// Card Section 1: Data Pemegang Polis dan Kontak Pengiriman QS
class QsPemegangPolisCard extends StatelessWidget {
  final TextEditingController namaPolisCtrl;
  final TextEditingController alamatCtrl;
  final TextEditingController bidangUsahaCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController namaPicCtrl;
  final TextEditingController noHpPicCtrl;
  final bool dataSamaPolis;
  final TextEditingController namaTertanggungCtrl;
  final VoidCallback? onFieldChanged;

  static const _chBidang = [
    'Percetakan',
    'Perdagangan',
    'Jasa',
    'Manufaktur',
    'Konstruksi',
  ];

  const QsPemegangPolisCard({
    super.key,
    required this.namaPolisCtrl,
    required this.alamatCtrl,
    required this.bidangUsahaCtrl,
    required this.emailCtrl,
    required this.namaPicCtrl,
    required this.noHpPicCtrl,
    required this.dataSamaPolis,
    required this.namaTertanggungCtrl,
    this.onFieldChanged,
  });

  @override
  Widget build(BuildContext context) {
    return QsSectionCard(
      icon: Icons.person_outline,
      title: 'Pemegang Polis',
      subtitle: 'Nama dan alamat yang tercantum di dokumen QS',
      children: [
        QsTextInputField(
          label: 'Nama Pemegang Polis',
          required: true,
          controller: namaPolisCtrl,
          placeholder: 'Nama perorangan / perusahaan',
          onChanged: (_) {
            if (dataSamaPolis) {
              namaTertanggungCtrl.text = namaPolisCtrl.text;
            }
            onFieldChanged?.call();
          },
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
        ),
        QsTextAreaField(
          label: 'Alamat',
          required: true,
          controller: alamatCtrl,
          placeholder: 'Alamat lengkap',
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const QsLabelText('Bidang Usaha', required: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: bidangUsahaCtrl,
              cursorColor: AppColors.orangeMbis,
              onChanged: (_) => onFieldChanged?.call(),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.blueInputText,
              ),
              decoration: InputDecoration(
                hintText: 'Pilih atau ketik bidang usaha',
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
              children: _chBidang.map((chip) {
                final isSel = bidangUsahaCtrl.text == chip;
                return QsQuickChip(
                  label: chip,
                  isSelected: isSel,
                  onTap: () {
                    bidangUsahaCtrl.text = chip;
                    onFieldChanged?.call();
                  },
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          height: 1,
          color: AppColors.bgDisabled,
        ),
        const SizedBox(height: 14),
        const Text(
          'Kontak untuk pengiriman QS',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.navyMbis,
          ),
        ),
        const SizedBox(height: 14),
        QsTextInputField(
          label: 'Email Pemegang Polis',
          controller: emailCtrl,
          placeholder: 'nama@perusahaan.co.id',
          helperText:
              'Link quotation dikirim ke email ini. Wajib saat "Kirim ke Customer".',
          keyboardType: TextInputType.emailAddress,
        ),
        QsTextInputField(
          label: 'Nama PIC (opsional)',
          controller: namaPicCtrl,
          placeholder: 'mis. Ibu Sari – HRD',
          helperText: 'Untuk pemegang polis perusahaan / Group.',
        ),
        QsTextInputField(
          label: 'No. HP PIC (opsional)',
          controller: noHpPicCtrl,
          placeholder: '08xxxxxxxxx',
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ],
    );
  }
}
