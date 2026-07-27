import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../widgets/field_label.dart';
import '../../src/app.dart';
import '../../src/network/api_client.dart';
import '../../src/agent/agent_repository.dart';
import '../../src/common/file_opener.dart';
import '../providers/ajukan_agen_provider.dart';
import '../widgets/back_app_bar.dart';
import '../widgets/missing_fields_notice.dart';

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

  // State async (template dokumen, config field/checklist, opsi gender, kode
  // dokumen eksisting, flag simpan) dikelola AjukanAgenNotifier. Field lama
  // diproksikan lewat getter agar kode build/form memakai nama yang sama tanpa
  // diubah. Input form (controller, jenis/bank/gender terpilih, tanggal lahir,
  // toggle domisili/ex-agen, map upload) TETAP di sini.
  AjukanAgenState get _aas => ref.read(ajukanAgenProvider);
  AjukanAgenNotifier get _notifier => ref.read(ajukanAgenProvider.notifier);

  Map<String, AgentTemplateItem> get _templates => _aas.templates; // code → template (for download buttons)
  Map<String, bool> get _fieldRequired => _aas.fieldRequired; // field code → wajib (admin config)
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
    _npwpController.text = e.npwp;
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
    _domAddressController.text = e.domicileAddress;
    _domProvinceController.text = e.domicileProvince;
    _domCityController.text = e.domicileCity;
    _domDistrictController.text = e.domicileDistrict;
    _domSubdistrictController.text = e.domicileSubdistrict;
    _domRtController.text = e.domicileRt;
    _domRwController.text = e.domicileRw;
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

  bool _req(String code, bool fallback) => _fieldRequired[code] ?? fallback;

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
  // Alamat Domisili
  final _domAddressController = TextEditingController();
  final _domProvinceController = TextEditingController();
  final _domCityController = TextEditingController();
  final _domDistrictController = TextEditingController();
  final _domSubdistrictController = TextEditingController();
  final _domRtController = TextEditingController();
  final _domRwController = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _nameController, _npwpController, _emailController, _phoneController,
      _ktpNumberController, _accountNumberController,
      _ktpAddressController, _ktpProvinceController, _ktpCityController,
      _ktpDistrictController, _ktpSubdistrictController, _ktpRtController, _ktpRwController,
      _domAddressController, _domProvinceController, _domCityController,
      _domDistrictController, _domSubdistrictController, _domRtController, _domRwController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _isoDate(DateTime? d) =>
      d == null ? null : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String? _orNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  /// Phase-1 document requirements, in display order. Conditional docs only
  /// appear (and are only required) when their toggle is on.
  List<AjukanDocDef> get _phase1Docs => const [
        AjukanDocDef('KTP', 'Fotokopi KTP', required: true),
        AjukanDocDef('NPWP', 'Fotokopi NPWP', required: true),
        AjukanDocDef('PIPELINE', 'Dokumen Pipeline', required: true),
        AjukanDocDef('SURAT_PERNYATAAN', 'Surat Pernyataan Bermeterai', required: true),
        AjukanDocDef('PENGALAMAN_KERJA', 'Pengalaman Kerja', required: true),
        AjukanDocDef('MEMO_1', 'Memo', required: true),
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
      npwp: _orNull(_npwpController),
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
      domicileAddress: _orNull(_domAddressController),
      domicileProvince: _orNull(_domProvinceController),
      domicileCity: _orNull(_domCityController),
      domicileDistrict: _orNull(_domDistrictController),
      domicileSubdistrict: _orNull(_domSubdistrictController),
      domicileRt: _orNull(_domRtController),
      domicileRw: _orNull(_domRwController),
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
            child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
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
                  code: 'NPWP', controller: _npwpController, required: false),
            ]),
            const SizedBox(height: 16),
            _section('Rekening Bank', [
              _bankField(),
              const SizedBox(height: 12),
              _field('No. Rekening', 'Nomor rekening',
                  code: 'ACCOUNT_NUMBER', controller: _accountNumberController,
                  keyboardType: TextInputType.number, required: false),
            ]),
            const SizedBox(height: 16),
            _section('Alamat KTP', [
              _field('Alamat', 'Alamat sesuai KTP',
                  code: 'KTP_ADDRESS', controller: _ktpAddressController, required: false),
              const SizedBox(height: 12),
              _field('Provinsi', 'Provinsi',
                  code: 'KTP_PROVINCE', controller: _ktpProvinceController, required: false),
              const SizedBox(height: 12),
              _field('Kota / Kabupaten', 'Kota / Kabupaten',
                  code: 'KTP_CITY', controller: _ktpCityController, required: false),
              const SizedBox(height: 12),
              _field('Kecamatan', 'Kecamatan',
                  code: 'KTP_DISTRICT', controller: _ktpDistrictController, required: false),
              const SizedBox(height: 12),
              _field('Kelurahan / Desa', 'Kelurahan / Desa',
                  code: 'KTP_SUBDISTRICT', controller: _ktpSubdistrictController, required: false),
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
              _field('Provinsi', 'Provinsi',
                  code: 'DOMICILE_PROVINCE', controller: _domProvinceController, required: false),
              const SizedBox(height: 12),
              _field('Kota / Kabupaten', 'Kota / Kabupaten',
                  code: 'DOMICILE_CITY', controller: _domCityController, required: false),
              const SizedBox(height: 12),
              _field('Kecamatan', 'Kecamatan',
                  code: 'DOMICILE_DISTRICT', controller: _domDistrictController, required: false),
              const SizedBox(height: 12),
              _field('Kelurahan / Desa', 'Kelurahan / Desa',
                  code: 'DOMICILE_SUBDISTRICT', controller: _domSubdistrictController, required: false),
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
            const SizedBox(height: 16),
            _documentsSection(),
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
          ],
        ),
          ),
        ),
      ),
    );
  }

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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Jenis Kelamin'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          // Nilai di luar daftar opsi membuat DropdownButtonFormField melempar
          // assertion (layar mati), bukan sekadar tampil kosong. Master data
          // bisa berubah, jadi nilainya divalidasi dulu terhadap opsinya.
          initialValue: _genderOptions.contains(_gender) ? _gender : null,
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
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.grayStage),
          decoration: _decoration(null),
        ),
      ],
    );
  }

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime> onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
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
            decoration: _decoration(null),
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
      String? Function(String?)? validator}) {
    final isRequired = code != null ? _req(code, required) : required;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(isRequired ? '$label *' : label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
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
