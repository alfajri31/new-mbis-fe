import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../utils/input_formatters.dart';
import '../widgets/field_label.dart';
import '../../src/app.dart';
import '../../src/network/api_client.dart';
import '../../src/agent/agent_repository.dart';
import '../../src/region/region_repository.dart';
import '../../src/common/file_opener.dart';
import '../../core/providers/repository_providers.dart';
import '../providers/ajukan_agen_provider.dart';
import '../widgets/back_app_bar.dart';
import '../widgets/missing_fields_notice.dart';
import '../widgets/region_address_fields.dart';

/// RM submits a new Agen/TPM candidate (POST /api/agents). This creates the
/// agent as DRAFT — the first step of the approval chain (RM → Pimpinan Cabang
/// → Network Management → PKS → CIF). The candidate's office is taken from the
/// submitting RM; onboarding documents (Pakta Integritas / PKS) are uploaded in
/// a later admin phase, not here.
class AjukanAgenScreen extends ConsumerStatefulWidget {
  /// When set, the screen edits this DRAFT/REJECTED agent (PUT) instead of
  /// creating a new one. Reached from the agent detail screen's "Edit" action.
  final AgentModel? existing;
  const AjukanAgenScreen({super.key, this.existing});

  @override
  ConsumerState<AjukanAgenScreen> createState() => _AjukanAgenScreenState();
}

class _AjukanAgenScreenState extends ConsumerState<AjukanAgenScreen> {
  final _formKey = GlobalKey<FormState>();

  /// Menyala setelah percobaan kirim pertama yang gagal, supaya tanda merah
  /// ikut hilang begitu user memperbaiki isiannya.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  String _jenis = 'agen'; // 'agen' | 'tpm'
  String _bank = ''; // nama bank terpilih (untuk pencairan komisi)

  // Phase-1 document uploads. Picked files keyed by doc code; existing codes
  // (edit mode) are already stored on the server.
  final Map<String, PlatformFile?> _docFiles = {};
  bool _domicileDiffers = false; // reveals + requires SK Domisili
  bool _wasAgentElsewhere = false; // reveals + requires Surat Pengunduran Diri

  // Langkah wizard aktif: 0 Data · 1 Alamat · 2 Dokumen · 3 Kirim. Semua field
  // tetap hidup di dalam Form (IndexedStack), jadi validasi & submit tak berubah.
  int _step = 0;
  static const _stepLabels = ['Data', 'Alamat', 'Dokumen', 'Kirim'];

  /// Repo wilayah untuk dropdown alamat (provinsi→kelurahan).
  RegionRepository get _regionRepo => ref.read(regionRepoProvider);

  // State async (template dokumen, config field/checklist, opsi gender, kode
  // dokumen eksisting, flag simpan) dikelola AjukanAgenNotifier. Field lama
  // diproksikan lewat getter agar kode build/form memakai nama yang sama tanpa
  // diubah. Input form (controller, jenis/bank/gender terpilih, tanggal lahir,
  // toggle domisili/ex-agen, map upload) TETAP di sini.
  AjukanAgenState get _aas => ref.read(ajukanAgenProvider);
  AjukanAgenNotifier get _notifier => ref.read(ajukanAgenProvider.notifier);

  Map<String, AgentTemplateItem> get _templates => _aas.templates; // code → template (for download buttons)
  List<AjukanDocDef>? get _configDocs => _aas.configDocs; // registration doc checklist from admin config (null = fallback)
  Set<String> get _existingDocCodes => _aas.existingDocCodes;
  bool get _busy => _aas.busy;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Reset baseline + muat template & config (async) via notifier. Sesi
      // dibaca notifier dari apiClientProvider — tak perlu context.
      _notifier.start();
    });
    final e = widget.existing;
    if (e == null) return;
    _jenis = e.type == 'TPM' ? 'tpm' : 'agen';
    _bank = e.bankName;
    _gender = e.gender;
    _birthDate = e.birthDate.isEmpty ? null : DateTime.tryParse(e.birthDate);
    _nameController.text = e.name;
    _npwpController.text = maskNpwp(e.npwp);
    _emailController.text = e.email;
    _phoneController.text = e.phone;
    _ktpNumberController.text = e.ktpNumber;
    _accountNumberController.text = e.accountNumber;
    _ktpAddressController.text = e.ktpAddress;
    _ktpProvinceController.text = e.ktpProvince;
    _ktpCityController.text = e.ktpCity;
    _ktpDistrictController.text = e.ktpDistrict;
    _ktpSubdistrictController.text = e.ktpSubdistrict;
    _ktpRtController.text = e.ktpRt;
    _ktpRwController.text = e.ktpRw;
    _ktpPostalController.text = e.ktpPostalCode;
    _domAddressController.text = e.domicileAddress;
    _domProvinceController.text = e.domicileProvince;
    _domCityController.text = e.domicileCity;
    _domDistrictController.text = e.domicileDistrict;
    _domSubdistrictController.text = e.domicileSubdistrict;
    _domRtController.text = e.domicileRt;
    _domRwController.text = e.domicileRw;
    _domPostalController.text = e.domicilePostalCode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadExistingDocs(e.id);
    });
  }

  /// Muat kode dokumen eksisting (mode edit) via notifier, lalu nyalakan toggle
  /// domisili/ex-agen (input form yang tetap di widget) berdasar kode yang ada.
  Future<void> _loadExistingDocs(String agentId) async {
    final codes = await _notifier.loadExistingDocs(agentId);
    if (!mounted) return;
    setState(() {
      _domicileDiffers = _domicileDiffers || codes.contains('SK_DOMISILI');
      _wasAgentElsewhere = _wasAgentElsewhere || codes.contains('SURAT_PENGUNDURAN_DIRI');
    });
  }

  // Semua field pengajuan dipaksa wajib (permintaan user), mengabaikan konfig
  // admin per-field. Bila kelak ingin mengembalikan konfig, kembalikan ke
  // `_fieldRequired[code] ?? fallback`.
  bool _req(String code, bool fallback) => true;

  // ── Anchor per-field untuk auto-scroll ke isian wajib pertama yang kosong ──
  final Map<String, GlobalKey> _anchors = {};
  GlobalKey _anchorKey(String code) => _anchors.putIfAbsent(code, () => GlobalKey());

  /// Urutan field wajib per langkah (untuk cari yang kosong pertama + scroll).
  List<String> _stepFieldCodes(int step) {
    switch (step) {
      case 0:
        return const ['NAME', 'KTP_NUMBER', 'GENDER', 'BIRTHDATE', 'EMAIL',
            'PHONE', 'NPWP', 'BANK_NAME', 'ACCOUNT_NUMBER'];
      case 1:
        return const ['KTP_ADDRESS', 'KTP_REGION', 'KTP_RT', 'KTP_RW',
            'DOMICILE_ADDRESS', 'DOMICILE_REGION', 'DOMICILE_RT', 'DOMICILE_RW'];
      case 2:
        return const ['DOCS'];
      default:
        return const [];
    }
  }

  bool _codeEmpty(String code) {
    switch (code) {
      case 'NAME':
        return _nameController.text.trim().isEmpty;
      case 'KTP_NUMBER':
        return _ktpNumberController.text.trim().isEmpty;
      case 'GENDER':
        return _gender.trim().isEmpty;
      case 'BIRTHDATE':
        return _birthDate == null;
      case 'EMAIL':
        return _emailController.text.trim().isEmpty;
      case 'PHONE':
        return _phoneController.text.trim().isEmpty;
      case 'NPWP':
        return _npwpController.text.trim().isEmpty;
      case 'BANK_NAME':
        return _bank.trim().isEmpty;
      case 'ACCOUNT_NUMBER':
        return _accountNumberController.text.trim().isEmpty;
      case 'KTP_ADDRESS':
        return _ktpAddressController.text.trim().isEmpty;
      case 'KTP_REGION':
        return [_ktpProvinceController, _ktpCityController, _ktpDistrictController,
                _ktpSubdistrictController, _ktpPostalController]
            .any((c) => c.text.trim().isEmpty);
      case 'KTP_RT':
        return _ktpRtController.text.trim().isEmpty;
      case 'KTP_RW':
        return _ktpRwController.text.trim().isEmpty;
      case 'DOMICILE_ADDRESS':
        return _domAddressController.text.trim().isEmpty;
      case 'DOMICILE_REGION':
        return [_domProvinceController, _domCityController, _domDistrictController,
                _domSubdistrictController, _domPostalController]
            .any((c) => c.text.trim().isEmpty);
      case 'DOMICILE_RT':
        return _domRtController.text.trim().isEmpty;
      case 'DOMICILE_RW':
        return _domRwController.text.trim().isEmpty;
      case 'DOCS':
        return _missingRequiredDocs().isNotEmpty;
      default:
        return false;
    }
  }

  /// Kode field wajib pertama yang kosong pada [step], atau null bila lengkap.
  String? _firstEmptyCode(int step) {
    for (final code in _stepFieldCodes(step)) {
      if (_codeEmpty(code)) return code;
    }
    return null;
  }

  /// Nama isian yang ramah untuk ditampilkan di toast per kode field.
  static const Map<String, String> _codeLabels = {
    'NAME': 'Nama Lengkap',
    'KTP_NUMBER': 'No. KTP',
    'GENDER': 'Jenis Kelamin',
    'BIRTHDATE': 'Tanggal Lahir',
    'EMAIL': 'Email',
    'PHONE': 'No. Telepon',
    'NPWP': 'NPWP',
    'BANK_NAME': 'Nama Bank',
    'ACCOUNT_NUMBER': 'No. Rekening',
    'KTP_ADDRESS': 'Alamat KTP',
    'KTP_REGION': 'Wilayah KTP (Provinsi/Kota/Kecamatan/Kelurahan/Kode Pos)',
    'KTP_RT': 'RT (KTP)',
    'KTP_RW': 'RW (KTP)',
    'DOMICILE_ADDRESS': 'Alamat Domisili',
    'DOMICILE_REGION': 'Wilayah Domisili (Provinsi/Kota/Kecamatan/Kelurahan/Kode Pos)',
    'DOMICILE_RT': 'RT (Domisili)',
    'DOMICILE_RW': 'RW (Domisili)',
  };

  /// Daftar nama isian wajib yang belum lengkap pada [step] — untuk toast
  /// informatif. Untuk langkah Dokumen, sebut nama dokumen yang kurang.
  List<String> _missingLabelsForStep(int step) {
    final out = <String>[];
    for (final code in _stepFieldCodes(step)) {
      if (!_codeEmpty(code)) continue;
      if (code == 'DOCS') {
        out.addAll(_missingRequiredDocs());
      } else {
        out.add(_codeLabels[code] ?? code);
      }
    }
    return out;
  }

  void _scrollToAnchor(String code) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _anchors[code]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 350),
            alignment: 0.1,
            curve: Curves.easeInOut);
      }
    });
  }

  /// Error FORMAT (bukan sekadar kosong) pada langkah [step]. Hanya langkah Data
  /// yang punya aturan format tambahan (email). Dipisah dari validasi Form penuh
  /// supaya "Lanjut" TIDAK terhalang isian kosong di LANGKAH LAIN.
  String? _stepFormatError(int step) {
    if (step == 0) {
      final email = _emailController.text.trim();
      if (email.isNotEmpty && !email.contains('@')) return 'Email tidak valid';
    }
    return null;
  }

  /// "Lanjut": validasi HANYA langkah aktif. Bila ada yang kosong/format salah →
  /// tampilkan error merah, toast informatif, dan scroll ke isian salah pertama.
  void _onNext() {
    final firstEmpty = _firstEmptyCode(_step);
    final formatErr = _stepFormatError(_step);
    if (firstEmpty == null && formatErr == null) {
      setState(() => _step += 1);
      return;
    }
    // Nyalakan error inline (merah). validate() penuh hanya untuk MENAMPILKAN
    // error; keputusan lanjut/tidak murni dari langkah aktif di atas.
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    _formKey.currentState?.validate();
    final labels = [
      ..._missingLabelsForStep(_step),
      ?formatErr,
    ];
    showMissingFieldsNotice(
      ScaffoldMessenger.of(context),
      labels.isEmpty ? const ['Ada isian yang belum valid'] : labels,
    );
    _scrollToAnchor(firstEmpty ?? 'EMAIL');
  }

  Future<void> _downloadTemplate(String code) async {
    final pending = openPendingTab();
    final repo = AgentRepository(apiClient: ApiClient(session: MbisApp.of(context)?.session));
    try {
      final f = await repo.downloadTemplate(code);
      final ok = await openBytes(f.bytes, f.contentType, f.fileName, pending: pending);
      if (!ok) {
        closePendingTab(pending);
        if (mounted) _snack('Unduhan template didukung di web. Untuk aplikasi mobile menyusul.', error: true);
      }
    } catch (e) {
      closePendingTab(pending);
      if (mounted) _snack(e.toString().replaceAll('Exception: ', ''), error: true);
    }
  }

  String _gender = ''; // 'Laki-laki' | 'Perempuan'
  // Opsi jenis kelamin: param GENDER (admin-editable); fallback bila belum
  // termuat. Dimuat notifier → diproksikan lewat getter.
  List<String> get _genderOptions => _aas.genderOptions;
  DateTime? _birthDate;

  final _nameController = TextEditingController();
  final _npwpController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ktpNumberController = TextEditingController();
  final _accountNumberController = TextEditingController();
  // Alamat KTP
  final _ktpAddressController = TextEditingController();
  final _ktpProvinceController = TextEditingController();
  final _ktpCityController = TextEditingController();
  final _ktpDistrictController = TextEditingController();
  final _ktpSubdistrictController = TextEditingController();
  final _ktpRtController = TextEditingController();
  final _ktpRwController = TextEditingController();
  final _ktpPostalController = TextEditingController();
  // Alamat Domisili
  final _domAddressController = TextEditingController();
  final _domProvinceController = TextEditingController();
  final _domCityController = TextEditingController();
  final _domDistrictController = TextEditingController();
  final _domSubdistrictController = TextEditingController();
  final _domRtController = TextEditingController();
  final _domRwController = TextEditingController();
  final _domPostalController = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _nameController, _npwpController, _emailController, _phoneController,
      _ktpNumberController, _accountNumberController,
      _ktpAddressController, _ktpProvinceController, _ktpCityController,
      _ktpDistrictController, _ktpSubdistrictController, _ktpRtController, _ktpRwController,
      _ktpPostalController,
      _domAddressController, _domProvinceController, _domCityController,
      _domDistrictController, _domSubdistrictController, _domRtController, _domRwController,
      _domPostalController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _isoDate(DateTime? d) =>
      d == null ? null : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String? _orNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  /// NPWP: kirim angka murni (tanpa titik/strip) — mask hanya untuk tampilan.
  String? _digitsOrNull(TextEditingController c) {
    final digits = c.text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : digits;
  }

  /// Phase-1 document requirements, in display order. Conditional docs only
  /// appear (and are only required) when their toggle is on.
  List<AjukanDocDef> get _phase1Docs => const [
        AjukanDocDef('KTP', 'Fotokopi KTP', required: true),
        AjukanDocDef('NPWP', 'Fotokopi NPWP', required: true),
        AjukanDocDef('PIPELINE', 'Dokumen Pipeline', required: true),
        AjukanDocDef('SURAT_PERNYATAAN', 'Surat Pernyataan Bermeterai', required: true),
        AjukanDocDef('PENGALAMAN_KERJA', 'Pengalaman Kerja', required: true),
        AjukanDocDef('MEMO_1', 'Memo Pengajuan', required: true),
        AjukanDocDef('AAUI', 'Copy AAUI (opsional)'),
        AjukanDocDef('SK_DOMISILI', 'SK Domisili', required: true, condition: 'domicile'),
        AjukanDocDef('SURAT_PENGUNDURAN_DIRI', 'Surat Pengunduran Diri', required: true, condition: 'exAgent'),
      ];

  /// Active checklist: admin config when loaded, else the built-in fallback.
  List<AjukanDocDef> get _docs => _configDocs ?? _phase1Docs;

  bool _isDocActive(AjukanDocDef d) {
    if (d.condition == 'domicile') return _domicileDiffers;
    if (d.condition == 'exAgent') return _wasAgentElsewhere;
    return true;
  }

  List<String> _missingRequiredDocs() {
    final missing = <String>[];
    for (final d in _docs) {
      if (!_isDocActive(d) || !d.required) continue;
      final has = (_docFiles[d.code]?.bytes != null) || _existingDocCodes.contains(d.code);
      if (!has) missing.add(d.label);
    }
    return missing;
  }

  /// Isian teks wajib pada form, URUT sesuai tampilan. Aturan wajibnya dibaca
  /// dari [_req] — sumber yang SAMA dengan `validator` tiap field — supaya
  /// daftar ini tak pernah berbeda dengan tanda merah di layar.
  ///
  /// Dipakai untuk pop-up bawah: dulu `_save` hanya `return` diam-diam saat
  /// `Form.validate()` gagal, jadi menekan "Kirim Pengajuan" terasa seperti
  /// tombol mati padahal ada field kosong di bagian layar yang tidak terlihat.
  List<String> _missingRequiredFields() {
    final entries = <(String label, String code, bool fallback, TextEditingController c)>[
      ('Nama Lengkap', 'NAME', true, _nameController),
      ('No. KTP', 'KTP_NUMBER', false, _ktpNumberController),
      ('Email', 'EMAIL', true, _emailController),
      ('No. Telepon', 'PHONE', true, _phoneController),
      ('NPWP', 'NPWP', false, _npwpController),
      ('No. Rekening', 'ACCOUNT_NUMBER', false, _accountNumberController),
      ('Alamat KTP', 'KTP_ADDRESS', false, _ktpAddressController),
      ('Provinsi (KTP)', 'KTP_PROVINCE', false, _ktpProvinceController),
      ('Kota/Kabupaten (KTP)', 'KTP_CITY', false, _ktpCityController),
      ('Kecamatan (KTP)', 'KTP_DISTRICT', false, _ktpDistrictController),
      ('Kelurahan/Desa (KTP)', 'KTP_SUBDISTRICT', false, _ktpSubdistrictController),
      ('RT (KTP)', 'KTP_RT', false, _ktpRtController),
      ('RW (KTP)', 'KTP_RW', false, _ktpRwController),
      ('Alamat Domisili', 'DOMICILE_ADDRESS', false, _domAddressController),
      ('Provinsi (Domisili)', 'DOMICILE_PROVINCE', false, _domProvinceController),
      ('Kota/Kabupaten (Domisili)', 'DOMICILE_CITY', false, _domCityController),
      ('Kecamatan (Domisili)', 'DOMICILE_DISTRICT', false, _domDistrictController),
      ('Kelurahan/Desa (Domisili)', 'DOMICILE_SUBDISTRICT', false, _domSubdistrictController),
      ('RT (Domisili)', 'DOMICILE_RT', false, _domRtController),
      ('RW (Domisili)', 'DOMICILE_RW', false, _domRwController),
    ];

    final missing = <String>[];
    for (final (label, code, fallback, controller) in entries) {
      if (!_req(code, fallback)) continue;
      if (controller.text.trim().isEmpty) missing.add(label);
    }
    // Field non-teks yang juga wajib.
    if (_req('GENDER', true) && _gender.trim().isEmpty) missing.add('Jenis Kelamin');
    if (_req('BIRTHDATE', true) && _birthDate == null) missing.add('Tanggal Lahir');
    // Email punya aturan tambahan (format) di validator-nya.
    final email = _emailController.text.trim();
    if (email.isNotEmpty && !email.contains('@')) missing.add('Email tidak valid');
    if (_req('BANK_NAME', false) && _bank.trim().isEmpty) missing.add('Nama Bank');
    return missing;
  }

  Future<void> _pickDoc(String code) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
    if (!mounted) return;
    setState(() => _docFiles[code] = res.files.first);
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? AppColors.errorRed : AppColors.successGreen,
    ));
  }

  /// Saves the candidate. When [submit] is true it uploads the picked documents
  /// and forwards the pengajuan for approval; otherwise it just stores a draft.
  ///
  /// Validasi + nilai form (controller/pilihan) tetap di widget; penyimpanan
  /// async (create/update + unggah dokumen + submit) & flag `busy` dikelola
  /// [AjukanAgenNotifier.save]. Navigasi & snackbar tetap di sini.
  Future<void> _save({required bool submit}) async {
    final messengerForNotice = ScaffoldMessenger.of(context);
    if (submit) {
      // Field + dokumen dikumpulkan jadi SATU daftar, lalu ditampilkan sebagai
      // pop-up bawah yang menyebut namanya. Sebelumnya `validate()` yang gagal
      // hanya `return` tanpa pesan apa pun.
      final missing = [..._missingRequiredFields(), ..._missingRequiredDocs()];
      if (missing.isNotEmpty) {
        setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
        // Lompat ke langkah pertama yang punya isian salah, lalu scroll ke sana.
        for (int s = 0; s < _stepLabels.length; s++) {
          final code = _firstEmptyCode(s);
          if (code != null) {
            setState(() => _step = s);
            _formKey.currentState?.validate();
            _scrollToAnchor(code);
            break;
          }
        }
        _formKey.currentState?.validate();
        showMissingFieldsNotice(messengerForNotice, missing);
        return;
      }
      if (!(_formKey.currentState?.validate() ?? false)) {
        setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
        _snack('Ada isian yang belum valid.', error: true);
        return;
      }
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      // Draft pun butuh nama supaya barisnya bisa dikenali di Manajemen Agen.
      showMissingFieldsNotice(messengerForNotice, const ['Nama Lengkap']);
      return;
    }
    if (_busy) return;

    final label = _jenis == 'agen' ? 'Agen' : 'TPM';
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final type = _jenis == 'agen' ? 'AGENT' : 'TPM';
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    // Bangun daftar upload dari map (input user, tetap di widget) untuk notifier.
    final uploads = <(String, List<int>, String)>[
      for (final entry in _docFiles.entries)
        if (entry.value != null && entry.value!.bytes != null)
          (entry.key, entry.value!.bytes!, entry.value!.name),
    ];

    final error = await _notifier.save(
      isEdit: _isEdit,
      existingId: widget.existing?.id,
      submit: submit,
      name: name,
      type: type,
      phone: phone,
      email: email,
      npwp: _digitsOrNull(_npwpController),
      bankName: _bank.isEmpty ? null : _bank,
      accountNumber: _orNull(_accountNumberController),
      ktpNumber: _orNull(_ktpNumberController),
      birthDate: _isoDate(_birthDate),
      gender: _gender.isEmpty ? null : _gender,
      ktpAddress: _orNull(_ktpAddressController),
      ktpProvince: _orNull(_ktpProvinceController),
      ktpCity: _orNull(_ktpCityController),
      ktpDistrict: _orNull(_ktpDistrictController),
      ktpSubdistrict: _orNull(_ktpSubdistrictController),
      ktpRt: _orNull(_ktpRtController),
      ktpRw: _orNull(_ktpRwController),
      ktpPostalCode: _orNull(_ktpPostalController),
      domicileAddress: _orNull(_domAddressController),
      domicileProvince: _orNull(_domProvinceController),
      domicileCity: _orNull(_domCityController),
      domicileDistrict: _orNull(_domDistrictController),
      domicileSubdistrict: _orNull(_domSubdistrictController),
      domicileRt: _orNull(_domRtController),
      domicileRw: _orNull(_domRwController),
      domicilePostalCode: _orNull(_domPostalController),
      uploads: uploads,
    );

    if (!mounted) return;
    if (error == null) {
      navigator.pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(submit
              ? 'Pengajuan $label terkirim & menunggu persetujuan.'
              : 'Draft $label disimpan.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.successGreen,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  Widget _documentsSection() {
    final tiles = <Widget>[];
    for (final d in _docs) {
      if (!_isDocActive(d)) continue;
      tiles.add(_docTile(d));
      tiles.add(const SizedBox(height: 10));
    }
    return _section('Dokumen Pendaftaran', [
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        value: _domicileDiffers,
        onChanged: (v) => setState(() => _domicileDiffers = v ?? false),
        title: const Text('Alamat domisili berbeda dari KTP', style: TextStyle(fontSize: 13)),
        subtitle: const Text('Wajib lampirkan SK Domisili',
            style: TextStyle(fontSize: 11, color: AppColors.grayStage)),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        value: _wasAgentElsewhere,
        onChanged: (v) => setState(() => _wasAgentElsewhere = v ?? false),
        title: const Text('Sebelumnya menjadi agen di tempat lain', style: TextStyle(fontSize: 13)),
        subtitle: const Text('Wajib lampirkan Surat Pengunduran Diri',
            style: TextStyle(fontSize: 11, color: AppColors.grayStage)),
      ),
      const SizedBox(height: 10),
      ...tiles,
      const Text('Format file: PDF/JPG/PNG, maks 10 MB. Tanda * wajib.',
          style: TextStyle(fontSize: 11, color: AppColors.grayStage)),
    ]);
  }

  Widget _docTile(AjukanDocDef d) {
    final picked = _docFiles[d.code];
    final exists = _existingDocCodes.contains(d.code);
    final chosen = picked != null || exists;
    final statusText = picked != null ? picked.name : (exists ? 'Sudah diunggah' : 'Belum dipilih');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgScreen,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                fieldLabel(d.required ? '${d.label} *' : d.label,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: chosen ? AppColors.successGreen : AppColors.grayStage)),
              ],
            ),
          ),
          if (_templates[d.code]?.available ?? false)
            IconButton(
              tooltip: 'Unduh template',
              onPressed: _busy ? null : () => _downloadTemplate(d.code),
              icon: const Icon(Icons.download_outlined, size: 18, color: AppColors.secondaryOrange),
              visualDensity: VisualDensity.compact,
            ),
          TextButton.icon(
            onPressed: _busy ? null : () => _pickDoc(d.code),
            icon: const Icon(Icons.attach_file, size: 16),
            label: Text(chosen ? 'Ganti' : 'Pilih'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryNavy),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat template/config/opsi
    // gender/flag busy/kode dokumen eksisting berubah (ganti setState yang dipindah).
    ref.watch(ajukanAgenProvider);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: BackAppBar(title: _isEdit ? 'Edit Agen / TPM' : 'Ajukan Agen / TPM'),
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        // Cap the form width and centre it on desktop; on phones it fills width.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                _stepIndicator(),
                Expanded(
                  child: IndexedStack(
                    index: _step,
                    sizing: StackFit.expand,
                    children: [
                      // ── Langkah 1: Data calon ──
                      _stepScroll([
            _section('Jenis Pengajuan', [
              Row(
                children: [
                  Expanded(child: _jenisOption('agen', 'Agen')),
                  const SizedBox(width: 10),
                  Expanded(child: _jenisOption('tpm', 'TPM')),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _jenis == 'agen'
                    ? 'Agen memerlukan sertifikasi & dokumen lengkap.'
                    : 'TPM (Tenaga Pemasaran Mikro) — dokumen lebih ringkas.',
                style: const TextStyle(fontSize: 11, color: AppColors.grayStage),
              ),
            ]),
            const SizedBox(height: 16),
            _section('Data Calon', [
              _field('Nama Lengkap', 'Nama calon ${_jenis.toUpperCase()}',
                  code: 'NAME', controller: _nameController),
              const SizedBox(height: 12),
              _field('No. KTP', '16 digit NIK',
                  code: 'KTP_NUMBER', controller: _ktpNumberController,
                  keyboardType: TextInputType.number, required: false),
              const SizedBox(height: 12),
              _genderDropdown(),
              const SizedBox(height: 12),
              _dateField('Tanggal Lahir', _birthDate,
                  (d) => setState(() => _birthDate = d)),
              const SizedBox(height: 12),
              _field('Email', 'email@contoh.com',
                  code: 'EMAIL',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    final req = _req('EMAIL', true);
                    if (v == null || v.trim().isEmpty) return req ? 'Wajib diisi' : null;
                    if (!v.contains('@')) return 'Email tidak valid';
                    return null;
                  }),
              const SizedBox(height: 12),
              _field('No. Telepon', '08xxxxxxxxxx',
                  code: 'PHONE', controller: _phoneController, keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _field('NPWP', '00.000.000.0-000.000',
                  code: 'NPWP', controller: _npwpController, required: false,
                  keyboardType: TextInputType.number,
                  inputFormatters: [NpwpInputFormatter()]),
            ]),
            const SizedBox(height: 16),
            _section('Rekening Bank', [
              _bankField(),
              const SizedBox(height: 12),
              _field('No. Rekening', 'Nomor rekening',
                  code: 'ACCOUNT_NUMBER', controller: _accountNumberController,
                  keyboardType: TextInputType.number, required: false),
            ]),
                      ]),
                      // ── Langkah 2: Alamat ──
                      _stepScroll([
            _section('Alamat KTP', [
              _field('Alamat', 'Alamat sesuai KTP',
                  code: 'KTP_ADDRESS', controller: _ktpAddressController, required: false),
              const SizedBox(height: 12),
              RegionAddressFields(
                key: _anchorKey('KTP_REGION'),
                required: true,
                repo: _regionRepo,
                province: _ktpProvinceController,
                city: _ktpCityController,
                district: _ktpDistrictController,
                subdistrict: _ktpSubdistrictController,
                postalCode: _ktpPostalController,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: _field('RT', '000',
                          code: 'KTP_RT', controller: _ktpRtController,
                          keyboardType: TextInputType.number, required: false)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _field('RW', '000',
                          code: 'KTP_RW', controller: _ktpRwController,
                          keyboardType: TextInputType.number, required: false)),
                ],
              ),
            ]),
            const SizedBox(height: 16),
            _section('Alamat Domisili', [
              _field('Alamat', 'Alamat domisili',
                  code: 'DOMICILE_ADDRESS', controller: _domAddressController, required: false),
              const SizedBox(height: 12),
              RegionAddressFields(
                key: _anchorKey('DOMICILE_REGION'),
                required: true,
                repo: _regionRepo,
                province: _domProvinceController,
                city: _domCityController,
                district: _domDistrictController,
                subdistrict: _domSubdistrictController,
                postalCode: _domPostalController,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: _field('RT', '000',
                          code: 'DOMICILE_RT', controller: _domRtController,
                          keyboardType: TextInputType.number, required: false)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _field('RW', '000',
                          code: 'DOMICILE_RW', controller: _domRwController,
                          keyboardType: TextInputType.number, required: false)),
                ],
              ),
            ]),
                      ]),
                      // ── Langkah 3: Dokumen ──
                      _stepScroll([
            KeyedSubtree(key: _anchorKey('DOCS'), child: _documentsSection()),
                      ]),
                      // ── Langkah 4: Review & kirim ──
                      _stepScroll([
            _reviewSummary(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _busy ? null : () => _save(submit: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  disabledBackgroundColor: AppColors.grayBg,
                  elevation: 0,
                  shape:
                      RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Kirim Pengajuan',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _busy ? null : () => _save(submit: false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryNavy,
                  side: const BorderSide(color: AppColors.primaryNavy, width: 1.4),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                ),
                child: const Text('Simpan sebagai Draft',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Kirim Pengajuan langsung diteruskan ke pimpinan (RO/Pimpinan Cabang) untuk persetujuan. Simpan Draft menyimpan tanpa mengirim. Pakta Integritas, PKS, SMAP & memo diunggah setelah lisensi terbit.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.grayStage),
            ),
            const SizedBox(height: 24),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Satu langkah wizard: konten yang bisa digulir dengan padding standar.
  /// Tombol navigasi (Kembali/Lanjut) ditempel di paling bawah isi — ikut
  /// menggulung, TIDAK sticky.
  Widget _stepScroll(List<Widget> children) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...children,
            _wizardNav(),
          ],
        ),
      );

  /// Indikator 4 langkah di atas form; bisa diketuk untuk lompat langkah
  /// (validasi tetap di tombol Kirim, jadi lompat aman).
  Widget _stepIndicator() {
    return Container(
      color: AppColors.surfaceWhite,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      child: Row(
        children: [
          for (int i = 0; i < _stepLabels.length; i++) _stepDot(i, _stepLabels[i]),
        ],
      ),
    );
  }

  Widget _stepDot(int i, String label) {
    final active = i == _step;
    final done = i < _step;
    final color = (active || done) ? AppColors.primaryNavy : AppColors.grayStage;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _step = i),
        child: Column(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (active || done) ? AppColors.primaryNavy : AppColors.surfaceWhite,
                border: Border.all(color: color, width: 1.5),
              ),
              child: done
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text('${i + 1}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: active ? Colors.white : color)),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: color)),
          ],
        ),
      ),
    );
  }

  /// Navigasi Kembali / Lanjut. TIDAK sticky — ikut menggulung di paling bawah
  /// isi tiap langkah. Di langkah terakhir hanya Kembali (Kirim & Draft ada di
  /// isi langkah Review). "Lanjut" memvalidasi langkah aktif dulu ([_onNext]).
  Widget _wizardNav() {
    final isLast = _step == _stepLabels.length - 1;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => setState(() => _step -= 1),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryNavy,
                  side: const BorderSide(color: AppColors.primaryNavy, width: 1.4),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Kembali',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          if (_step > 0 && !isLast) const SizedBox(width: 12),
          if (!isLast)
            Expanded(
              child: ElevatedButton(
                onPressed: _busy ? null : _onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Lanjut',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  int _activeDocCount() => _docs.where(_isDocActive).length;

  int _chosenDocCount() => _docs.where((d) {
        if (!_isDocActive(d)) return false;
        return (_docFiles[d.code]?.bytes != null) || _existingDocCodes.contains(d.code);
      }).length;

  /// Ringkasan singkat di langkah Review sebelum kirim.
  Widget _reviewSummary() {
    String orDash(TextEditingController c) =>
        c.text.trim().isEmpty ? '-' : c.text.trim();
    return _section('Ringkasan', [
      _reviewRow('Jenis', _jenis == 'agen' ? 'Agen' : 'TPM'),
      _reviewRow('Nama', orDash(_nameController)),
      _reviewRow('Email', orDash(_emailController)),
      _reviewRow('No. Telepon', orDash(_phoneController)),
      _reviewRow('Dokumen dipilih', '${_chosenDocCount()} / ${_activeDocCount()}'),
    ]);
  }

  Widget _reviewRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ),
          ],
        ),
      );

  Widget _section(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
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
          Text(title.toUpperCase(),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _jenisOption(String value, String label) {
    final selected = _jenis == value;
    return GestureDetector(
      onTap: () => setState(() => _jenis = value),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryNavy : AppColors.surfaceWhite,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(
              color: selected ? AppColors.primaryNavy : AppColors.border,
              width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _label(String text) => fieldLabel(text);

  Widget _bankField() {
    final isRequired = _req('BANK_NAME', false);
    return Column(
      key: _anchorKey('BANK_NAME'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(isRequired ? 'Nama Bank *' : 'Nama Bank'),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: _bank,
          onChanged: (val) => _bank = val,
          textCapitalization: TextCapitalization.words,
          validator: isRequired
              ? (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null
              : null,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: _decoration('Nama bank pencairan komisi'),
        ),
      ],
    );
  }

  Widget _genderDropdown() {
    return Column(
      key: _anchorKey('GENDER'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Jenis Kelamin *'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          // Nilai di luar daftar opsi membuat DropdownButtonFormField melempar
          // assertion (layar mati), bukan sekadar tampil kosong. Master data
          // bisa berubah, jadi nilainya divalidasi dulu terhadap opsinya.
          initialValue: _genderOptions.contains(_gender) ? _gender : null,
          style: AppInput.fieldText,
          isExpanded: true,
          hint: const Text('Pilih jenis kelamin',
              style: TextStyle(color: AppColors.grayStage, fontSize: 14)),
          items: _genderOptions
              .map((g) => DropdownMenuItem<String>(
                    value: g,
                    child: Text(g,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textPrimary)),
                  ))
              .toList(),
          onChanged: (val) => setState(() => _gender = val ?? ''),
          validator: (_) => _gender.trim().isEmpty ? 'Wajib dipilih' : null,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.grayStage),
          decoration: _decoration(null),
        ),
      ],
    );
  }

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime> onPicked) {
    // Tanggal picker bukan FormField, jadi errornya ditampilkan manual saat
    // validasi sudah dipicu dan tanggalnya masih kosong.
    final showError = _autovalidate != AutovalidateMode.disabled && value == null;
    return Column(
      key: _anchorKey('BIRTHDATE'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('$label *'),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: AppRadius.radiusMd,
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime(now.year - 25),
              firstDate: DateTime(1940),
              lastDate: DateTime(now.year + 1),
            );
            if (picked != null) onPicked(picked);
          },
          child: InputDecorator(
            decoration: _decoration(null)
                .copyWith(errorText: showError ? 'Wajib dipilih' : null),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value == null ? 'Pilih tanggal' : _isoDate(value)!,
                  style: TextStyle(
                      fontSize: 14,
                      color: value == null
                          ? AppColors.grayStage
                          : AppColors.textPrimary),
                ),
                const Icon(Icons.calendar_today_outlined,
                    size: 18, color: AppColors.grayStage),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(String label, String hint,
      {required TextEditingController controller,
      String? code,
      TextInputType keyboardType = TextInputType.text,
      bool required = true,
      List<TextInputFormatter>? inputFormatters,
      String? Function(String?)? validator}) {
    final isRequired = code != null ? _req(code, required) : required;
    return Column(
      key: code != null ? _anchorKey(code) : null,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(isRequired ? '$label *' : label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator ??
              (isRequired
                  ? (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null
                  : null),
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: _decoration(hint),
        ),
      ],
    );
  }

  InputDecoration _decoration(String? hint) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: AppRadius.radiusMd,
        borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.grayStage, fontSize: 14),
      filled: true,
      fillColor: AppColors.bgScreen,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: b(AppColors.border),
      focusedBorder: b(AppColors.primaryNavy, 1.5),
      errorBorder: b(AppColors.errorRed),
      focusedErrorBorder: b(AppColors.errorRed, 1.5),
      errorStyle: const TextStyle(fontSize: 12, color: AppColors.errorRed),
    );
  }
}
