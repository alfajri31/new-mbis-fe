import 'package:flutter/material.dart';

import '../qs_form_state.dart';
import 'qs_step_uang_pertanggungan_paxtra.dart';
import 'qs_step_uang_pertanggungan_psakdi.dart';

/// Tab 2 – Uang Pertanggungan & Biaya Asuransi / Premi.
/// Mendelegasikan tampilan ke [QsStepUangPertanggunganPsakdi] atau [QsStepUangPertanggunganPaXtra].
class QsStepUangPertanggungan extends StatelessWidget {
  final QsProduct product;
  final QsType type;
  final QsPremiMode premiMode;
  final GlobalKey<FormState> formKey;

  // PSAKDI fields
  final TextEditingController upACtrl;
  final PsakdiRiskType riskType;
  final ValueChanged<PsakdiRiskType> onRiskTypeChanged;
  final bool risikoC;
  final ValueChanged<bool> onRisikoCChanged;
  final TextEditingController upCCtrl;
  final TextEditingController rateABCtrl;
  final TextEditingController rateCCtrl;

  // PA Xtra fields
  final TextEditingController upPaXtraCtrl;
  final bool cacatTetap;
  final ValueChanged<bool> onCacatTetapChanged;
  final bool perawatanPengobatan;
  final ValueChanged<bool> onPerawatanChanged;
  final Map<String, TextEditingController> santunanCtrls;

  // Common
  final TextEditingController risikoDijaminCtrl;
  final TextEditingController diskonCtrl;
  final QsPolisType polisType;
  final ValueChanged<QsPolisType> onPolisTypeChanged;

  // Mutlak fields
  final TextEditingController premiMutlakPokokCtrl;
  final TextEditingController premiMutlakTambahanCtrl;

  // Flat fields
  final TextEditingController tarifFlatCtrl;

  // Readonly – computed
  final int jumlahHari;
  final int jumlahOrang;
  final int? klasifikasiPeserta;

  // Penyimpangan UW
  final List<UwDeviation> deviations;
  final VoidCallback? onJumpToStep1;
  final String? pipeRate;

  const QsStepUangPertanggungan({
    super.key,
    required this.product,
    required this.type,
    required this.premiMode,
    required this.formKey,
    required this.upACtrl,
    required this.riskType,
    required this.onRiskTypeChanged,
    required this.risikoC,
    required this.onRisikoCChanged,
    required this.upCCtrl,
    required this.rateABCtrl,
    required this.rateCCtrl,
    required this.upPaXtraCtrl,
    required this.cacatTetap,
    required this.onCacatTetapChanged,
    required this.perawatanPengobatan,
    required this.onPerawatanChanged,
    required this.santunanCtrls,
    required this.risikoDijaminCtrl,
    required this.diskonCtrl,
    required this.polisType,
    required this.onPolisTypeChanged,
    required this.premiMutlakPokokCtrl,
    required this.premiMutlakTambahanCtrl,
    required this.tarifFlatCtrl,
    required this.jumlahHari,
    required this.jumlahOrang,
    required this.klasifikasiPeserta,
    required this.deviations,
    this.onJumpToStep1,
    this.pipeRate = '0.10',
  });

  @override
  Widget build(BuildContext context) {
    if (product == QsProduct.psakdi) {
      return QsStepUangPertanggunganPsakdi(
        type: type,
        premiMode: premiMode,
        formKey: formKey,
        upACtrl: upACtrl,
        riskType: riskType,
        onRiskTypeChanged: onRiskTypeChanged,
        risikoC: risikoC,
        onRisikoCChanged: onRisikoCChanged,
        upCCtrl: upCCtrl,
        rateABCtrl: rateABCtrl,
        rateCCtrl: rateCCtrl,
        risikoDijaminCtrl: risikoDijaminCtrl,
        diskonCtrl: diskonCtrl,
        polisType: polisType,
        onPolisTypeChanged: onPolisTypeChanged,
        premiMutlakPokokCtrl: premiMutlakPokokCtrl,
        premiMutlakTambahanCtrl: premiMutlakTambahanCtrl,
        tarifFlatCtrl: tarifFlatCtrl,
        jumlahHari: jumlahHari,
        jumlahOrang: jumlahOrang,
        klasifikasiPeserta: klasifikasiPeserta,
        deviations: deviations,
        onJumpToStep1: onJumpToStep1,
        pipeRate: pipeRate,
      );
    } else {
      return QsStepUangPertanggunganPaXtra(
        type: type,
        premiMode: premiMode,
        formKey: formKey,
        upPaXtraCtrl: upPaXtraCtrl,
        cacatTetap: cacatTetap,
        onCacatTetapChanged: onCacatTetapChanged,
        perawatanPengobatan: perawatanPengobatan,
        onPerawatanChanged: onPerawatanChanged,
        santunanCtrls: santunanCtrls,
        risikoDijaminCtrl: risikoDijaminCtrl,
        diskonCtrl: diskonCtrl,
        polisType: polisType,
        onPolisTypeChanged: onPolisTypeChanged,
        premiMutlakPokokCtrl: premiMutlakPokokCtrl,
        premiMutlakTambahanCtrl: premiMutlakTambahanCtrl,
        tarifFlatCtrl: tarifFlatCtrl,
        jumlahHari: jumlahHari,
        jumlahOrang: jumlahOrang,
        deviations: deviations,
        onJumpToStep1: onJumpToStep1,
        pipeRate: pipeRate,
      );
    }
  }
}
