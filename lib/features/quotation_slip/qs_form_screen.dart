import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../core/providers/repository_providers.dart';
import '../../theme/app_theme.dart';
import 'qs_form_state.dart';
import 'widgets/pertanggungan/repositories/qs_pertanggungan_model.dart';
import 'widgets/qs_step_pertanggungan.dart';
import 'widgets/qs_step_terms_conditions.dart';
import 'widgets/qs_step_uang_pertanggungan.dart';
import 'widgets/terms_conditions/qs_tc_constants.dart';

/// Screen utama pembuatan Quotation Slip.
///
/// Mengikuti desain prototype M-BIS (Prototype_QS_M-BIS.html):
/// Header Navy terpadu dengan 3 progress bars (Pertanggungan, UP & Premi, T&C),
/// banner auto-fill, legend warna teks biru, bottom bar dengan total premi kalkulasi,
/// dan transisi penuh ke Preview QS dengan status deviasi UW.
class QsFormScreen extends ConsumerStatefulWidget {
  final QsProduct product;

  final String? customerName;
  final String? customerAddress;
  final String? customerBidangUsaha;
  final String? customerEmail;
  final String? pipelineId;
  final String? productCode;
  final String? qsId;

  const QsFormScreen({
    super.key,
    this.product = QsProduct.psakdi,
    this.customerName,
    this.customerAddress,
    this.customerBidangUsaha,
    this.customerEmail,
    this.pipelineId,
    this.productCode,
    this.qsId,
  });

  @override
  ConsumerState<QsFormScreen> createState() => _QsFormScreenState();
}

class _QsFormScreenState extends ConsumerState<QsFormScreen>
    with TickerProviderStateMixin {
  // Product state
  late QsProduct _product;

  // Status & Navigation
  QsStatus _status = QsStatus.draft;
  int _currentStep = 0;
  bool _isPreviewing = false;
  final _currFormat = NumberFormat('#,##0', 'id');

  // Loading & Saving states
  bool _isLoadingInitial = false;
  bool _isSavingQs = false;
  String? _qsId;
  String? _serverNomorQs;
  String? _initialError;
  QsPertanggunganResponse? _apiResponse;
  QsPertanggunganResponse? get apiResponse => _apiResponse;
  QsPerhitunganBiayaData? _apiPerhitunganBiaya;
  List<String>? _termsKlausula;
  List<String>? _termsKondisi;
  List<String>? _termsWaranti;
  List<String>? _termsPengecualian;

  // PDF Preview State
  Uint8List? _previewPdfBytes;
  bool _isLoadingPdf = false;
  String? _pdfError;

  String? get _pipelineId =>
      (widget.pipelineId != null && widget.pipelineId!.isNotEmpty)
          ? widget.pipelineId
          : 'ce116c9b-3a0b-4109-84ae-56175ffb27f2';

  String get _productCode {
    if (widget.productCode != null && widget.productCode!.isNotEmpty) {
      final upper = widget.productCode!.trim().toUpperCase();
      if (upper == 'PAXTRA' ||
          upper.contains('XTRA') ||
          upper.contains('PERSONAL ACCIDENT')) {
        return 'PAXTRA';
      }
      if (upper.contains('PSAKDI')) {
        return 'PSAKDI';
      }
      return widget.productCode!.trim();
    }
    return _product == QsProduct.psakdi ? 'PSAKDI' : 'PAXTRA';
  }

  // Form keys per step
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();

  // ── Tab 1: Pertanggungan ──
  late final TextEditingController _namaPolisCtrl;
  late final TextEditingController _alamatCtrl;
  late final TextEditingController _bidangUsahaCtrl;
  late final TextEditingController _emailCtrl;
  final _namaPicCtrl = TextEditingController();
  final _noHpPicCtrl = TextEditingController();
  QsType _type = QsType.single;
  final _jumlahOrangCtrl = TextEditingController();
  final _aktivitasCtrl = TextEditingController();
  QsPremiMode _premiMode = QsPremiMode.normal;
  DateTime? _tglMulai;
  DateTime? _tglAkhir;
  bool _dataSamaPolis = false;
  final _namaTertanggungCtrl = TextEditingController(text: '');
  final _noKtpCtrl = TextEditingController(text: '');
  DateTime? _tglLahir;
  final _pekerjaanCtrl = TextEditingController(text: '');
  int? _klasifikasiPeserta;

  // ── Tab 2: Uang Pertanggungan ──
  final _upACtrl = TextEditingController();
  PsakdiRiskType _riskType = PsakdiRiskType.ab;
  bool _risikoC = false;
  final _upCCtrl = TextEditingController();
  final _rateABCtrl = TextEditingController();
  final _rateCCtrl = TextEditingController();
  final _upPaXtraCtrl = TextEditingController();
  bool _cacatTetap = true;
  bool _perawatanPengobatan = false;
  final Map<String, TextEditingController> _santunanCtrls = {
    for (final key in santunanLabels.keys) key: TextEditingController(),
  };
  final _risikoDijaminCtrl = TextEditingController();
  final _diskonCtrl = TextEditingController(text: '0');
  QsPolisType _polisType = QsPolisType.cetak;
  final _premiMutlakPokokCtrl = TextEditingController();
  final _premiMutlakTambahanCtrl = TextEditingController();
  final _tarifFlatCtrl = TextEditingController();

  // ── Tab 3: T/C ──
  final _kotaCtrl = TextEditingController();
  final _cabangCtrl = TextEditingController();
  final _penandatanganCtrl = TextEditingController();
  final _jabatanCtrl = TextEditingController();
  DateTime? _tglPenerbitan;
  DateTime? _masaBerlaku;
  final _klausulTambahanCtrl = TextEditingController();
  final _kondisiTambahanCtrl = TextEditingController();
  final _warantiTambahanCtrl = TextEditingController();
  final _pengecualianTambahanCtrl = TextEditingController();
  final _deductibleCtrl = TextEditingController();
  String? _namaFile;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _qsId = widget.qsId;

    // Bersihkan form tanpa nilai default statis
    _namaPolisCtrl = TextEditingController(text: widget.customerName ?? '');
    _alamatCtrl = TextEditingController(text: widget.customerAddress ?? '');
    _bidangUsahaCtrl =
        TextEditingController(text: widget.customerBidangUsaha ?? '');
    _emailCtrl = TextEditingController(text: widget.customerEmail ?? '');
    _jumlahOrangCtrl.text = '';
    _tglMulai = null;
    _tglAkhir = null;
    _tglPenerbitan = null;
    _masaBerlaku = null;
    _klasifikasiPeserta = null;
    _diskonCtrl.text = '0';
    _deductibleCtrl.text = '';
    _rateABCtrl.text = '';
    _rateCCtrl.text = '';

    final isFromPipeline =
        widget.pipelineId != null && widget.pipelineId!.isNotEmpty;
    if (isFromPipeline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchInitialData();
      });
    }
  }

  Future<void> _fetchInitialData() async {
    final pId = widget.pipelineId;
    if (pId == null || pId.isEmpty) return;

    final pCode = _productCode;

    setState(() {
      _isLoadingInitial = true;
      _initialError = null;
    });

    try {
      final repo = ref.read(qsPertanggunganRepoProvider);
      final res = await repo.getPertanggungan(
        pipelineId: pId,
        productCode: pCode,
      );

      if (!mounted) return;

      setState(() {
        _apiResponse = res;
        if (res.id != null && res.id!.isNotEmpty) {
          _qsId = res.id;
        }

        // 1. Resolve Product
        final prodStr = (res.productCode ?? pCode).toLowerCase();
        if (prodStr.contains('personal accident') ||
            prodStr.contains('paxtra') ||
            prodStr.contains('pa xtra')) {
          _product = QsProduct.paXtra;
        } else if (prodStr.contains('psakdi')) {
          _product = QsProduct.psakdi;
        }

        // 2. Pemegang Polis
        final pp = res.pemegangPolis;
        if (pp != null) {
          if (pp.tertanggung != null) _namaPolisCtrl.text = pp.tertanggung!;
          if (pp.alamat != null) _alamatCtrl.text = pp.alamat!;
          if (pp.bidang != null) _bidangUsahaCtrl.text = pp.bidang!;
          if (pp.email != null) _emailCtrl.text = pp.email!;
          if (pp.pic != null) _namaPicCtrl.text = pp.pic!;
          if (pp.hpPic != null) _noHpPicCtrl.text = pp.hpPic!;
        }

        // 3. Tipe Pertanggungan
        final tp = res.tipePertanggungan;
        if (tp != null) {
          final qTypeStr = (tp.qType ?? '').trim().toLowerCase();
          _type = (qTypeStr == 'group') ? QsType.group : QsType.single;
          if (tp.jmlOrang != null) {
            _jumlahOrangCtrl.text = tp.jmlOrang.toString();
          } else {
            _jumlahOrangCtrl.text = _type == QsType.single ? '1' : '';
          }
          if (tp.aktivitas != null) _aktivitasCtrl.text = tp.aktivitas!;
        }

        // 4. Perhitungan Premi Mode
        final ppPrem = res.perhitunganPremi;
        if (ppPrem != null) {
          final calcStr = (ppPrem.calcType ?? '').trim().toLowerCase();
          if (calcStr.contains('mutlak')) {
            _premiMode = QsPremiMode.mutlak;
          } else if (calcStr.contains('flat')) {
            _premiMode = QsPremiMode.flat;
          } else {
            _premiMode = QsPremiMode.normal;
          }
        }

        // 5. Klasifikasi Peserta
        _klasifikasiPeserta = res.klasifikasiPeserta;

        // 6. Jangka Waktu
        final jw = res.jangkaWaktu;
        if (jw != null) {
          if (jw.start != null && jw.start!.isNotEmpty) {
            _tglMulai = DateTime.tryParse(jw.start!);
          }
          if (jw.end != null && jw.end!.isNotEmpty) {
            _tglAkhir = DateTime.tryParse(jw.end!);
          }
        }

        // 7. Orang Dipertanggungkan
        final od = res.orangDipertanggungkan;
        if (od != null) {
          _dataSamaPolis = od.samaDenganPP ?? true;
          if (od.nama != null && od.nama!.isNotEmpty) {
            _namaTertanggungCtrl.text = od.nama!;
          } else if (_dataSamaPolis && _namaPolisCtrl.text.isNotEmpty) {
            _namaTertanggungCtrl.text = _namaPolisCtrl.text;
          }

          if (od.ktp != null) _noKtpCtrl.text = od.ktp!;
          if (od.lahir != null && od.lahir!.isNotEmpty) {
            _tglLahir = DateTime.tryParse(od.lahir!);
          }
          if (od.pekerjaan != null) _pekerjaanCtrl.text = od.pekerjaan!;
        }

        // 8. Step 2 (Uang Pertanggungan & Biaya Asuransi)
        final s2 = res.step2;
        if (s2 != null) {
          final upVal = s2.jaminanPokok?.uangPertanggunganMeninggalDunia;
          if (upVal != null && upVal > 0) {
            final formattedUp = _currFormat.format(upVal);
            _upPaXtraCtrl.text = formattedUp;
            _upACtrl.text = formattedUp;
          }

          // Jaminan Tambahan
          final jt = s2.jaminanTambahan;
          if (jt != null) {
            _cacatTetap = jt.cacatTetap ?? true;
            final rawPengobatan = jt.biayaPerawatanPengobatan ?? 0;
            _perawatanPengobatan = rawPengobatan > 0;
            if (rawPengobatan > 0) {
              _santunanCtrls['pengobatan']?.text = _currFormat.format(rawPengobatan);
            }
          }

          // Perluasan Santunan
          final per = s2.perluasan;
          if (per != null) {
            if (per.santunanAmbulansEvakuasi != null && per.santunanAmbulansEvakuasi! > 0) {
              _santunanCtrls['ambulan']?.text = _currFormat.format(per.santunanAmbulansEvakuasi!);
            }
            if (per.santunanPemakamanKremasi != null && per.santunanPemakamanKremasi! > 0) {
              _santunanCtrls['pemakaman']?.text = _currFormat.format(per.santunanPemakamanKremasi!);
            }
            if (per.santunanKehilanganBarangPribadi != null && per.santunanKehilanganBarangPribadi! > 0) {
              _santunanCtrls['barang']?.text = _currFormat.format(per.santunanKehilanganBarangPribadi!);
            }
            if (per.santunanPengurusanDokumen != null && per.santunanPengurusanDokumen! > 0) {
              _santunanCtrls['dokumen']?.text = _currFormat.format(per.santunanPengurusanDokumen!);
            }
            if (per.santunanBiayaPendidikan != null && per.santunanBiayaPendidikan! > 0) {
              _santunanCtrls['pendidikan']?.text = _currFormat.format(per.santunanBiayaPendidikan!);
            }
            if (per.santunanPemulanganJenazah != null && per.santunanPemulanganJenazah! > 0) {
              _santunanCtrls['pemulangan']?.text = _currFormat.format(per.santunanPemulanganJenazah!);
            }
          }

          // Diskon
          if (s2.discountPersen != null) {
            final d = s2.discountPersen!;
            _diskonCtrl.text = (d == d.roundToDouble()) ? d.toInt().toString() : d.toString();
          }

          // Jenis Polis
          if (s2.jenisPolis != null) {
            _polisType = (s2.jenisPolis!.toUpperCase() == 'EPOLIS')
                ? QsPolisType.ePolis
                : QsPolisType.cetak;
          }

          // Premi Mutlak
          if (s2.premiJaminanPokok != null) {
            _premiMutlakPokokCtrl.text = _currFormat.format(s2.premiJaminanPokok!);
          }
          if (s2.premiJaminanTambahan != null) {
            _premiMutlakTambahanCtrl.text = _currFormat.format(s2.premiJaminanTambahan!);
          }
          if (s2.tarifFlatPerHari != null) {
            _tarifFlatCtrl.text = _currFormat.format(s2.tarifFlatPerHari!);
          }
        }

        // 9. Step 3 (T/C & Penerbitan)
        final s3 = res.step3;
        if (s3 != null) {
          final pen = s3.penerbitan;
          if (pen != null) {
            if (pen.kota != null) _kotaCtrl.text = pen.kota!;
            if (pen.cabang != null) _cabangCtrl.text = pen.cabang!;
            if (pen.penandatangan != null) _penandatanganCtrl.text = pen.penandatangan!;
            if (pen.jabatanPenandatangan != null) _jabatanCtrl.text = pen.jabatanPenandatangan!;
            if (pen.tanggalTerbit != null && pen.tanggalTerbit!.isNotEmpty) {
              _tglPenerbitan = DateTime.tryParse(pen.tanggalTerbit!);
            }
          }
          if (s3.berlakuSampai != null && s3.berlakuSampai!.isNotEmpty) {
            _masaBerlaku = DateTime.tryParse(s3.berlakuSampai!);
          }

          // Process Terms
          if (s3.terms != null) {
            for (final term in s3.terms!) {
              final tipe = (term.tipeTerms ?? '').toUpperCase().trim();
              final descs = term.descriptions ?? [];
              if (tipe == 'DEDUCTIBLE') {
                if (descs.isNotEmpty) {
                  _deductibleCtrl.text = descs.join(', ');
                }
              } else if (tipe == 'KLAUSULA') {
                final stdList = _product == QsProduct.paXtra ? kPaxtraKlausulaStandar : kPsakdiKlausulaStandar;
                final additional = descs.where((d) => !stdList.contains(d)).toList();
                if (additional.isNotEmpty) {
                  _klausulTambahanCtrl.text = additional.join('\n');
                }
                _termsKlausula = descs;
              } else if (tipe == 'KONDISI') {
                final stdList = _product == QsProduct.paXtra ? kPaxtraKondisiStandar : kPsakdiKondisiStandar;
                final additional = descs.where((d) => !stdList.contains(d)).toList();
                if (additional.isNotEmpty) {
                  _kondisiTambahanCtrl.text = additional.join('\n');
                }
                _termsKondisi = descs;
              } else if (tipe == 'WARANTI') {
                final stdList = _product == QsProduct.paXtra ? kPaxtraWarantiStandar : kPsakdiWarantiStandar;
                final additional = descs.where((d) => !stdList.contains(d)).toList();
                if (additional.isNotEmpty) {
                  _warantiTambahanCtrl.text = additional.join('\n');
                }
                _termsWaranti = descs;
              } else if (tipe == 'PENGECUALIAN') {
                final stdList = _product == QsProduct.paXtra ? kPaxtraPengecualianStandar : kPsakdiPengecualianStandar;
                final additional = descs.where((d) => !stdList.contains(d)).toList();
                if (additional.isNotEmpty) {
                  _pengecualianTambahanCtrl.text = additional.join('\n');
                }
                _termsPengecualian = descs;
              }
            }
          }
        }

        // 10. Perhitungan Biaya
        _apiPerhitunganBiaya = res.perhitunganBiaya;

        _isLoadingInitial = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _initialError = e.toString().replaceFirst('Exception: ', '');
          _isLoadingInitial = false;
        });
      }
    }
  }

  Future<void> _fetchPreviewPdf([String? pipelineId, String? productCode]) async {
    final pId = pipelineId ?? _pipelineId;
    final pCode = productCode ?? _productCode;
    if (pId == null || pId.isEmpty) return;

    setState(() {
      _isLoadingPdf = true;
      _pdfError = null;
    });

    try {
      final repo = ref.read(qsPertanggunganRepoProvider);
      final bytes = await repo.getPreviewQsPdf(
        pipelineId: pId,
        productCode: pCode,
      );

      if (!mounted) return;

      setState(() {
        _previewPdfBytes = bytes;
        _isLoadingPdf = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pdfError = e.toString().replaceFirst('Exception: ', '');
        _isLoadingPdf = false;
      });
    }
  }

  @override
  void dispose() {
    _namaPolisCtrl.dispose();
    _alamatCtrl.dispose();
    _bidangUsahaCtrl.dispose();
    _emailCtrl.dispose();
    _namaPicCtrl.dispose();
    _noHpPicCtrl.dispose();
    _jumlahOrangCtrl.dispose();
    _aktivitasCtrl.dispose();
    _namaTertanggungCtrl.dispose();
    _noKtpCtrl.dispose();
    _pekerjaanCtrl.dispose();
    _upACtrl.dispose();
    _upCCtrl.dispose();
    _rateABCtrl.dispose();
    _rateCCtrl.dispose();
    _upPaXtraCtrl.dispose();
    for (final c in _santunanCtrls.values) {
      c.dispose();
    }
    _risikoDijaminCtrl.dispose();
    _diskonCtrl.dispose();
    _premiMutlakPokokCtrl.dispose();
    _premiMutlakTambahanCtrl.dispose();
    _tarifFlatCtrl.dispose();
    _kotaCtrl.dispose();
    _cabangCtrl.dispose();
    _penandatanganCtrl.dispose();
    _jabatanCtrl.dispose();
    _klausulTambahanCtrl.dispose();
    _kondisiTambahanCtrl.dispose();
    _warantiTambahanCtrl.dispose();
    _pengecualianTambahanCtrl.dispose();
    _deductibleCtrl.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Computed
  // ────────────────────────────────────────────────────────────────────────

  int get _jumlahHari {
    if (_tglMulai == null || _tglAkhir == null) return 0;
    return _tglAkhir!.difference(_tglMulai!).inDays;
  }

  int get _jumlahOrang =>
      _type == QsType.single ? 1 : (int.tryParse(_jumlahOrangCtrl.text) ?? 1);

  String get _nomorQs {
    if (_serverNomorQs != null && _serverNomorQs!.isNotEmpty) {
      return _serverNomorQs!;
    }
    final prod = _product == QsProduct.psakdi ? 'PSAKDI' : 'PAXTRA';
    final prefix = _status == QsStatus.draft ? 'XXX' : '001';
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    return '$prefix/QS-$prod/RO2-SBY/$mm/${now.year}';
  }

  List<UwDeviation> get _deviations => detectDeviations(
        product: _product,
        mode: _premiMode,
        kelasPeserta: _klasifikasiPeserta,
        saranKelasPeserta: saranKelas(_pekerjaanCtrl.text),
        rateAB: double.tryParse(_rateABCtrl.text),
        rateC: double.tryParse(_rateCCtrl.text),
        tarifFlatPerHari: double.tryParse(
            _tarifFlatCtrl.text.replaceAll('.', '').replaceAll(',', '')),
        tcTambahanDiubah: _klausulTambahanCtrl.text.isNotEmpty ||
            _kondisiTambahanCtrl.text.isNotEmpty ||
            _warantiTambahanCtrl.text.isNotEmpty ||
            _pengecualianTambahanCtrl.text.isNotEmpty,
        deductible: _deductibleCtrl.text,
      );

  double get _diskonPersen =>
      double.tryParse(_diskonCtrl.text) ?? 0;

  double get _biayaAdmin => biayaAdminForPolis(_polisType);

  double _parseNum(String s) =>
      double.tryParse(s.replaceAll('.', '').replaceAll(',', '')) ?? 0;

  Map<String, double> get _santunanValues => {
        for (final e in _santunanCtrls.entries)
          e.key: _parseNum(e.value.text),
      };

  PremiResult? get _premiResult {
    if (_apiPerhitunganBiaya != null) {
      return PremiResult(
        premiPokok: _apiPerhitunganBiaya!.premiJaminanPokok ?? 0,
        premiTambahan: _apiPerhitunganBiaya!.premiJaminanTambahan ?? 0,
        gross: _apiPerhitunganBiaya!.grossPremi ?? 0,
        diskon: _apiPerhitunganBiaya!.nilaiDiscount ?? 0,
        netto: _apiPerhitunganBiaya!.nettPremi ?? 0,
        biayaAdmin: _apiPerhitunganBiaya!.adminCost ?? 0,
        total: _apiPerhitunganBiaya!.biayaAsuransi ?? 0,
      );
    }

    final hari = _jumlahHari;
    if (hari <= 0) return null;
    final n = _jumlahOrang;

    if (_product == QsProduct.psakdi) {
      final up = _parseNum(_upACtrl.text);
      if (up <= 0) return null;

      switch (_premiMode) {
        case QsPremiMode.normal:
          return hitungPsakdiNormal(
            upA: up,
            riskType: _riskType,
            upC: _risikoC ? _parseNum(_upCCtrl.text) : null,
            rateAB: double.tryParse(_rateABCtrl.text) ?? 0,
            rateC: double.tryParse(_rateCCtrl.text) ?? 0,
            hari: hari,
            jumlahOrang: n,
            diskonPersen: _diskonPersen,
            biayaAdmin: _biayaAdmin,
          );
        case QsPremiMode.mutlak:
          final pokok = _parseNum(_premiMutlakPokokCtrl.text);
          final tambahan = _parseNum(_premiMutlakTambahanCtrl.text);
          final gross = pokok + tambahan;
          final disk = gross * (_diskonPersen / 100);
          return PremiResult(
            premiPokok: pokok,
            premiTambahan: tambahan,
            gross: gross,
            diskon: disk,
            netto: gross - disk,
            biayaAdmin: _biayaAdmin,
            total: gross - disk + _biayaAdmin,
          );
        case QsPremiMode.flat:
          final tarif = _parseNum(_tarifFlatCtrl.text);
          final premi = tarif * hari * n;
          final disk = premi * (_diskonPersen / 100);
          return PremiResult(
            premiPokok: premi,
            premiTambahan: 0,
            gross: premi,
            diskon: disk,
            netto: premi - disk,
            biayaAdmin: _biayaAdmin,
            total: premi - disk + _biayaAdmin,
          );
      }
    } else {
      // PA Xtra
      final up = _parseNum(_upPaXtraCtrl.text);
      if (up <= 0) return null;

      switch (_premiMode) {
        case QsPremiMode.normal:
          return hitungPaXtraNormal(
            up: up,
            cacatTetap: _cacatTetap,
            santunanValues: _santunanValues,
            hari: hari,
            jumlahOrang: n,
            diskonPersen: _diskonPersen,
            biayaAdmin: _biayaAdmin,
          );
        case QsPremiMode.mutlak:
          final pokok = _parseNum(_premiMutlakPokokCtrl.text);
          final tambahan = _parseNum(_premiMutlakTambahanCtrl.text);
          final gross = pokok + tambahan;
          final disk = gross * (_diskonPersen / 100);
          return PremiResult(
            premiPokok: pokok,
            premiTambahan: tambahan,
            gross: gross,
            diskon: disk,
            netto: gross - disk,
            biayaAdmin: _biayaAdmin,
            total: gross - disk + _biayaAdmin,
          );
        case QsPremiMode.flat:
          final tarif = _parseNum(_tarifFlatCtrl.text);
          final premi = tarif * hari * n;
          final disk = premi * (_diskonPersen / 100);
          return PremiResult(
            premiPokok: premi,
            premiTambahan: 0,
            gross: premi,
            diskon: disk,
            netto: premi - disk,
            biayaAdmin: _biayaAdmin,
            total: premi - disk + _biayaAdmin,
          );
      }
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isPreviewing) {
      if (_previewPdfBytes == null && !_isLoadingPdf && _pdfError == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _previewPdfBytes == null &&
              !_isLoadingPdf &&
              _pdfError == null) {
            _fetchPreviewPdf();
          }
        });
      }
      return _buildPreviewScreen();
    }

    if (_isLoadingInitial) {
      return Scaffold(
        backgroundColor: AppColors.bgScaffold,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderDivider),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.5,
                          color: AppColors.navyMbis,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Memuat Data Quotation Slip…',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Mengambil data pipeline & rincian pertanggungan dari server',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_initialError != null) {
      return Scaffold(
        backgroundColor: AppColors.bgScaffold,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 460),
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEE2E2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          size: 32,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Gagal Memuat Quotation Slip',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _initialError!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textDark,
                              side: const BorderSide(color: AppColors.borderDefault),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            child: const Text(
                              'Kembali',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _fetchInitialData,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text(
                              'Coba Lagi',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navyMbis,
                              foregroundColor: AppColors.surfaceWhite,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: AppColors.bgScaffold,
        body: Column(
          children: [
            // Header Navy sesuai prototype (lengkap dengan 3 progress bars)
            _buildHeader(),

            // Body form
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      children: [
                        // Banner auto-fill pada Langkah 1
                        if (_currentStep == 0) _buildAutoFillBanner(),

                        // Form aktif
                        _currentStepWidget(),

                        const SizedBox(height: 12),

                        // Legend teks biru
                        _buildFooterLegend(),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom sticky navigation bar
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Responsive Header (Prototype 1:1 - Wide Desktop vs Mobile Stepper)
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1024;
        if (isWide) {
          return _buildHeaderWide();
        } else {
          return _buildHeaderMobile();
        }
      },
    );
  }

  /// Header mode Desktop / Web (lebar >= 1024px sesuai prototype isFormWide)
  Widget _buildHeaderWide() {
    final productLabel =
        _product == QsProduct.psakdi ? 'PSAKDI' : 'PA Xtra';
    final totalLbl =
        _product == QsProduct.paXtra ? 'Biaya Asuransi' : 'Total Premi';
    final totalVal = _premiResult?.total ?? 0;
    final totalTxt = 'Rp ${_currFormat.format(totalVal)}';
    final needsUw = _deviations.isNotEmpty;
    final uwBtnLabel = needsUw ? 'Minta Approval UW' : 'Terbitkan QS';

    return Container(
      color: AppColors.navyMbis,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Material(
              color: AppColors.whiteAlpha12,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _onBack,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      size: 20,
                      color: AppColors.surfaceWhite,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'QS Baru · $productLabel',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.surfaceWhite,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No. $_nomorQs',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.badgeDraftText,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.whiteAlpha14,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _statusLabel,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.surfaceWhite,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  totalLbl,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.whiteAlpha75,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  totalTxt,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.badgeReadyText,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 18),
            OutlinedButton(
              onPressed: _simpanDraft,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.surfaceWhite,
                side: BorderSide(
                  color: AppColors.textWhite70,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                minimumSize: const Size(0, 42),
              ),
              child: const Text(
                'Simpan Draft',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () {
                if (needsUw) {
                  _ajukanKeUW();
                } else {
                  _finalisasi();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orangeMbis,
                foregroundColor: AppColors.surfaceWhite,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                minimumSize: const Size(0, 42),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check, size: 18, color: AppColors.surfaceWhite),
                  const SizedBox(width: 8),
                  Text(
                    uwBtnLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Header mode Mobile (lebar < 1024px sesuai prototype isFormMobile)
  Widget _buildHeaderMobile() {
    final productLabel =
        _product == QsProduct.psakdi ? 'PSAKDI' : 'PA Xtra';
    const stepNames = [
      'Pertanggungan',
      'Uang Pertanggungan & Biaya Asuransi',
      'T/C (Syarat & Ketentuan)',
    ];
    final currentStepName = stepNames[_currentStep];

    return Container(
      color: AppColors.navyMbis,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Material(
                  color: AppColors.whiteAlpha12,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _onBack,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          size: 20,
                          color: AppColors.surfaceWhite,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QS Baru · $productLabel',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.surfaceWhite,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Langkah ${_currentStep + 1} dari 3 · $currentStepName',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.whiteAlpha78,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'No. $_nomorQs',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.badgeDraftText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.whiteAlpha14,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.surfaceWhite,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepSegment(0, 'Pertanggungan', flex: 100),
                const SizedBox(width: 6),
                _buildStepSegment(
                  1,
                  'Uang Pertanggungan & Biaya Asuransi',
                  flex: 170,
                ),
                const SizedBox(width: 6),
                _buildStepSegment(2, 'T/C', flex: 55),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepSegment(int stepIndex, String label, {required int flex}) {
    final cur = _currentStep == stepIndex;
    final done = _currentStep > stepIndex;
    final barColor = cur
        ? AppColors.orangeMbis
        : (done ? AppColors.surfaceWhite : AppColors.whiteAlpha25);
    final textColor = (cur || done)
        ? AppColors.surfaceWhite
        : AppColors.whiteAlpha72;
    final fw = cur ? FontWeight.w700 : FontWeight.w500;

    return Expanded(
      flex: flex,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 5,
              width: double.infinity,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.3,
                fontWeight: fw,
                color: textColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Auto-Fill Banner & Footer Legend
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildAutoFillBanner() {
    final customerName = _namaPolisCtrl.text.isNotEmpty
        ? _namaPolisCtrl.text
        : (widget.customerName ?? 'Customer');
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.greenLightBanner,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check,
              size: 18, color: AppColors.greenDarkText),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'Data dari customer ',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.greenDarkText,
                  height: 1.45,
                ),
                children: [
                  TextSpan(
                    text: customerName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(
                    text:
                        ' dan pipeline sudah terisi otomatis. Periksa kembali sebelum lanjut.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.blueInputText,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Teks biru = isian yang akan tampil di dokumen QS',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Bottom Sticky Bar (Total Premi + Lanjut / Preview QS)
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final totalVal = _premiResult?.total ?? 0;
    final totalLabel = _product == QsProduct.paXtra
        ? 'Biaya Asuransi'
        : 'Total Premi';
    final isCalculated = totalVal > 0;
    final totalColor =
        isCalculated ? AppColors.greenTotal : AppColors.orangeDark;
    final String totalText;
    if (isCalculated) {
      totalText = 'Rp ${_currFormat.format(totalVal)}';
    } else {
      if (_product == QsProduct.paXtra) {
        totalText = 'Belum terbentuk';
      } else if (_premiMode == QsPremiMode.flat) {
        totalText = 'Isi tarif flat';
      } else if (_premiMode == QsPremiMode.mutlak) {
        totalText = 'Isi premi mutlak';
      } else {
        totalText = 'Belum terbentuk';
      }
    }
    final nextBtnText = _currentStep < 2 ? 'Lanjut' : 'Preview QS';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border(top: BorderSide(color: AppColors.borderDivider)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    totalLabel,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    totalText,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: totalColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (_currentStep > 0) ...[
              Material(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _isSavingQs
                      ? null
                      : () {
                          FocusScope.of(context).unfocus();
                          setState(() => _currentStep--);
                        },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: AppColors.navyMbis, width: 1.5),
                    ),
                    child: const Center(
                      child: Icon(Icons.chevron_left,
                          size: 20, color: AppColors.navyMbis),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Material(
              color: AppColors.navyMbis,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _isSavingQs ? null : _onNextOrPreview,
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  child: _isSavingQs
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              nextBtnText,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.surfaceWhite,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right,
                                size: 18, color: AppColors.surfaceWhite),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  num _parseAmount(String text) {
    final clean = text.replaceAll('.', '').replaceAll(',', '').trim();
    return num.tryParse(clean) ?? 0;
  }

  num _parsePercentOrDecimal(String text) {
    final clean = text.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '').trim();
    return num.tryParse(clean) ?? 0;
  }

  Map<String, dynamic> _buildQuotationSlipPayload([int? step]) {
    final activeStep = step ?? _currentStep;
    final dateFormat = DateFormat('yyyy-MM-dd');

    // 1. Pemegang Polis & Data Step 1 (Pertanggungan)
    final pemegangPolis = {
      'tertanggung': _namaPolisCtrl.text.trim(),
      'alamat': _alamatCtrl.text.trim(),
      'bidang': _bidangUsahaCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'pic': _namaPicCtrl.text.trim(),
      'hpPic': _noHpPicCtrl.text.trim(),
    };

    // 2. Tipe Pertanggungan
    final tipePertanggungan = {
      'qType': _type == QsType.group ? 'Group' : 'Single',
      'jmlOrang': int.tryParse(_jumlahOrangCtrl.text.trim()) ?? 1,
      'aktivitas': _aktivitasCtrl.text.trim(),
    };

    // 3. Perhitungan Premi
    final perhitunganPremi = {
      'calcType': _premiMode == QsPremiMode.mutlak
          ? 'Mutlak'
          : (_premiMode == QsPremiMode.flat ? 'Flat' : 'Normal'),
    };

    // 4. Klasifikasi Peserta
    final klasifikasiPeserta = {
      'kelas': _klasifikasiPeserta?.toString() ?? '1',
    };

    // 5. Jangka Waktu
    final jangkaWaktu = {
      'start': _tglMulai != null ? dateFormat.format(_tglMulai!) : '',
      'end': _tglAkhir != null ? dateFormat.format(_tglAkhir!) : '',
    };

    // 6. Orang Dipertanggungkan
    final orangDipertanggungkan = {
      'samaDenganPP': _dataSamaPolis,
      'nama': _dataSamaPolis && _namaTertanggungCtrl.text.trim().isEmpty
          ? _namaPolisCtrl.text.trim()
          : _namaTertanggungCtrl.text.trim(),
      'ktp': _noKtpCtrl.text.trim(),
      'lahir': _tglLahir != null ? dateFormat.format(_tglLahir!) : '',
      'pekerjaan': _pekerjaanCtrl.text.trim(),
    };

    final payload = <String, dynamic>{
      'pemegangPolis': pemegangPolis,
      'tipePertanggungan': tipePertanggungan,
      'perhitunganPremi': perhitunganPremi,
      'klasifikasiPeserta': klasifikasiPeserta,
      'jangkaWaktu': jangkaWaktu,
      'orangDipertanggungkan': orangDipertanggungkan,
    };

    // 7. Step 2 (Uang Pertanggungan & Biaya Asuransi) - dikirim jika >= step 2 (index 1)
    if (activeStep >= 1) {
      final diskonPersenVal = _parsePercentOrDecimal(_diskonCtrl.text);
      final jenisPolisStr =
          _polisType == QsPolisType.ePolis ? 'EPOLIS' : 'CETAK';

      Map<String, dynamic> step2Map = {
        'discountPersen': diskonPersenVal,
        'jenisPolis': jenisPolisStr,
      };

      if (_product == QsProduct.psakdi) {
        final upMeninggalVal = _parseAmount(_upACtrl.text);
        final upPengobatanVal = _risikoC ? _parseAmount(_upCCtrl.text) : 0;

        String risikoDijaminText = _risikoDijaminCtrl.text.trim();
        if (risikoDijaminText.isEmpty) {
          risikoDijaminText = _riskType == PsakdiRiskType.ab
              ? 'Meninggal Dunia / Cacat Tetap${_risikoC ? " dan Biaya Pengobatan" : ""} yang disebabkan karena kecelakaan.'
              : 'Meninggal Dunia${_risikoC ? " dan Biaya Pengobatan" : ""} yang disebabkan karena kecelakaan.';
        }

        step2Map['psakdi'] = {
          'jenisRisiko': _riskType == PsakdiRiskType.ab ? 'AB' : 'A',
          'uangPertanggunganMeninggalDunia': upMeninggalVal,
          'uangPertanggunganBiayaPengobatan': upPengobatanVal,
          'risikoDijamin': risikoDijaminText,
        };
      } else {
        // PA Xtra
        final upPaXtraVal = _parseAmount(_upPaXtraCtrl.text);
        final pengobatanVal = _perawatanPengobatan
            ? _parseAmount(_santunanCtrls['pengobatan']?.text ?? '')
            : 0;

        step2Map['jaminanPokok'] = {
          'uangPertanggunganMeninggalDunia': upPaXtraVal,
        };
        step2Map['jaminanTambahan'] = {
          'cacatTetap': _cacatTetap,
          'biayaPerawatanPengobatan': pengobatanVal,
        };
        step2Map['perluasan'] = {
          'santunanAmbulansEvakuasi':
              _parseAmount(_santunanCtrls['ambulan']?.text ?? ''),
          'santunanPemakamanKremasi':
              _parseAmount(_santunanCtrls['pemakaman']?.text ?? ''),
          'santunanKehilanganBarangPribadi':
              _parseAmount(_santunanCtrls['barang']?.text ?? ''),
          'santunanPengurusanDokumen':
              _parseAmount(_santunanCtrls['dokumen']?.text ?? ''),
          'santunanBiayaPendidikan':
              _parseAmount(_santunanCtrls['pendidikan']?.text ?? ''),
          'santunanPemulanganJenazah':
              _parseAmount(_santunanCtrls['pemulangan']?.text ?? ''),
        };
      }

      payload['step2'] = step2Map;
    }

    // 8. Step 3 (T/C & Penerbitan) - dikirim jika >= step 3 (index 2)
    if (activeStep >= 2) {
      final step3Map = {
        'penerbitan': {
          'kota': _kotaCtrl.text.trim(),
          'tanggalTerbit': _tglPenerbitan != null
              ? dateFormat.format(_tglPenerbitan!)
              : '',
          'cabang': _cabangCtrl.text.trim(),
          'penandatangan': _penandatanganCtrl.text.trim(),
          'jabatanPenandatangan': _jabatanCtrl.text.trim(),
        },
      };

      payload['step3'] = step3Map;
    }

    if (_qsId != null && _qsId!.isNotEmpty) {
      payload['qsId'] = _qsId;
    }

    return payload;
  }

  Future<void> _onNextOrPreview() async {
    if (_isSavingQs) return;
    FocusScope.of(context).unfocus();

    // 1. Validasi form langkah aktif
    if (_currentStep == 0) {
      if (!(_formKey1.currentState?.validate() ?? true)) return;
    } else if (_currentStep == 1) {
      if (!(_formKey2.currentState?.validate() ?? true)) return;
    } else {
      if (!(_formKey3.currentState?.validate() ?? true)) return;
    }

    // 2. Simpan draft Quotation Slip via API POST jika ada pipelineId
    final pId = _pipelineId;
    if (pId != null && pId.isNotEmpty) {
      setState(() => _isSavingQs = true);
      try {
        final pCode = _productCode;

        final payload = _buildQuotationSlipPayload();
        final repo = ref.read(qsPertanggunganRepoProvider);
        final res = await repo.saveQuotationSlip(
          pipelineId: pId,
          productCode: pCode,
          payload: payload,
        );

        if (!mounted) return;

        setState(() {
          if (res.id != null && res.id!.isNotEmpty) {
            _qsId = res.id;
          }
          if (res.nomorQs != null && res.nomorQs!.isNotEmpty) {
            _serverNomorQs = res.nomorQs;
          }
          if (res.payload != null) {
            _apiResponse = res.payload;
            if (res.payload!.perhitunganBiaya != null) {
              _apiPerhitunganBiaya = res.payload!.perhitunganBiaya;
            }
          }
          _isSavingQs = false;

          // Berpindah step / preview setelah simpan berhasil
          if (_currentStep == 0) {
            _currentStep = 1;
          } else if (_currentStep == 1) {
            _currentStep = 2;
          } else {
            _isPreviewing = true;
            _fetchPreviewPdf(pId, pCode);
          }
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSavingQs = false);

        final cleanMsg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Gagal menyimpan draft QS: $cleanMsg',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } else {
      // Jika tanpa pipelineId, transisi langkah secara lokal
      setState(() {
        if (_currentStep == 0) {
          _currentStep = 1;
        } else if (_currentStep == 1) {
          _currentStep = 2;
        } else {
          _isPreviewing = true;
        }
      });
    }
  }

  void _onBack() {
    if (_isSavingQs) return;
    FocusScope.of(context).unfocus();
    if (_isPreviewing) {
      setState(() => _isPreviewing = false);
    } else if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.maybePop(context);
    }
  }

  String get _statusLabel {
    switch (_status) {
      case QsStatus.draft:
        return 'Draft';
      case QsStatus.menungguUw:
        return 'Menunggu UW';
      case QsStatus.ditolakUw:
        return 'Ditolak UW';
      case QsStatus.disetujuiUw:
        return 'Disetujui UW';
      case QsStatus.finalQs:
        return 'Final';
    }
  }

  Widget _currentStepWidget() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      default:
        return _buildStep1();
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Screen Preview QS (Sesuai Prototype isPreview)
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildPreviewScreen() {
    final hasDeviations = _deviations.isNotEmpty;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: AppColors.bgPreviewDoc,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Container(
          color: AppColors.navyMbis,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Material(
                  color: AppColors.whiteAlpha12,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _isPreviewing = false),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.arrow_back_ios_new,
                          size: 20, color: AppColors.surfaceWhite),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Preview QS',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.surfaceWhite,
                        ),
                      ),
                      Text(
                        'No. $_nomorQs',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.whiteAlpha78,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isPreviewing = false;
                      _currentStep = 0;
                    });
                  },
                  icon: const Icon(Icons.edit, size: 14, color: AppColors.surfaceWhite),
                  label: const Text(
                    'Edit',
                    style: TextStyle(
                        color: AppColors.surfaceWhite,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.whiteAlpha14,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (hasDeviations) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.alertBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.alertBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚠ Perlu Persetujuan Underwriting (UW)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.alertTitle,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ..._deviations.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '• ${d.message}',
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.alertText),
                        ),
                      )),
                ],
              ),
            ),
          ] else ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.badgeP1Bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle,
                      size: 18, color: AppColors.greenTotal),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ketentuan tarif & batas sesuai standar UW. Siap diterbitkan.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.greenTotal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Ubah: ',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textLabel),
                ),
                const SizedBox(width: 4),
                _jumpChip('Pertanggungan', 0),
                const SizedBox(width: 6),
                _jumpChip('Uang Pertanggungan & Biaya Asuransi', 1),
                const SizedBox(width: 6),
                _jumpChip('T/C', 2),
              ],
            ),
          ),
          Expanded(
            child: _buildPdfViewerContent(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: AppColors.surfaceWhite,
          border: Border(top: BorderSide(color: AppColors.borderDivider)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _simpanDraft,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.navyMbis),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Simpan Draft',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.navyMbis),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: hasDeviations
                    ? FilledButton.icon(
                        onPressed: _ajukanKeUW,
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text('Ajukan ke UW',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.orangeMbis,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: _finalisasi,
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('OK',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.navyMbis,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildPdfViewerContent() {
    if (_isLoadingPdf) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: AppColors.navyMbis,
              strokeWidth: 3,
            ),
            SizedBox(height: 16),
            Text(
              'Memuat preview dokumen QS (PDF)...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Mengambil data dari server MBIS',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    if (_pdfError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 28,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Gagal Memuat Dokumen PDF',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _pdfError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              if (_pipelineId != null && _pipelineId!.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _fetchPreviewPdf(_pipelineId!, _productCode),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Coba Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navyMbis,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (_previewPdfBytes != null && _previewPdfBytes!.isNotEmpty) {
      return Container(
        color: AppColors.bgPreviewDoc,
        child: PdfPreview(
          build: (format) => _previewPdfBytes!,
          useActions: false,
          canChangeOrientation: false,
          canChangePageFormat: false,
          canDebug: false,
          loadingWidget: const Center(
            child: CircularProgressIndicator(
              color: AppColors.navyMbis,
              strokeWidth: 3,
            ),
          ),
          scrollViewDecoration: const BoxDecoration(
            color: AppColors.bgPreviewDoc,
          ),
        ),
      );
    }

    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: AppColors.navyMbis,
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Menyiapkan pratinjau dokumen PDF...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _jumpChip(String label, int step) {
    return InkWell(
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() {
          _isPreviewing = false;
          _currentStep = step;
        });
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.borderTable),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.navyMbis,
          ),
        ),
      ),
    );
  }

  void _simpanDraft() {
    setState(() => _status = QsStatus.draft);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Draft QS tersimpan di pipeline'),
        backgroundColor: AppColors.navyMbis,
      ),
    );
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }


  // ────────────────────────────────────────────────────────────────────────
  // Step builders
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildStep1() {
    return QsStepPertanggungan(
      pipelineId: widget.pipelineId,
      productCode: widget.productCode,
      product: _product,
      type: _type,
      onTypeChanged: (t) => setState(() {
        _type = t;
        if (t == QsType.single) _jumlahOrangCtrl.text = '1';
      }),
      premiMode: _premiMode,
      onPremiModeChanged: (m) => setState(() => _premiMode = m),
      formKey: _formKey1,
      namaPolisCtrl: _namaPolisCtrl,
      alamatCtrl: _alamatCtrl,
      bidangUsahaCtrl: _bidangUsahaCtrl,
      emailCtrl: _emailCtrl,
      namaPicCtrl: _namaPicCtrl,
      noHpPicCtrl: _noHpPicCtrl,
      jumlahOrangCtrl: _jumlahOrangCtrl,
      aktivitasCtrl: _aktivitasCtrl,
      namaTertanggungCtrl: _namaTertanggungCtrl,
      noKtpCtrl: _noKtpCtrl,
      pekerjaanCtrl: _pekerjaanCtrl,
      tglLahir: _tglLahir,
      onTglLahirChanged: (d) => setState(() => _tglLahir = d),
      tglMulai: _tglMulai,
      onTglMulaiChanged: (d) => setState(() => _tglMulai = d),
      tglAkhir: _tglAkhir,
      onTglAkhirChanged: (d) => setState(() => _tglAkhir = d),
      dataSamaPolis: _dataSamaPolis,
      onDataSamaPolisChanged: (v) {
        setState(() {
          _dataSamaPolis = v;
          if (v) {
            _namaTertanggungCtrl.text = _namaPolisCtrl.text;
          }
        });
      },
      klasifikasiPeserta: _klasifikasiPeserta,
      onKlasifikasiChanged: (k) => setState(() => _klasifikasiPeserta = k),
    );
  }

  Widget _buildStep2() {
    return QsStepUangPertanggungan(
      product: _product,
      type: _type,
      premiMode: _premiMode,
      formKey: _formKey2,
      upACtrl: _upACtrl,
      riskType: _riskType,
      onRiskTypeChanged: (r) => setState(() {
        _riskType = r;
        if (r == PsakdiRiskType.a && _risikoC) {
          _risikoC = false;
          _upCCtrl.clear();
        }
      }),
      risikoC: _risikoC,
      onRisikoCChanged: (v) => setState(() => _risikoC = v),
      upCCtrl: _upCCtrl,
      rateABCtrl: _rateABCtrl,
      rateCCtrl: _rateCCtrl,
      upPaXtraCtrl: _upPaXtraCtrl,
      cacatTetap: _cacatTetap,
      onCacatTetapChanged: (v) => setState(() => _cacatTetap = v),
      perawatanPengobatan: _perawatanPengobatan,
      onPerawatanChanged: (v) => setState(() => _perawatanPengobatan = v),
      santunanCtrls: _santunanCtrls,
      risikoDijaminCtrl: _risikoDijaminCtrl,
      diskonCtrl: _diskonCtrl,
      polisType: _polisType,
      onPolisTypeChanged: (t) => setState(() => _polisType = t),
      premiMutlakPokokCtrl: _premiMutlakPokokCtrl,
      premiMutlakTambahanCtrl: _premiMutlakTambahanCtrl,
      tarifFlatCtrl: _tarifFlatCtrl,
      jumlahHari: _jumlahHari,
      jumlahOrang: _jumlahOrang,
      klasifikasiPeserta: _klasifikasiPeserta,
      deviations: _deviations,
      onJumpToStep1: () {
        FocusScope.of(context).unfocus();
        setState(() => _currentStep = 0);
      },
    );
  }

  Widget _buildStep3() {
    return QsStepTermsConditions(
      product: _product,
      formKey: _formKey3,
      kotaCtrl: _kotaCtrl,
      cabangCtrl: _cabangCtrl,
      penandatanganCtrl: _penandatanganCtrl,
      jabatanCtrl: _jabatanCtrl,
      tglPenerbitan: _tglPenerbitan,
      onTglPenerbitanChanged: (d) => setState(() => _tglPenerbitan = d),
      masaBerlaku: _masaBerlaku,
      onMasaBerlakuChanged: (d) => setState(() => _masaBerlaku = d),
      klausulTambahanCtrl: _klausulTambahanCtrl,
      kondisiTambahanCtrl: _kondisiTambahanCtrl,
      warantiTambahanCtrl: _warantiTambahanCtrl,
      pengecualianTambahanCtrl: _pengecualianTambahanCtrl,
      deductibleCtrl: _deductibleCtrl,
      standardKlausula: _termsKlausula,
      standardKondisi: _termsKondisi,
      standardWaranti: _termsWaranti,
      standardPengecualian: _termsPengecualian,
      namaFile: _namaFile,
      onPilihFile: () {
        // Mock file pick
        setState(() => _namaFile = 'KTP_contoh.pdf');
      },
      onHapusFile: _namaFile != null
          ? () => setState(() => _namaFile = null)
          : null,
    );
  }




  // ────────────────────────────────────────────────────────────────────────
  // Actions
  // ────────────────────────────────────────────────────────────────────────

  void _ajukanKeUW() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: AppRadius.radius2Xl),
        title: const Text('Ajukan ke UW',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'QS memiliki penyimpangan dari ketentuan standar UW. Ajukan ke Underwriting untuk persetujuan?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextFormField(
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Alasan / Catatan pengajuan *',
                border: OutlineInputBorder(
                    borderRadius: AppRadius.radiusLg),
                contentPadding: const EdgeInsets.all(14),
              ),
              style: AppInput.fieldText,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _status = QsStatus.menungguUw;
                _isPreviewing = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✓ QS berhasil diajukan ke Underwriting.'),
                  backgroundColor: AppColors.primaryNavy,
                ),
              );
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondaryOrange),
            child: const Text('Ajukan'),
          ),
        ],
      ),
    );
  }

  void _finalisasi() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: AppRadius.radius2Xl),
        title: const Text('Terbitkan & Finalkan QS?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: const Text(
          'Setelah OK, QS final dan terkunci. Nomor QS resmi terbentuk dan siap dikirim ke customer.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _status = QsStatus.finalQs);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '✓ QS final dan terkunci · No. $_nomorQs – siap dikirim ke customer'),
                  backgroundColor: AppColors.successGreen,
                ),
              );
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryNavy),
            child: const Text('OK – Terbitkan'),
          ),
        ],
      ),
    );
  }
}


