import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/providers/repository_providers.dart';
import '../qs_form_state.dart';
import '../qs_step_pertanggungan_provider.dart';
import 'pertanggungan/qs_pemegang_polis_card.dart';
import 'pertanggungan/qs_tipe_pertanggungan_card.dart';
import 'pertanggungan/qs_perhitungan_premi_card.dart';
import 'pertanggungan/qs_jangka_waktu_card.dart';
import 'pertanggungan/qs_tertanggung_card.dart';
import 'pertanggungan/qs_ketentuan_standar_card.dart';

/// Tab 1 – Pertanggungan: data pemegang polis, tipe pertanggungan, perhitungan premi,
/// periode/jangka waktu, orang yang dipertanggungkan, dan ketentuan standar.
///
/// Desain 1:1 mencerminkan Prototype_QS_M-BIS.html:
/// - 6 Section Cards beradius 16px dengan icon badge 36x36
/// - Textfield bernuansa dokumen QS (teks biru #0070C0, label 13px semibold)
/// - Quick chips untuk Bidang Usaha dan Pekerjaan
/// - Pilihan Type (Single/Group), Durasi (+1 Tahun), dan Radio Card Mode Premi (Normal/Mutlak/Flat)
/// - Pilihan Ya/Tidak untuk data orang sama dengan pemegang polis
/// - Klasifikasi Peserta dengan rekomendasi sistem dan blokir Kelas 4 (ajukan manual UW)
/// - Accordion Ketentuan Standar
class QsStepPertanggungan extends ConsumerStatefulWidget {
  final QsProduct product;
  final QsType type;
  final ValueChanged<QsType> onTypeChanged;
  final QsPremiMode premiMode;
  final ValueChanged<QsPremiMode> onPremiModeChanged;
  final GlobalKey<FormState> formKey;

  final String? pipelineId;
  final String? productCode;

  // Controllers passed from parent
  final TextEditingController namaPolisCtrl;
  final TextEditingController alamatCtrl;
  final TextEditingController bidangUsahaCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController namaPicCtrl;
  final TextEditingController noHpPicCtrl;
  final TextEditingController jumlahOrangCtrl;
  final TextEditingController aktivitasCtrl;
  final TextEditingController namaTertanggungCtrl;
  final TextEditingController noKtpCtrl;
  final TextEditingController pekerjaanCtrl;

  final DateTime? tglLahir;
  final ValueChanged<DateTime?> onTglLahirChanged;
  final DateTime? tglMulai;
  final ValueChanged<DateTime?> onTglMulaiChanged;
  final DateTime? tglAkhir;
  final ValueChanged<DateTime?> onTglAkhirChanged;
  final bool dataSamaPolis;
  final ValueChanged<bool> onDataSamaPolisChanged;
  final int? klasifikasiPeserta;
  final ValueChanged<int?> onKlasifikasiChanged;

  const QsStepPertanggungan({
    super.key,
    this.pipelineId,
    this.productCode,
    required this.product,
    required this.type,
    required this.onTypeChanged,
    required this.premiMode,
    required this.onPremiModeChanged,
    required this.formKey,
    required this.namaPolisCtrl,
    required this.alamatCtrl,
    required this.bidangUsahaCtrl,
    required this.emailCtrl,
    required this.namaPicCtrl,
    required this.noHpPicCtrl,
    required this.jumlahOrangCtrl,
    required this.aktivitasCtrl,
    required this.namaTertanggungCtrl,
    required this.noKtpCtrl,
    required this.pekerjaanCtrl,
    required this.tglLahir,
    required this.onTglLahirChanged,
    required this.tglMulai,
    required this.onTglMulaiChanged,
    required this.tglAkhir,
    required this.onTglAkhirChanged,
    required this.dataSamaPolis,
    required this.onDataSamaPolisChanged,
    required this.klasifikasiPeserta,
    required this.onKlasifikasiChanged,
  });

  @override
  ConsumerState<QsStepPertanggungan> createState() =>
      _QsStepPertanggunganState();
}

class _QsStepPertanggunganState extends ConsumerState<QsStepPertanggungan> {
  late final TextEditingController _tglLahirGroupCtrl;
  bool _isLoadingInitial = false;
  String? _initialError;

  @override
  void initState() {
    super.initState();
    _tglLahirGroupCtrl = TextEditingController(text: 'TBA');
    _isLoadingInitial = (widget.pipelineId != null &&
        widget.pipelineId!.isNotEmpty &&
        widget.namaPolisCtrl.text.isEmpty);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(qsStepPertanggunganProvider.notifier).init(
              product: widget.product,
              type: widget.type,
              premiMode: widget.premiMode,
              tglLahir: widget.tglLahir,
              tglMulai: widget.tglMulai,
              tglAkhir: widget.tglAkhir,
              dataSamaPolis: widget.dataSamaPolis,
              klasifikasiPeserta: widget.klasifikasiPeserta,
              pekerjaan: widget.pekerjaanCtrl.text,
            );
        if (_isLoadingInitial) {
          _fetchInitialData();
        }
      }
    });
  }

  Future<void> _fetchInitialData() async {
    final pId = widget.pipelineId;
    final pCode = (widget.productCode != null && widget.productCode!.isNotEmpty)
        ? widget.productCode!
        : (widget.product == QsProduct.psakdi ? 'PSAKDI' : 'Personal Accident Xtra Insurance');

    if (pId == null || pId.isEmpty || widget.namaPolisCtrl.text.isNotEmpty) {
      if (mounted) {
        setState(() => _isLoadingInitial = false);
      }
      return;
    }

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

      // 1. Pemegang Polis
      final pp = res.pemegangPolis;
      if (pp != null) {
        if (pp.tertanggung != null && pp.tertanggung!.isNotEmpty) {
          widget.namaPolisCtrl.text = pp.tertanggung!;
        }
        if (pp.alamat != null) widget.alamatCtrl.text = pp.alamat!;
        if (pp.bidang != null) widget.bidangUsahaCtrl.text = pp.bidang!;
        if (pp.email != null) widget.emailCtrl.text = pp.email!;
        if (pp.pic != null) widget.namaPicCtrl.text = pp.pic!;
        if (pp.hpPic != null) widget.noHpPicCtrl.text = pp.hpPic!;
      }

      // 2. Tipe Pertanggungan
      final tp = res.tipePertanggungan;
      QsType resolvedType = widget.type;
      if (tp != null) {
        final qTypeStr = (tp.qType ?? '').trim().toLowerCase();
        resolvedType = (qTypeStr == 'group') ? QsType.group : QsType.single;
        widget.onTypeChanged(resolvedType);
        ref.read(qsStepPertanggunganProvider.notifier).setType(resolvedType);

        if (tp.jmlOrang != null) {
          widget.jumlahOrangCtrl.text = tp.jmlOrang.toString();
        }
        if (tp.aktivitas != null) {
          widget.aktivitasCtrl.text = tp.aktivitas!;
        }
      }

      // 3. Perhitungan Premi
      final ppPrem = res.perhitunganPremi;
      QsPremiMode resolvedPremiMode = widget.premiMode;
      if (ppPrem != null) {
        final calcStr = (ppPrem.calcType ?? '').trim().toLowerCase();
        if (calcStr.contains('mutlak')) {
          resolvedPremiMode = QsPremiMode.mutlak;
        } else if (calcStr.contains('flat')) {
          resolvedPremiMode = QsPremiMode.flat;
        } else {
          resolvedPremiMode = QsPremiMode.normal;
        }
        widget.onPremiModeChanged(resolvedPremiMode);
        ref.read(qsStepPertanggunganProvider.notifier).setPremiMode(resolvedPremiMode);
      }

      // 4. Jangka Waktu
      final jw = res.jangkaWaktu;
      DateTime? resolvedStart = widget.tglMulai;
      DateTime? resolvedEnd = widget.tglAkhir;
      if (jw != null) {
        if (jw.start != null && jw.start!.isNotEmpty) {
          final sDate = DateTime.tryParse(jw.start!);
          if (sDate != null) {
            resolvedStart = sDate;
            widget.onTglMulaiChanged(sDate);
            ref.read(qsStepPertanggunganProvider.notifier).setTglMulai(sDate);
          }
        }
        if (jw.end != null && jw.end!.isNotEmpty) {
          final eDate = DateTime.tryParse(jw.end!);
          if (eDate != null) {
            resolvedEnd = eDate;
            widget.onTglAkhirChanged(eDate);
            ref.read(qsStepPertanggunganProvider.notifier).setTglAkhir(eDate);
          }
        }
      }

      // 5. Orang Dipertanggungkan
      final od = res.orangDipertanggungkan;
      DateTime? resolvedLahir = widget.tglLahir;
      bool resolvedSamaPP = widget.dataSamaPolis;
      if (od != null) {
        resolvedSamaPP = od.samaDenganPP ?? true;
        widget.onDataSamaPolisChanged(resolvedSamaPP);
        ref.read(qsStepPertanggunganProvider.notifier).setDataSamaPolis(resolvedSamaPP);

        if (od.nama != null && od.nama!.isNotEmpty) {
          widget.namaTertanggungCtrl.text = od.nama!;
        } else if (resolvedSamaPP && widget.namaPolisCtrl.text.isNotEmpty) {
          widget.namaTertanggungCtrl.text = widget.namaPolisCtrl.text;
        }

        if (od.ktp != null) {
          widget.noKtpCtrl.text = od.ktp!;
        } else {
          widget.noKtpCtrl.text = '';
        }

        if (od.lahir != null && od.lahir!.isNotEmpty) {
          final lDate = DateTime.tryParse(od.lahir!);
          resolvedLahir = lDate;
          widget.onTglLahirChanged(lDate);
          ref.read(qsStepPertanggunganProvider.notifier).setTglLahir(lDate);
        } else {
          resolvedLahir = null;
          widget.onTglLahirChanged(null);
          ref.read(qsStepPertanggunganProvider.notifier).setTglLahir(null);
        }

        if (od.pekerjaan != null && od.pekerjaan!.isNotEmpty) {
          widget.pekerjaanCtrl.text = od.pekerjaan!;
          ref.read(qsStepPertanggunganProvider.notifier).setPekerjaan(od.pekerjaan!);
        } else {
          widget.pekerjaanCtrl.text = '';
          ref.read(qsStepPertanggunganProvider.notifier).setPekerjaan('');
        }
      }

      // Sinkronkan ulang notifier state secara menyeluruh
      ref.read(qsStepPertanggunganProvider.notifier).init(
            product: widget.product,
            type: resolvedType,
            premiMode: resolvedPremiMode,
            tglLahir: resolvedLahir,
            tglMulai: resolvedStart,
            tglAkhir: resolvedEnd,
            dataSamaPolis: resolvedSamaPP,
            klasifikasiPeserta: widget.klasifikasiPeserta,
            pekerjaan: widget.pekerjaanCtrl.text,
          );

      setState(() {
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

  @override
  void didUpdateWidget(covariant QsStepPertanggungan oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product != widget.product ||
        oldWidget.type != widget.type ||
        oldWidget.premiMode != widget.premiMode ||
        oldWidget.tglLahir != widget.tglLahir ||
        oldWidget.tglMulai != widget.tglMulai ||
        oldWidget.tglAkhir != widget.tglAkhir ||
        oldWidget.dataSamaPolis != widget.dataSamaPolis ||
        oldWidget.klasifikasiPeserta != widget.klasifikasiPeserta) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final current = ref.read(qsStepPertanggunganProvider);
          if (current.product != widget.product ||
              current.type != widget.type ||
              current.premiMode != widget.premiMode ||
              current.tglLahir != widget.tglLahir ||
              current.tglMulai != widget.tglMulai ||
              current.tglAkhir != widget.tglAkhir ||
              current.dataSamaPolis != widget.dataSamaPolis ||
              current.klasifikasiPeserta != widget.klasifikasiPeserta) {
            ref.read(qsStepPertanggunganProvider.notifier).init(
                  product: widget.product,
                  type: widget.type,
                  premiMode: widget.premiMode,
                  tglLahir: widget.tglLahir,
                  tglMulai: widget.tglMulai,
                  tglAkhir: widget.tglAkhir,
                  dataSamaPolis: widget.dataSamaPolis,
                  klasifikasiPeserta: widget.klasifikasiPeserta,
                  pekerjaan: widget.pekerjaanCtrl.text,
                );
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _tglLahirGroupCtrl.dispose();
    super.dispose();
  }

  int get _jumlahHari =>
      ref.watch(qsStepPertanggunganProvider.select((s) => s.jumlahHari));

  bool get _isEndBad =>
      ref.watch(qsStepPertanggunganProvider.select((s) => s.isEndBad));

  int? get _saranKelas =>
      ref.watch(qsStepPertanggunganProvider.select((s) => s.saranKelasResult));

  String? get _usiaError {
    final type =
        ref.watch(qsStepPertanggunganProvider.select((s) => s.type));
    if (type == QsType.group) return null;
    return ref.watch(qsStepPertanggunganProvider.select((s) => s.usiaError));
  }

  bool get _showStd =>
      ref.watch(qsStepPertanggunganProvider.select((s) => s.showStd));

  @override
  Widget build(BuildContext context) {
    final stepState = ref.watch(qsStepPertanggunganProvider);
    final notifier = ref.read(qsStepPertanggunganProvider.notifier);

    return Skeletonizer(
      enabled: _isLoadingInitial,
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          if (_isLoadingInitial) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Memuat data auto-fill dari pipeline...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1E40AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_initialError != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gagal memuat auto-fill: $_initialError',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                    ),
                  ),
                  TextButton(
                    onPressed: _fetchInitialData,
                    child: const Text('Coba Lagi', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
          // 1. Pemegang Polis
          QsPemegangPolisCard(
            namaPolisCtrl: widget.namaPolisCtrl,
            alamatCtrl: widget.alamatCtrl,
            bidangUsahaCtrl: widget.bidangUsahaCtrl,
            emailCtrl: widget.emailCtrl,
            namaPicCtrl: widget.namaPicCtrl,
            noHpPicCtrl: widget.noHpPicCtrl,
            dataSamaPolis: widget.dataSamaPolis,
            namaTertanggungCtrl: widget.namaTertanggungCtrl,
            onFieldChanged: () => setState(() {}),
          ),
          const SizedBox(height: 14),

          // 2. Tipe Pertanggungan
          QsTipePertanggunganCard(
            type: stepState.type,
            onTypeChanged: (t) {
              notifier.setType(t);
              widget.onTypeChanged(t);
            },
            jumlahOrangCtrl: widget.jumlahOrangCtrl,
            noKtpCtrl: widget.noKtpCtrl,
            aktivitasCtrl: widget.aktivitasCtrl,
          ),
          const SizedBox(height: 14),

          // 3. Perhitungan Premi
          QsPerhitunganPremiCard(
            premiMode: stepState.premiMode,
            onPremiModeChanged: (m) {
              notifier.setPremiMode(m);
              widget.onPremiModeChanged(m);
            },
          ),
          const SizedBox(height: 14),

          // 4. Jangka Waktu Pertanggungan
          QsJangkaWaktuCard(
            tglMulai: stepState.tglMulai,
            onTglMulaiChanged: (d) {
              notifier.setTglMulai(d);
              widget.onTglMulaiChanged(d);
            },
            tglAkhir: stepState.tglAkhir,
            onTglAkhirChanged: (d) {
              notifier.setTglAkhir(d);
              widget.onTglAkhirChanged(d);
            },
            jumlahHari: _jumlahHari,
            isEndBad: _isEndBad,
          ),
          const SizedBox(height: 14),

          // 5. Orang yang Dipertanggungkan
          QsTertanggungCard(
            product: widget.product,
            type: stepState.type,
            dataSamaPolis: stepState.dataSamaPolis,
            onDataSamaPolisChanged: (val) {
              notifier.setDataSamaPolis(val);
              widget.onDataSamaPolisChanged(val);
            },
            namaPolis: widget.namaPolisCtrl.text,
            namaTertanggungCtrl: widget.namaTertanggungCtrl,
            noKtpCtrl: widget.noKtpCtrl,
            tglLahir: stepState.tglLahir,
            onTglLahirChanged: (d) {
              notifier.setTglLahir(d);
              widget.onTglLahirChanged(d);
            },
            tglLahirGroupCtrl: _tglLahirGroupCtrl,
            refDate: stepState.tglMulai ?? DateTime.now(),
            usiaError: _usiaError,
            pekerjaanCtrl: widget.pekerjaanCtrl,
            onPekerjaanChanged: (p) => notifier.setPekerjaan(p),
            saranKelas: _saranKelas,
            klasifikasiPeserta: stepState.klasifikasiPeserta,
            onKlasifikasiChanged: (k) {
              notifier.setKlasifikasiPeserta(k);
              widget.onKlasifikasiChanged(k);
            },
            onFieldChanged: () => setState(() {}),
          ),
          const SizedBox(height: 14),

          // 6. Ketentuan Standar (Accordion)
          QsKetentuanStandarCard(
            product: widget.product,
            showStd: _showStd,
            onToggleShowStd: () => notifier.toggleShowStd(),
          ),
        ],
      ),
    ),
  );
}
}
