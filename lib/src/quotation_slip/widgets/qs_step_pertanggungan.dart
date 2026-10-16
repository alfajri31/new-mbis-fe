import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../qs_form_state.dart';
import '../qs_step_pertanggungan_provider.dart';
import '../../../theme/app_theme.dart';

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

  static const _chBidang = [
    'Percetakan',
    'Perdagangan',
    'Jasa',
    'Manufaktur',
    'Konstruksi'
  ];

  static const _chKerja = [
    'Karyawan',
    'Wiraswasta',
    'PNS / BUMN',
    'Ibu Rumah Tangga',
    'Sopir',
    'Pekerja Tambang'
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

  late final TextEditingController _tglLahirGroupCtrl;

  @override
  void initState() {
    super.initState();
    _tglLahirGroupCtrl = TextEditingController(text: 'TBA');
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
      }
    });
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

    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Pemegang Polis
          _buildSectionCard(
            icon: Icons.person_outline,
            title: 'Pemegang Polis',
            subtitle: 'Nama dan alamat yang tercantum di dokumen QS',
            children: [
              _buildTextInput(
                label: 'Nama Pemegang Polis',
                required: true,
                controller: widget.namaPolisCtrl,
                placeholder: 'Nama perorangan / perusahaan',
                onChanged: (_) {
                  if (widget.dataSamaPolis) {
                    widget.namaTertanggungCtrl.text = widget.namaPolisCtrl.text;
                  }
                  setState(() {});
                },
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              _buildTextArea(
                label: 'Alamat',
                required: true,
                controller: widget.alamatCtrl,
                placeholder: 'Alamat lengkap',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Bidang Usaha', required: true),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: widget.bidangUsahaCtrl,
                    cursorColor: AppColors.orangeMbis,
                    onChanged: (_) => setState(() {}),
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
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
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
                        borderSide: BorderSide(
                            color: AppColors.orangeMbis, width: 2.0),
                      ),
                      errorBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(
                            color: AppColors.redRequired, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _chBidang.map((chip) {
                      final isSel = widget.bidangUsahaCtrl.text == chip;
                      return _buildQuickChip(
                        label: chip,
                        isSelected: isSel,
                        onTap: () {
                          setState(() {
                            widget.bidangUsahaCtrl.text = chip;
                          });
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
              _buildTextInput(
                label: 'Email Pemegang Polis',
                controller: widget.emailCtrl,
                placeholder: 'nama@perusahaan.co.id',
                helperText:
                    'Link quotation dikirim ke email ini. Wajib saat "Kirim ke Customer".',
                keyboardType: TextInputType.emailAddress,
              ),
              _buildTextInput(
                label: 'Nama PIC (opsional)',
                controller: widget.namaPicCtrl,
                placeholder: 'mis. Ibu Sari – HRD',
                helperText: 'Untuk pemegang polis perusahaan / Group.',
              ),
              _buildTextInput(
                label: 'No. HP PIC (opsional)',
                controller: widget.noHpPicCtrl,
                placeholder: '08xxxxxxxxx',
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. Tipe Pertanggungan
          _buildSectionCard(
            icon: Icons.person_outline,
            title: 'Tipe Pertanggungan',
            subtitle: 'Single: 1 orang · Group: banyak orang',
            children: [
              _buildLabel('Type', required: true),
              const SizedBox(height: 6),
              DropdownButtonFormField<QsType>(
                key: ValueKey(stepState.type),
                initialValue: stepState.type,
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
                  notifier.setType(newType);
                  widget.onTypeChanged(newType);
                  if (newType == QsType.single) {
                    widget.jumlahOrangCtrl.text = '1';
                    if (widget.noKtpCtrl.text == 'TBA' ||
                        widget.noKtpCtrl.text == '-') {
                      widget.noKtpCtrl.text = '';
                    }
                  } else {
                    if (widget.jumlahOrangCtrl.text == '1' ||
                        widget.jumlahOrangCtrl.text.isEmpty) {
                      widget.jumlahOrangCtrl.text = '25';
                    }
                    if (widget.noKtpCtrl.text.trim().isEmpty ||
                        RegExp(r'^\d+$').hasMatch(widget.noKtpCtrl.text.trim())) {
                      widget.noKtpCtrl.text = 'TBA';
                    }
                  }
                },
              ),
              const SizedBox(height: 14),
              _buildLabel('Jumlah Orang', required: true),
              const SizedBox(height: 6),
              TextFormField(
                controller: widget.jumlahOrangCtrl,
                enabled: stepState.type == QsType.group,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                cursorColor: AppColors.orangeMbis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: stepState.type == QsType.single
                      ? AppColors.iconDropdown
                      : AppColors.blueInputText,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: stepState.type == QsType.single
                      ? AppColors.bgDisabled
                      : Colors.white,
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
                      color: stepState.type == QsType.single
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
                  if (stepState.type == QsType.group) {
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
                stepState.type == QsType.single
                    ? 'Terkunci 1 orang karena Type = Single. Pilih Group untuk mengubah.'
                    : 'Wajib diisi, minimal 2 orang untuk Type Group.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
              if (stepState.type == QsType.group) ...[
                const SizedBox(height: 14),
                _buildTextInput(
                  label: 'Aktivitas/Kegiatan',
                  required: true,
                  controller: widget.aktivitasCtrl,
                  placeholder: 'mis. Manufacture, Sekolah, Outbond',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                ),
              ],
            ],
          ),

          const SizedBox(height: 14),

          // 3. Perhitungan Premi
          _buildSectionCard(
            icon: Icons.paid_outlined,
            title: 'Perhitungan Premi',
            requiredTitle: true,
            subtitle: 'Pilih cara menghitung premi',
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildCalcModeCard(
                      label: 'Normal',
                      desc: 'Rate × UP',
                      isSelected: stepState.premiMode == QsPremiMode.normal,
                      onTap: () {
                        notifier.setPremiMode(QsPremiMode.normal);
                        widget.onPremiModeChanged(QsPremiMode.normal);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCalcModeCard(
                      label: 'Mutlak',
                      desc: 'Nominal premi',
                      isSelected: stepState.premiMode == QsPremiMode.mutlak,
                      onTap: () {
                        notifier.setPremiMode(QsPremiMode.mutlak);
                        widget.onPremiModeChanged(QsPremiMode.mutlak);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCalcModeCard(
                      label: 'Flat',
                      desc: 'Tarif per hari',
                      isSelected: stepState.premiMode == QsPremiMode.flat,
                      onTap: () {
                        notifier.setPremiMode(QsPremiMode.flat);
                        widget.onPremiModeChanged(QsPremiMode.flat);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 4. Jangka Waktu Pertanggungan
          _buildSectionCard(
            icon: Icons.calendar_today_outlined,
            title: 'Jangka Waktu Pertanggungan',
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildDatePicker(
                      label: 'Mulai',
                      required: true,
                      value: stepState.tglMulai,
                      onChanged: (d) {
                        notifier.setTglMulai(d);
                        widget.onTglMulaiChanged(d);
                        if (d != null && stepState.tglAkhir == null) {
                          final nextYear =
                              DateTime(d.year + 1, d.month, d.day);
                          notifier.setTglAkhir(nextYear);
                          widget.onTglAkhirChanged(nextYear);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDatePicker(
                      label: 'Sampai dengan',
                      required: true,
                      value: stepState.tglAkhir,
                      onChanged: (d) {
                        notifier.setTglAkhir(d);
                        widget.onTglAkhirChanged(d);
                      },
                    ),
                  ),
                ],
              ),
              if (_isEndBad) ...[
                const SizedBox(height: 6),
                const Text(
                  'Tanggal akhir harus setelah tanggal mulai.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.redRequired,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _jumlahHari > 0
                        ? 'Masa Pertanggungan: $_jumlahHari hari'
                        : 'Pilih tanggal mulai, akhir otomatis +1 tahun',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: stepState.tglMulai == null
                        ? null
                        : () {
                            final m = stepState.tglMulai!;
                            final nextYear =
                                DateTime(m.year + 1, m.month, m.day);
                            notifier.setTglAkhir(nextYear);
                            widget.onTglAkhirChanged(nextYear);
                          },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: AppColors.borderDefault, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      minimumSize: const Size(0, 34),
                    ),
                    child: const Text(
                      'Set 1 tahun',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navyMbis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Kedua tanggal berlaku pukul 12.00 siang waktu setempat di mana orang yang dipertanggungkan berada.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 5. Orang yang Dipertanggungkan
          _buildSectionCard(
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
                      _buildPillButton(
                        label: 'Ya',
                        isSelected: stepState.dataSamaPolis,
                        activeColor: AppColors.greenTotal,
                        onTap: () {
                          notifier.setDataSamaPolis(true);
                          widget.onDataSamaPolisChanged(true);
                          if (widget.namaPolisCtrl.text.isNotEmpty) {
                            widget.namaTertanggungCtrl.text =
                                widget.namaPolisCtrl.text;
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                      _buildPillButton(
                        label: 'Tidak',
                        isSelected: !stepState.dataSamaPolis,
                        activeColor: AppColors.redRequired,
                        onTap: () {
                          notifier.setDataSamaPolis(false);
                          widget.onDataSamaPolisChanged(false);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTextInput(
                label: stepState.type == QsType.group
                    ? 'Nama / Kelompok Peserta'
                    : 'Nama',
                required: true,
                controller: widget.namaTertanggungCtrl,
                placeholder: stepState.type == QsType.group
                    ? 'mis. Karyawan/wati, Siswa/Siswi'
                    : 'Nama sesuai KTP',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              _buildTextInput(
                label: 'Nomor KTP (NIK)',
                required: stepState.type == QsType.single,
                controller: widget.noKtpCtrl,
                placeholder: '16 digit NIK',
                keyboardType: stepState.type == QsType.single
                    ? TextInputType.number
                    : TextInputType.text,
                maxLength: stepState.type == QsType.single ? 16 : null,
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (stepState.type == QsType.single) {
                    if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                  }
                  return null;
                },
              ),
              Builder(builder: (context) {
                final len = widget.noKtpCtrl.text.length;
                final isWarning =
                    stepState.type == QsType.single && len > 0 && len != 16;
                return Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 8),
                  child: Text(
                    stepState.type == QsType.group
                        ? 'Untuk Group boleh diisi TBA atau -'
                        : '$len/16 digit${isWarning ? ' · NIK umumnya 16 digit, mohon cek kembali' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: stepState.type == QsType.group
                          ? AppColors.textMuted
                          : (isWarning
                              ? AppColors.warningNik
                              : AppColors.textMuted),
                    ),
                  ),
                );
              }),
              if (stepState.type == QsType.single) ...[
                _buildDatePicker(
                  label: 'Tanggal Lahir',
                  required: true,
                  value: stepState.tglLahir,
                  onChanged: (d) {
                    notifier.setTglLahir(d);
                    widget.onTglLahirChanged(d);
                  },
                ),
                if (stepState.tglLahir != null) ...[
                  Builder(builder: (context) {
                    final lahir = stepState.tglLahir!;
                    final refDate = stepState.tglMulai ?? DateTime.now();
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
                if (_usiaError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _usiaError!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.redRequired,
                    ),
                  ),
                ],
              ] else ...[
                _buildTextInput(
                  label: 'Tanggal Lahir',
                  required: false,
                  controller: _tglLahirGroupCtrl,
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
                  _buildLabel('Pekerjaan',
                      required: stepState.type == QsType.single),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: widget.pekerjaanCtrl,
                    cursorColor: AppColors.orangeMbis,
                    onChanged: (v) {
                      notifier.setPekerjaan(v);
                      setState(() {});
                    },
                    validator: (v) {
                      if (stepState.type == QsType.single) {
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
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
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
                        borderSide: BorderSide(
                            color: AppColors.orangeMbis, width: 2.0),
                      ),
                      errorBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(
                            color: AppColors.redRequired, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _chKerja.map((chip) {
                      final isSel = widget.pekerjaanCtrl.text == chip;
                      return _buildQuickChip(
                        label: chip,
                        isSelected: isSel,
                        onTap: () {
                          widget.pekerjaanCtrl.text = chip;
                          notifier.setPekerjaan(chip);
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  if (_saranKelas == 4) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
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
                                  'Pekerjaan “${widget.pekerjaanCtrl.text}” termasuk Kelas 4 (pekerjaan berat & berbahaya). QS tidak dapat dilanjutkan walaupun perhitungan Mutlak/Flat.',
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
              if (widget.product == QsProduct.psakdi) ...[
                const SizedBox(height: 14),
                _buildLabel('Klasifikasi Peserta', required: true),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: stepState.klasifikasiPeserta,
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
                  onChanged: (v) {
                    notifier.setKlasifikasiPeserta(v);
                    widget.onKlasifikasiChanged(v);
                  },
                ),
                if (_saranKelas != null &&
                    _saranKelas != stepState.klasifikasiPeserta) ...[
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
                            'Saran sistem: Kelas $_saranKelas berdasarkan pekerjaan "${widget.pekerjaanCtrl.text}"',
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
                            notifier.setKlasifikasiPeserta(_saranKelas);
                            widget.onKlasifikasiChanged(_saranKelas);
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
                if (stepState.klasifikasiPeserta == 4) ...[
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
                ] else if (widget.klasifikasiPeserta != null) ...[
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    final item = _kelasInfo.firstWhere(
                        (x) => x['v'] == widget.klasifikasiPeserta);
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
          ),

          const SizedBox(height: 14),

          // 6. Ketentuan Standar (Accordion)
          _buildAccordionCard(),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Section Box Card Component
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    bool requiredTitle = false,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.blueLightBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.navyMbis),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (requiredTitle)
                          const Text(
                            '*',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.redRequired,
                            ),
                          ),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Form Field Components
  // ────────────────────────────────────────────────────────────────────────

  Widget _buildLabel(String text, {bool required = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textLabel,
          ),
        ),
        if (required)
          const Text(
            '*',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.redRequired,
            ),
          ),
      ],
    );
  }

  Widget _buildTextInput({
    required String label,
    bool required = false,
    required TextEditingController controller,
    String? placeholder,
    String? helperText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(label, required: required),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            onChanged: onChanged,
            validator: validator,
            cursorColor: AppColors.orangeMbis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.blueInputText,
            ),
            decoration: InputDecoration(
              hintText: placeholder,
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
                borderSide:
                    const BorderSide(color: AppColors.borderDefault, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.borderDefault, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.orangeMbis, width: 2.0),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.redRequired, width: 1.5),
              ),
            ),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 6),
            Text(
              helperText,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextArea({
    required String label,
    bool required = false,
    required TextEditingController controller,
    String? placeholder,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(label, required: required),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            maxLines: 2,
            validator: validator,
            cursorColor: AppColors.orangeMbis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.blueInputText,
              height: 1.45,
            ),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: const TextStyle(
                fontSize: 14,
                color: AppColors.textPlaceholder,
                fontWeight: FontWeight.w400,
              ),
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
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.orangeMbis, width: 2.0),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.redRequired, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    bool required = false,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) {
    return FormField<DateTime>(
      validator: required
          ? (_) => value == null ? 'Wajib diisi' : null
          : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(label, required: required),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(1940),
                lastDate: DateTime(2100),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: Theme.of(ctx).colorScheme.copyWith(
                          primary: AppColors.navyMbis,
                        ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                onChanged(picked);
                field.didChange(picked);
              }
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
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
                          : 'dd/mm/yyyy',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            value != null ? FontWeight.w600 : FontWeight.w400,
                        color: value != null
                            ? AppColors.blueInputText
                            : AppColors.textPlaceholder,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: AppColors.textMuted,
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
      ),
    );
  }

  Widget _buildQuickChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blueLightBg : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? AppColors.navyMbis
                : AppColors.borderDefault,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.navyMbis : AppColors.textLabel,
          ),
        ),
      ),
    );
  }


  Widget _buildPillButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color activeColor = AppColors.navyMbis,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.borderDefault,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textLabel,
          ),
        ),
      ),
    );
  }

  Widget _buildCalcModeCard({
    required String label,
    required String desc,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navyMbis : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.navyMbis
                : AppColors.borderDefault,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style: TextStyle(
                fontSize: 11.5,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccordionCard() {
    final prodWording = widget.product == QsProduct.psakdi
        ? 'Polis Standar Asuransi Kecelakaan Diri Indonesia'
        : 'Personal Accident Xtra Insurance';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () =>
                ref.read(qsStepPertanggunganProvider.notifier).toggleShowStd(),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                const Icon(Icons.lock_outline,
                    size: 18, color: AppColors.textMuted),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Ketentuan standar (tidak dapat diubah)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Text(
                  _showStd ? 'Tutup' : 'Lihat',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navyMbis,
                  ),
                ),
              ],
            ),
          ),
          if (_showStd) ...[
            const SizedBox(height: 12),
            Column(
              children: [
                _buildStdDashedItem(
                  title: 'JENIS PERTANGGUNGAN',
                  desc: 'Asuransi Kecelakaan Diri',
                ),
                const SizedBox(height: 10),
                _buildStdDashedItem(
                  title: 'WORDING',
                  desc: prodWording,
                ),
                const SizedBox(height: 10),
                _buildStdDashedItem(
                  title: 'RISIKO SENDIRI',
                  desc: 'Nil',
                ),
                const SizedBox(height: 10),
                _buildStdDashedItem(
                  title: 'KLAUSULA, KONDISI & WARANTI',
                  desc: 'Terlampir',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStdDashedItem({
    required String title,
    required String desc,
  }) {
    return CustomPaint(
      painter: DashedRectPainter(
        color: AppColors.borderDashed,
        strokeWidth: 1.0,
        gap: 5.0,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgLightGray,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child:
                  Icon(Icons.lock_outline, size: 16, color: AppColors.textMuted),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                      height: 1.4,
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
}
