import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/qs_section_card.dart';
import '../../../../theme/app_theme.dart';
import '../../qs_form_state.dart';
import 'qs_pertanggungan_fields.dart';

/// Card Section 2: Tipe Pertanggungan (Single / Group, Jumlah Orang, Aktivitas)
class QsTipePertanggunganCard extends StatelessWidget {
  final QsType type;
  final ValueChanged<QsType> onTypeChanged;
  final TextEditingController jumlahOrangCtrl;
  final TextEditingController noKtpCtrl;
  final TextEditingController aktivitasCtrl;

  const QsTipePertanggunganCard({
    super.key,
    required this.type,
    required this.onTypeChanged,
    required this.jumlahOrangCtrl,
    required this.noKtpCtrl,
    required this.aktivitasCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return QsSectionCard(
      icon: Icons.person_outline,
      title: 'Tipe Pertanggungan',
      subtitle: 'Single: 1 orang · Group: banyak orang',
      children: [
        const QsLabelText('Type', required: true),
        const SizedBox(height: 6),
        DropdownButtonFormField<QsType>(
          key: ValueKey(type),
          initialValue: type,
          dropdownColor: Colors.white,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.iconDropdown,
            size: 20,
          ),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.blueInputText,
          ),
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.borderDefault, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.borderDefault, width: 1.5),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide:
                  BorderSide(color: AppColors.orangeMbis, width: 2.0),
            ),
          ),
          items: const [
            DropdownMenuItem(
              value: QsType.single,
              child: Text('Single'),
            ),
            DropdownMenuItem(
              value: QsType.group,
              child: Text('Group'),
            ),
          ],
          onChanged: (newType) {
            if (newType == null) return;
            onTypeChanged(newType);
            if (newType == QsType.single) {
              jumlahOrangCtrl.text = '1';
              if (noKtpCtrl.text == 'TBA' || noKtpCtrl.text == '-') {
                noKtpCtrl.text = '';
              }
            } else {
              if (jumlahOrangCtrl.text == '1') {
                jumlahOrangCtrl.text = '';
              }
              if (noKtpCtrl.text.trim().isEmpty ||
                  RegExp(r'^\d+$').hasMatch(noKtpCtrl.text.trim())) {
                noKtpCtrl.text = 'TBA';
              }
            }
          },
        ),
        const SizedBox(height: 14),
        const QsLabelText('Jumlah Orang', required: true),
        const SizedBox(height: 6),
        TextFormField(
          controller: jumlahOrangCtrl,
          enabled: type == QsType.group,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          cursorColor: AppColors.orangeMbis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: type == QsType.single
                ? AppColors.iconDropdown
                : AppColors.blueInputText,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor:
                type == QsType.single ? AppColors.bgDisabled : Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            hintText: 'mis. 25',
            hintStyle: const TextStyle(
              fontSize: 14,
              color: AppColors.textPlaceholder,
              fontWeight: FontWeight.w400,
            ),
            suffixIcon: const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'orang',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: type == QsType.single
                    ? AppColors.borderDisabled
                    : AppColors.borderDefault,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.borderDefault, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.borderDisabled, width: 1.5),
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
          validator: (v) {
            if (type == QsType.group) {
              if (v == null || v.trim().isEmpty) {
                return 'Wajib diisi untuk Type Group';
              }
              final n = int.tryParse(v);
              if (n == null || n < 2) {
                return 'Minimal 2 orang untuk Type Group';
              }
            }
            return null;
          },
        ),
        const SizedBox(height: 6),
        Text(
          type == QsType.single
              ? 'Terkunci 1 orang karena Type = Single. Pilih Group untuk mengubah.'
              : 'Wajib diisi, minimal 2 orang untuk Type Group.',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            height: 1.4,
          ),
        ),
        if (type == QsType.group) ...[
          const SizedBox(height: 14),
          QsTextInputField(
            label: 'Aktivitas/Kegiatan',
            required: true,
            controller: aktivitasCtrl,
            placeholder: 'mis. Manufacture, Sekolah, Outbond',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
          ),
        ],
      ],
    );
  }
}
