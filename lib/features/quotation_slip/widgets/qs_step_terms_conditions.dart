import 'package:flutter/material.dart';

import '../qs_form_state.dart';
import 'qs_step_terms_conditions_paxtra.dart';
import 'qs_step_terms_conditions_psakdi.dart';

/// Tab 3 – Terms & Conditions, Penerbitan, Dokumen Pendukung.
/// Mendelegasikan tampilan ke [QsStepTermsConditionsPsakdi] atau [QsStepTermsConditionsPaXtra].
class QsStepTermsConditions extends StatelessWidget {
  final QsProduct product;
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

  const QsStepTermsConditions({
    super.key,
    required this.product,
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
  Widget build(BuildContext context) {
    if (product == QsProduct.psakdi) {
      return QsStepTermsConditionsPsakdi(
        formKey: formKey,
        kotaCtrl: kotaCtrl,
        cabangCtrl: cabangCtrl,
        penandatanganCtrl: penandatanganCtrl,
        jabatanCtrl: jabatanCtrl,
        tglPenerbitan: tglPenerbitan,
        onTglPenerbitanChanged: onTglPenerbitanChanged,
        masaBerlaku: masaBerlaku,
        onMasaBerlakuChanged: onMasaBerlakuChanged,
        namaFile: namaFile,
        onPilihFile: onPilihFile,
        onHapusFile: onHapusFile,
      );
    } else {
      return QsStepTermsConditionsPaXtra(
        formKey: formKey,
        kotaCtrl: kotaCtrl,
        cabangCtrl: cabangCtrl,
        penandatanganCtrl: penandatanganCtrl,
        jabatanCtrl: jabatanCtrl,
        tglPenerbitan: tglPenerbitan,
        onTglPenerbitanChanged: onTglPenerbitanChanged,
        masaBerlaku: masaBerlaku,
        onMasaBerlakuChanged: onMasaBerlakuChanged,
        klausulTambahanCtrl: klausulTambahanCtrl,
        kondisiTambahanCtrl: kondisiTambahanCtrl,
        warantiTambahanCtrl: warantiTambahanCtrl,
        pengecualianTambahanCtrl: pengecualianTambahanCtrl,
        deductibleCtrl: deductibleCtrl,
        namaFile: namaFile,
        onPilihFile: onPilihFile,
        onHapusFile: onHapusFile,
      );
    }
  }
}
