import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../src/visit/visit_gallery.dart';
import '../../src/visit/visit_photo_stamp.dart';
import '../../utils/format.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_theme.dart';
import '../widgets/field_label.dart';
import '../../src/location/geocoding_service.dart';
import '../providers/add_activity_provider.dart';

class AddActivityScreen extends ConsumerStatefulWidget {
  final String pipelineId;

  const AddActivityScreen({super.key, required this.pipelineId});

  @override
  ConsumerState<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends ConsumerState<AddActivityScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form/interaktif (tetap di widget): toggle, GPS/foto picker, date/time picker,
  // input teks, dan flag validasi follow-up — semua diedit/dipicu langsung user.
  // CR-11 (MTR-8): jenis kunjungan default = Lapangan. Kunjungan lapangan adalah
  // aktivitas yang paling sering dicatat RM, jadi nilai awalnya dibuat menyala dan
  // pengguna mematikannya hanya saat mencatat Call. Konsekuensi yang disengaja:
  // bagian GPS & foto langsung tampil dan ikut divalidasi — keduanya memang syarat
  // kunjungan lapangan. Tidak ada GPS yang diambil otomatis saat layar dibuka;
  // pengambilan lokasi tetap menunggu ketukan pengguna.
  bool _isVisit = true;
  double? _gpsLat;
  double? _gpsLng;
  String _gpsLabel = '';
  bool _locatingGps = false;
  /// Foto MENTAH dari kamera. Disimpan terpisah dari [_photoBytes] yang sudah
  /// dicap, supaya pencapan ulang (mis. RM menyegarkan lokasi setelah memotret)
  /// selalu berangkat dari gambar bersih — bukan menumpuk cap di atas cap.
  Uint8List? _photoRaw;
  Uint8List? _photoBytes;

  /// Penanda kombinasi (foto, lokasi) yang salinannya sudah masuk galeri, supaya
  /// satu foto tidak tersimpan berkali-kali. Berubah hanya bila fotonya diganti
  /// atau titik lokasinya benar-benar bergeser.
  String? _archivedSignature;

  /// Pencapan sedang berjalan. Menjaga panggilan yang datang selama proses itu
  /// tidak ikut masuk — lihat [_stampAndArchivePhoto].
  bool _archiving = false;
  String? _photoName;
  String _deskripsi = '';
  String _rencanaTindakLanjut = '';
  DateTime? _tanggalFollowUp;
  TimeOfDay? _jamFollowUp;
  bool _showFollowUpError = false;

  // State async simpan dipindah ke AddActivityNotifier. Getter berikut memproksi
  // agar kode build tetap memakai nama lama tanpa perubahan.
  AddActivityNotifier get _notifier => ref.read(addActivityProvider.notifier);
  bool get _saving => ref.read(addActivityProvider).saving;
  String? get _error => ref.read(addActivityProvider).error;

  bool get _hasGps => _gpsLat != null && _gpsLng != null;
  bool get _hasPhoto => _photoBytes != null;

  final TextEditingController _descController = TextEditingController();
  final TextEditingController _rencanaController = TextEditingController();

  @override
  void dispose() {
    _descController.dispose();
    _rencanaController.dispose();
    super.dispose();
  }

  /// Captures the device's CURRENT GPS position — the RM cannot pick a point on
  /// a map. This is deliberate: a visit must be logged from where the RM
  /// physically is, so the coordinates can't be faked from the office.
  Future<void> _captureCurrentLocation() async {
    setState(() => _locatingGps = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationError(
          'Layanan lokasi (GPS) tidak aktif. Aktifkan dulu di pengaturan perangkat.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showLocationError(
          'Izin lokasi ditolak. Beri izin lokasi untuk mencatat kunjungan.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Anti-fraud: reject spoofed/mock GPS (fake-GPS apps).
      if (position.isMocked) {
        _showLocationError(
          'Terdeteksi lokasi palsu (mock GPS). Matikan aplikasi fake GPS lalu coba lagi.',
        );
        return;
      }

      final lat = position.latitude;
      final lng = position.longitude;
      final coordLabel = '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
      if (!mounted) return;
      setState(() {
        _gpsLat = lat;
        _gpsLng = lng;
        _gpsLabel = coordLabel;
      });

      // Best-effort friendly address; keeps coordinates if it fails.
      final address = await GeocodingService.reverseGeocode(lat, lng);
      if (!mounted) return;
      if (address != null && address.isNotEmpty) {
        setState(() => _gpsLabel = '$address\n$coordLabel');
      }
      // Sesudah alamat selesai dicari, bukan sebelumnya: capnya memuat alamat itu.
      await _stampAndArchivePhoto();
    } catch (e) {
      _showLocationError('Gagal mengambil lokasi: $e');
    } finally {
      if (mounted) setState(() => _locatingGps = false);
    }
  }

  /// Tanam cap ke foto lalu simpan salinannya ke galeri — dijalankan begitu FOTO
  /// dan LOKASI sama-sama ada, mana pun yang belakangan.
  ///
  /// Sengaja bukan saat tombol simpan ditekan: RM mengharapkan foto sudah ada di
  /// galeri segera setelah memotret, dan menunda sampai pengiriman berarti foto
  /// hilang bila formulirnya ditinggalkan atau aplikasi tertutup.
  ///
  /// Sengaja juga bukan tepat saat rana ditekan: capnya memuat lokasi, sedangkan
  /// RM boleh memotret lebih dulu baru mengambil GPS. Menunggu keduanya siap
  /// adalah satu-satunya titik yang memenuhi dua tuntutan itu sekaligus.
  Future<void> _stampAndArchivePhoto() async {
    final raw = _photoRaw;
    if (raw == null || !_hasGps) return;

    // Penanda sengaja hanya memuat FOTO, bukan foto+koordinat. Koordinat GPS
    // bergoyang beberapa meter tiap kali diambil, jadi penanda yang ikut memuatnya
    // akan berubah pada setiap pengambilan ulang dan galeri terisi salinan baru
    // terus-menerus — terbukti di perangkat: satu kunjungan meninggalkan SEMBILAN
    // berkas. Satu kunjungan = satu salinan galeri.
    final signature = '${raw.length}';
    final sudahDiarsipkan = _archivedSignature == signature;

    // Palang masuk dipasang SEBELUM await pertama: penanda baru terisi setelah
    // pencapan selesai (ratusan milidetik untuk foto belasan megapiksel), sehingga
    // panggilan yang datang selama jeda itu akan lolos penjaga di atas.
    if (_archiving) return;
    _archiving = true;
    try {
      final now = DateTime.now();
      final stamped = await VisitPhotoStamp.apply(
        bytes: raw,
        takenAt: now,
        timeZoneLabel: AppFormat.timeZoneLabel(now),
        locationLabel: _gpsLabel,
        latitude: _gpsLat,
        longitude: _gpsLng,
      );
      if (!mounted) return;
      // Pencapan SELALU diperbarui walau salinan galerinya sudah ada, supaya foto
      // yang terunggah memuat lokasi terakhir — itu yang jadi bukti kunjungan.
      setState(() {
        _photoBytes = stamped;
        _archivedSignature = signature;
      });
      if (sudahDiarsipkan) return; // galeri cukup satu salinan per foto

      // Best-effort: galeri adalah SALINAN kenyamanan. Kegagalannya hanya
      // diberitahukan, tidak boleh menghalangi pencatatan kunjungan.
      final saved = await VisitGallery.save(
        stamped,
        name: 'kunjungan-${now.millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      final warning = VisitGallery.messageFor(saved);
      if (warning != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(warning),
            backgroundColor: AppColors.secondaryOrange,
          ),
        );
      }
    } finally {
      _archiving = false;
    }
  }

  void _showLocationError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.errorRed),
    );
  }

  Future<void> _takePhoto() async {
    // Capture straight from the camera (falls back to a file picker on web).
    final picker = ImagePicker();
    final XFile? shot = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (shot == null) return;
    final bytes = await shot.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photoRaw = bytes;
      _photoBytes = bytes;
      _photoName = shot.name;
      _archivedSignature = null; // foto baru → cap & arsip harus diulang
    });
    await _stampAndArchivePhoto();
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }

  void _showDatePicker() {
    showDatePicker(
      context: context,
      initialDate: _tanggalFollowUp ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryNavy,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    ).then((selectedDate) {
      if (selectedDate != null) {
        setState(() {
          _tanggalFollowUp = selectedDate;
        });
      }
    });
  }

  /// True when exactly one of tanggal/jam is filled — the follow-up needs both or
  /// neither.
  bool get _followUpIncomplete =>
      (_tanggalFollowUp == null) != (_jamFollowUp == null);

  /// The follow-up now becomes a real schedule, and the reminders (H-24j/H-2j/
  /// H-1j/H-15m) count off its time — so a date alone isn't enough. Mirrors the
  /// "Jadwalkan Visit" sheet, which requires both.
  void _showTimePicker() {
    showTimePicker(
      context: context,
      initialTime: _jamFollowUp ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryNavy,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    ).then((selectedTime) {
      if (selectedTime != null) {
        setState(() {
          _jamFollowUp = selectedTime;
        });
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isVisit && (!_hasGps || !_hasPhoto)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kunjungan lapangan wajib melampirkan Lokasi GPS dan Foto Kunjungan',
          ),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    // All-or-nothing: a date without a time can't become a schedule the reminders
    // can count off, and a time without a date would just be dropped silently.
    if (_followUpIncomplete) {
      setState(() => _showFollowUpError = true);
      return;
    }

    // Naive local wall-clock, no offset — the backend parses this as a
    // LocalDateTime and reads it as Asia/Jakarta. Deliberately NOT .toUtc(), which
    // is what the schedule endpoint wants; the two date paths differ.
    String? followupIso;
    if (_tanggalFollowUp != null && _jamFollowUp != null) {
      followupIso = DateTime(
        _tanggalFollowUp!.year,
        _tanggalFollowUp!.month,
        _tanggalFollowUp!.day,
        _jamFollowUp!.hour,
        _jamFollowUp!.minute,
      ).toIso8601String();
    }

    // CR-12 (MTR-7): pencapan & penyimpanan ke galeri sudah terjadi lebih awal —
    // begitu foto dan lokasi sama-sama ada. Panggilan di sini semata JARING
    // PENGAMAN untuk urutan tak lazim (mis. pencapan sempat gagal): ia idempoten,
    // jadi foto yang sudah tercap tidak dicap dua kali dan salinan galerinya tidak
    // bertambah. Tanpa jaring ini, satu kegagalan diam-diam berarti foto bukti
    // terunggah TANPA cap.
    await _stampAndArchivePhoto();
    if (!mounted) return;
    final Uint8List? photoBytes = _photoBytes;

    // Simpan (flag `saving` + panggilan repo) dipindah ke notifier; validasi,
    // snackbar, dan navigasi tetap di sini.
    final ok = await _notifier.submit(
      pipelineId: widget.pipelineId,
      type: _isVisit ? 'VISIT' : 'CALL',
      notes: _deskripsi,
      nextFollowupDate: followupIso,
      actionPlan: _rencanaTindakLanjut.trim().isEmpty
          ? null
          : _rencanaTindakLanjut.trim(),
      gpsLatitude: _gpsLat?.toString(),
      gpsLongitude: _gpsLng?.toString(),
      photoBytes: photoBytes,
      photoName: _photoName,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aktivitas berhasil disimpan!'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan aktivitas: $_error'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state simpan → rebuild otomatis saat `saving` berubah
    // (mengganti setState lama untuk flag simpan).
    ref.watch(addActivityProvider);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Tambah Aktivitas',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.border, height: 1.0),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Kunjungan Lapangan Toggle Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: AppRadius.radiusLg,
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [AppShadows.level1],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kunjungan Lapangan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Aktifkan jika kunjungan fisik ke nasabah',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isVisit,
                      onChanged: (val) {
                        setState(() {
                          _isVisit = val;
                          if (!_isVisit) {
                            _gpsLat = null;
                            _gpsLng = null;
                            _gpsLabel = '';
                            _photoRaw = null;
                            _photoBytes = null;
                            _photoName = null;
                            _archivedSignature = null;
                          }
                        });
                      },
                      activeThumbColor: AppColors.primaryNavy,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Visit Specific Fields (GPS & Photo)
              if (_isVisit) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: AppRadius.radiusLg,
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [AppShadows.level1],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DATA KUNJUNGAN',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // GPS Location Detector
                      const Text(
                        'Lokasi GPS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildGpsDetectorWidget(),
                      const SizedBox(height: 14),

                      // Photo field
                      const Text(
                        'Foto Kunjungan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildPhotoWidget(),
                      const SizedBox(height: 6),
                      const Text(
                        '* Foto langsung dari kamera (bukan galeri). Wajib untuk validasi visit.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Common Fields (Description, Follow up date, Plans)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: AppRadius.radiusLg,
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [AppShadows.level1],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextareaField(
                      label: 'Deskripsi Aktivitas *',
                      hint:
                          'Tuliskan hasil diskusi, temuan, atau catatan penting...',
                      controller: _descController,
                      maxLength: _deskripsiMaxChars,
                      validator: (val) => val == null || val.isEmpty
                          ? 'Deskripsi wajib diisi'
                          : null,
                      onChanged: (val) => setState(() => _deskripsi = val),
                    ),
                    const SizedBox(height: 14),
                    _buildTextareaField(
                      label: 'Rencana Tindak Lanjut',
                      hint: 'Apa yang akan dilakukan selanjutnya?',
                      controller: _rencanaController,
                      maxLength: _rencanaMaxChars,
                      maxLines: 2,
                      onChanged: (val) =>
                          setState(() => _rencanaTindakLanjut = val),
                    ),
                    const SizedBox(height: 14),
                    // Tanggal + jam follow-up. Filling these creates an OPEN jadwal
                    // for the pipeline's RM, so both are needed together.
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tanggal Follow-up',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _followUpBox(
                                icon: Icons.calendar_today_outlined,
                                onTap: _showDatePicker,
                                filled: _tanggalFollowUp != null,
                                label: _tanggalFollowUp == null
                                    ? 'Pilih tanggal'
                                    : '${_tanggalFollowUp!.day} ${_getMonthName(_tanggalFollowUp!.month)} ${_tanggalFollowUp!.year}',
                                error:
                                    _showFollowUpError &&
                                    _tanggalFollowUp == null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: _followUpBox(
                                icon: Icons.access_time,
                                onTap: _showTimePicker,
                                filled: _jamFollowUp != null,
                                label: _jamFollowUp == null
                                    ? 'Pilih jam'
                                    : _jamFollowUp!.format(context),
                                error:
                                    _showFollowUpError && _jamFollowUp == null,
                              ),
                            ),
                          ],
                        ),
                        if (_showFollowUpError && _followUpIncomplete) ...[
                          const SizedBox(height: 6),
                          Text(
                            _jamFollowUp == null
                                ? 'Jam wajib diisi — jadwal & pengingat memakainya.'
                                : 'Tanggal wajib diisi kalau jam sudah dipilih.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.errorRed,
                            ),
                          ),
                        ] else if (_tanggalFollowUp != null &&
                            _jamFollowUp != null) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'Akan otomatis masuk Jadwal, lengkap dengan pengingat.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Visit info banner
              if (_isVisit) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.navyBg,
                    borderRadius: AppRadius.radiusMd,
                    border: Border.all(
                      color: AppColors.primaryNavy.withValues(alpha: 0.15),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Info Validasi Visit',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryNavy,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Lokasi diambil otomatis dari GPS perangkat saat ini (tidak bisa memilih titik di peta) untuk memastikan kunjungan benar-benar dilakukan di lokasi. Visit dihitung valid jika Foto dan GPS keduanya terisi, dan akan dihitung sebagai 1 Visit di laporan kinerja.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Simpan Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.radiusLg,
                    ),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Simpan Aktivitas',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Deskripsi becomes visits.notes (TEXT; backend rejects >5000).
  static const int _deskripsiMaxChars = 2000;

  /// Rencana Tindak Lanjut becomes schedules.action_plan, which is varchar(255).
  /// Capped here so the RM sees a counter rather than a 400 on save.
  static const int _rencanaMaxChars = 255;

  /// One of the two follow-up pickers (tanggal / jam), styled as a tappable box.
  Widget _followUpBox({
    required IconData icon,
    required VoidCallback onTap,
    required bool filled,
    required String label,
    bool error = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.bgScreen,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(
            color: error ? AppColors.errorRed : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: error ? AppColors.errorRed : AppColors.grayStage,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: filled ? AppColors.textPrimary : AppColors.grayStage,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextareaField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required int maxLength,
    int maxLines = 3,
    String? Function(String?)? validator,
    required void Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        fieldLabel(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgScreen,
            borderRadius: AppRadius.radiusMd,
            border: Border.all(color: AppColors.border),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            maxLength: maxLength,
            validator: validator,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: AppColors.grayStage,
                fontSize: 13,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGpsDetectorWidget() {
    if (!_hasGps) {
      return GestureDetector(
        onTap: _locatingGps ? null : _captureCurrentLocation,
        child: CustomPaint(
          painter: DashedRectPainter(
            color: AppColors.primaryNavy,
            strokeWidth: 1.5,
            gap: 4.0,
          ),
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.navyBg,
              borderRadius: AppRadius.radiusMd,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_locatingGps) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Mengambil lokasi...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ] else ...[
                  const Icon(
                    Icons.my_location,
                    color: AppColors.primaryNavy,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Ambil Lokasi Saat Ini',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: _locatingGps
          ? null
          : _captureCurrentLocation, // tap to re-capture current position
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.greenLight,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(
            color: AppColors.successGreen.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle,
              color: AppColors.successGreen,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lokasi saat ini terekam',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.successGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _gpsLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            _locatingGps
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.successGreen,
                    ),
                  )
                : const Icon(
                    Icons.refresh,
                    color: AppColors.successGreen,
                    size: 18,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoWidget() {
    if (!_hasPhoto) {
      return GestureDetector(
        onTap: _takePhoto,
        child: CustomPaint(
          painter: DashedRectPainter(
            color: AppColors.grayStage,
            strokeWidth: 1.5,
            gap: 4.0,
          ),
          child: Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.bgScreen,
              borderRadius: AppRadius.radiusMd,
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  size: 28,
                  color: AppColors.grayStage,
                ),
                SizedBox(height: 8),
                Text(
                  'Ambil Foto',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: _takePhoto, // tap to retake
      child: ClipRRect(
        borderRadius: AppRadius.radiusMd,
        child: Stack(
          children: [
            Image.memory(
              _photoBytes!,
              width: double.infinity,
              height: 160,
              fit: BoxFit.cover,
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Ambil ulang',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
