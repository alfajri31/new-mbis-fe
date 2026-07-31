import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_theme.dart';
import '../../utils/input_formatters.dart';
import '../widgets/field_label.dart';
import '../widgets/search_picker_sheet.dart';
import '../widgets/add_customer/add_customer_form_section.dart';
import '../widgets/add_customer/blacklist_checking_view.dart';
import '../widgets/add_customer/blacklist_match_card.dart';
import '../widgets/add_customer/bumn_relation_info_box.dart';
import '../widgets/add_customer/location_picker_slot.dart';
import '../widgets/add_customer/npwp_status_line.dart';
import '../widgets/add_customer/readonly_address_box.dart';
import '../widgets/add_customer/similar_customers_section.dart';
import '../../core/providers/repository_providers.dart';
import '../providers/add_customer_provider.dart';
import '../../src/customer/customer_repository.dart';
import '../../src/reference/reference_repository.dart';
import '../../src/bumn/bumn_repository.dart';
// Heavy map picker (flutter_map): loaded on demand to keep it out of the
// initial bundle. The lightweight result type lives in its own file so we can
// still name it here without pulling in the map library.
import '../../src/location/location_picker_screen.dart' deferred as locpick;
import '../../src/location/picked_location.dart';

/// A document picked by the user but not yet uploaded to the server.
/// Held in memory until the customer is saved (we need the customer id first).
class _PickedDoc {
  final String fileName;
  final List<int> bytes;
  const _PickedDoc(this.fileName, this.bytes);
}

class AddCustomerScreen extends ConsumerStatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form fields state
  String _badanHukum = '';
  String _namaCustomer = '';
  String _entitas = '';
  String _strukturRelasi = '';
  String _nib = '';
  String _npwp = '';
  String _email = '';
  String _phone = '';
  String _alamat = '';
  String _picName = '';
  String _picPhone = '';
  String _picJabatan = '';
  // Location state (real GPS / map pick)
  String _locationCoordinate = '';
  String _locationAddress =
      ''; // picker's (editable) address for the geotag box
  double? _locationLat;
  double? _locationLng;
  final TextEditingController _alamatController = TextEditingController();

  // ── New-DB integration: kategori bank / BUMN ──
  String _kategori = 'NON_PERBANKAN'; // PERBANKAN | NON_PERBANKAN
  bool _isBumn = false;
  bool _isHvc = false;
  String _nik = '';
  String _picTitle = '';
  BankRef? _selectedBank;
  BankBranchRef? _selectedBranch;
  String? _bumnName; // nama entitas BUMN terpilih (= nama customer)
  String? _bumnId; // FK master_bumn — sumber struktur relasi + induk
  String? _bumnInduk; // nama induk (parentName), untuk tampilan

  // State async (opsi referensi/BUMN, cek blacklist, similar, simpan) dikelola
  // AddCustomerNotifier. Field lama diproksikan lewat getter di bawah agar
  // seluruh kode build/form tetap memakai nama yang sama tanpa diubah. Input form
  // interaktif (controller, nilai terpilih, toggle, upload, lokasi) TETAP di sini.
  AddCustomerState get _acs => ref.read(addCustomerProvider);
  AddCustomerNotifier get _notifier => ref.read(addCustomerProvider.notifier);

  List<ParamRef> get _badanHukumOptions => _acs.badanHukumOptions;
  List<ParamRef> get _entitasOptions =>
      _acs.entitasOptions; // tanpa BUMN (BUMN lewat toggle)
  List<BumnOption> get _bumnOptions =>
      _acs.bumnOptions; // dari master_bumn (515 entitas nyata)
  List<BankRef> get _banks => _acs.banks;
  // Dropdown berbasis parameter (editable di Kelola Master Data). Default =
  // fallback bila parameter belum termuat / kosong.
  List<String> get _picTitleOptions => _acs.picTitleOptions;

  bool get _isBank => _kategori == 'PERBANKAN';
  // Bank & BUMN: NIB/NPWP & data perusahaan disembunyikan.
  bool get _hideCompanyIdentity => _isBank || _isBumn;

  // Agent flow: an agent must refer the new customer to an RM in their scope.
  // Deteksi peran + daftar RM (async) ada di notifier; RM terpilih (input user)
  // tetap di widget.
  bool get _isAgent => _acs.isAgent;
  bool get _loadingRms => _acs.loadingRms;
  List<AssignableRm> get _rms => _acs.rms;
  String? _selectedRmId;

  @override
  void initState() {
    super.initState();
    // Bootstrap notifier setelah frame pertama: deteksi peran (agent → muat
    // daftar RM) + muat opsi referensi/BUMN. Sesi dibaca notifier dari
    // sessionProvider — tak perlu context. (Dulu dipecah antara initState
    // post-frame [agent] + didChangeDependencies [referensi].)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start();
    });
  }

  @override
  void dispose() {
    _alamatController.dispose();
    super.dispose();
  }

  // Documents state: picked files held in memory until the customer is saved.
  // Input user (upload map) → TETAP di widget.
  final Map<String, _PickedDoc?> _uploadedDocs = {
    'NPWP': null,
    'NIB': null,
    'NIK/KTP PIC': null,
  };

  // Blacklist / simpan state (async) dikelola AddCustomerNotifier; diproksikan
  // lewat getter agar sheet & tombol tetap membaca nama lama.
  // status: 'idle' | 'checking' | 'clean' | 'warning' | 'error' | 'saveError'.
  // WARNING-ONLY — tidak ada status 'blocked'; customer selalu tersimpan.
  String get _blacklistStatus => _acs.blacklistStatus;
  BlacklistCheckResult? get _blacklistResult => _acs.blacklistResult;
  // Possible existing duplicates (national), surfaced in the same pre-save sheet
  // so a swasta multi-branch company stays one entity. Warning-only.
  List<SimilarCustomer> get _similarCustomers => _acs.similarCustomers;
  String get _saveErrorMsg => _acs.saveErrorMsg;
  bool get _saving => _acs.saving; // sedang menyimpan setelah RM konfirmasi

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat opsi/flag async berubah
    // (mengganti setState untuk bagian yang dipindah ke notifier).
    ref.watch(addCustomerProvider);
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
          'Tambah Customer',
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
        // Cap the form width and centre it so it doesn't run edge-to-edge on
        // desktop; on phones (< 640) it simply fills the available width.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // SECTION: RM TUJUAN (hanya untuk agen)
                  if (_isAgent) ...[
                    _buildAgentRmSection(),
                    const SizedBox(height: 16),
                  ],
                  // SECTION: DATA PERUSAHAAN
                  AddCustomerFormSection(
                    title: 'Data Perusahaan',
                    children: [
                      _buildToggle2(
                        'Kategori',
                        'Non Perbankan',
                        'NON_PERBANKAN',
                        'Perbankan',
                        'PERBANKAN',
                        _kategori,
                        (v) => setState(() {
                          _kategori = v;
                          _selectedBank = null;
                          _selectedBranch = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      _buildToggle2(
                        'Entitas BUMN',
                        'Non BUMN',
                        'false',
                        'BUMN',
                        'true',
                        _isBumn ? 'true' : 'false',
                        (v) => setState(() {
                          _isBumn = v == 'true';
                          if (!_isBumn) {
                            _strukturRelasi = '';
                            _bumnName = null;
                            _bumnId = null;
                            _bumnInduk = null;
                          }
                          _selectedBank = null; // HIMBARA filter changes
                          _selectedBranch = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      // HVC = High Value Customer (flag prioritas).
                      _buildToggle2(
                        'Status HVC',
                        'Non HVC',
                        'false',
                        'HVC',
                        'true',
                        _isHvc ? 'true' : 'false',
                        (v) => setState(() => _isHvc = v == 'true'),
                      ),
                      const SizedBox(height: 12),
                      if (_isBank) ...[
                        _buildPickerField(
                          'Bank *',
                          _selectedBank?.name,
                          _pickBank,
                        ),
                        if (_selectedBank != null) ...[
                          const SizedBox(height: 12),
                          _buildPickerField(
                            'Cabang *',
                            _selectedBranch?.name,
                            _pickBranch,
                          ),
                        ],
                        if (_isBumn) ...[
                          const SizedBox(height: 4),
                          const Text(
                            '* Hanya bank BUMN (HIMBARA)',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ] else if (_isBumn) ...[
                        _buildPickerField(
                          'Perusahaan BUMN *',
                          _bumnName,
                          _pickBumn,
                        ),
                        // Struktur relasi & induk TIDAK diinput manual — otomatis dari
                        // node master_bumn yang dipilih (datanya sudah ada di sana).
                        if (_bumnId != null && _bumnId!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          BumnRelationInfoBox(
                            strukturRelasi: _strukturRelasi,
                            bumnInduk: _bumnInduk,
                          ),
                        ],
                        if (_bumnOptions.isEmpty) ...[
                          const SizedBox(height: 4),
                          const Text(
                            '* Daftar BUMN belum tersedia (menyusul)',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ] else ...[
                        _buildDropdownFieldKV(
                          'Badan Hukum *',
                          _badanHukum.isEmpty ? null : _badanHukum,
                          _badanHukumOptions,
                          (val) => setState(() => _badanHukum = val ?? ''),
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          label: 'Nama Customer *',
                          hint: 'Nama lengkap perusahaan',
                          onChanged: (val) =>
                              setState(() => _namaCustomer = val),
                          validator: (val) => val == null || val.isEmpty
                              ? 'Nama customer wajib diisi'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        _buildDropdownFieldKV(
                          'Entitas Customer *',
                          _entitas.isEmpty ? null : _entitas,
                          _entitasOptions,
                          (val) => setState(() => _entitas = val ?? ''),
                        ),
                        if (_badanHukum.toUpperCase() == 'PERORANGAN') ...[
                          const SizedBox(height: 12),
                          _buildTextField(
                            label: 'NIK *',
                            hint: 'Nomor Induk Kependudukan',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(16),
                            ],
                            onChanged: (val) => setState(() => _nik = val),
                            validator: (val) =>
                                (val != null &&
                                    val.isNotEmpty &&
                                    val.length != 16)
                                ? 'NIK harus 16 digit'
                                : null,
                          ),
                        ],
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // SECTION: IDENTITAS & KONTAK PERUSAHAAN (semua opsional)
                  AddCustomerFormSection(
                    title: 'Identitas & Kontak Perusahaan',
                    children: [
                      _buildTextField(
                        label: 'Email Perusahaan',
                        hint: 'perusahaan@email.com',
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (val) => setState(() => _email = val),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        label: 'No. Telepon Perusahaan',
                        hint: '021-xxxx-xxxx',
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9+\-\s]'),
                          ),
                          LengthLimitingTextInputFormatter(20),
                        ],
                        onChanged: (val) => setState(() => _phone = val),
                        validator: _validatePhoneOptional,
                      ),
                      // NIB & NPWP disembunyikan untuk customer bank / BUMN.
                      if (!_hideCompanyIdentity) ...[
                        const SizedBox(height: 12),
                        _buildTextField(
                          label: 'NIB',
                          hint: 'Nomor Induk Berusaha (13 digit)',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(13),
                          ],
                          onChanged: (val) => setState(() => _nib = val),
                          validator: (val) =>
                              (val != null &&
                                  val.isNotEmpty &&
                                  val.length != 13)
                              ? 'NIB harus 13 digit'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          label: 'NPWP',
                          hint: 'XX.XXX.XXX.X-XXX.XXX',
                          keyboardType: TextInputType.number,
                          inputFormatters: [NpwpInputFormatter()],
                          onChanged: (val) => setState(() => _npwp = val),
                          validator: _validateNpwpOptional,
                        ),
                      ],
                      // Alamat: untuk bank diisi otomatis dari cabang terpilih.
                      if (!_isBank) ...[
                        const SizedBox(height: 12),
                        _buildTextField(
                          label: 'Alamat Lengkap Perusahaan',
                          hint: 'Alamat lengkap perusahaan',
                          maxLines: 3,
                          controller: _alamatController,
                          onChanged: (val) => setState(() => _alamat = val),
                        ),
                      ] else if (_selectedBranch?.address != null) ...[
                        const SizedBox(height: 12),
                        ReadonlyAddressBox(text: _selectedBranch!.address!),
                      ],
                      const SizedBox(height: 14),

                      // GPS / Maps Geotagging button
                      LocationPickerSlot(
                        locationCoordinate: _locationCoordinate,
                        locationAddress: _locationAddress,
                        onTap: _pickLocation,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // SECTION: IDENTITAS PIC
                  AddCustomerFormSection(
                    title: 'Identitas PIC',
                    children: [
                      _buildDropdownField(
                        label: 'Title',
                        value: _picTitle.isEmpty ? null : _picTitle,
                        items: _picTitleOptions,
                        onChanged: (val) =>
                            setState(() => _picTitle = val ?? ''),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        label: 'Nama PIC *',
                        hint: 'Nama penanggung jawab',
                        onChanged: (val) => setState(() => _picName = val),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Nama PIC wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        label: 'No. Telepon PIC',
                        hint: '08xx-xxxx-xxxx',
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9+\-\s]'),
                          ),
                          LengthLimitingTextInputFormatter(20),
                        ],
                        onChanged: (val) => setState(() => _picPhone = val),
                        validator: _validatePhoneOptional,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        label: 'Jabatan PIC',
                        hint: 'Jabatan penanggung jawab',
                        onChanged: (val) => setState(() => _picJabatan = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // SECTION: DOKUMEN
                  AddCustomerFormSection(
                    title: 'Dokumen',
                    children: [
                      _buildUploadRow('NPWP'),
                      const SizedBox(height: 10),
                      _buildUploadRow('NIB'),
                      const SizedBox(height: 10),
                      _buildUploadRow('NIK/KTP PIC'),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Format: PDF/JPG, maks 5MB per file',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // SUBMIT BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryNavy,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.radiusLg,
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Simpan & Cek Blacklist',
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
        ),
      ),
    );
  }

  /// Agent-only: pick the RM (within the agent's branch/region) this customer
  /// is referred to. The customer rolls up to that RM's office.
  Widget _buildAgentRmSection() {
    return AddCustomerFormSection(
      title: 'RM Tujuan',
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Customer ini akan ditugaskan ke RM berikut (sesuai cabang/wilayah Anda).',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 10),
        if (_loadingRms)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text(
                  'Memuat daftar RM…',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else if (_rms.isEmpty)
          const Text(
            'Tidak ada RM pada cabang/wilayah Anda.',
            style: TextStyle(fontSize: 13, color: AppColors.errorRed),
          )
        else
          DropdownButtonFormField<String>(
            // Nilai di luar daftar opsi membuat DropdownButtonFormField melempar
            // assertion (layar mati), bukan sekadar tampil kosong. Master data
            // bisa berubah, jadi nilainya divalidasi dulu terhadap opsinya.
            initialValue:
                _rms.any((r) => r.id == _selectedRmId) ? _selectedRmId : null,
            style: AppInput.fieldText,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Pilih RM',
              filled: true,
              fillColor: AppColors.bgScreen,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: AppRadius.radiusMd,
                borderSide: BorderSide.none,
              ),
            ),
            items: _rms
                .map(
                  (rm) => DropdownMenuItem<String>(
                    value: rm.id,
                    child: Text(
                      rm.officeName != null
                          ? '${rm.name} • ${rm.officeName}'
                          : rm.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => _selectedRmId = val),
            validator: (val) =>
                (val == null || val.isEmpty) ? 'Pilih RM tujuan' : null,
          ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    TextEditingController? controller,
    List<TextInputFormatter>? inputFormatters,
    required void Function(String) onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
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
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            validator: validator,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: AppColors.grayStage,
                fontSize: 14,
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

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.bgScreen,
            borderRadius: AppRadius.radiusMd,
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonFormField<String>(
            // Nilai di luar daftar opsi membuat DropdownButtonFormField melempar
            // assertion (layar mati), bukan sekadar tampil kosong. Master data
            // bisa berubah, jadi nilainya divalidasi dulu terhadap opsinya.
            initialValue: items.contains(value) ? value : null,
            style: AppInput.fieldText,
            isExpanded: true,
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            validator: validator,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            icon: const Icon(
              Icons.keyboard_arrow_down,
              color: AppColors.grayStage,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadRow(String docType) {
    final picked = _uploadedDocs[docType];
    final isUploaded = picked != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgScreen,
        borderRadius: AppRadius.radiusSm,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  docType,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (isUploaded) ...[
                  const SizedBox(height: 2),
                  Text(
                    picked.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.successGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (isUploaded) {
                setState(() => _uploadedDocs[docType] = null);
              } else {
                _pickDocument(docType);
              }
            },
            icon: Icon(
              isUploaded ? Icons.check : Icons.upload_file_outlined,
              size: 13,
              color: isUploaded ? Colors.white : AppColors.primaryNavy,
            ),
            label: Text(
              isUploaded ? 'Terunggah' : 'Upload',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isUploaded ? Colors.white : AppColors.primaryNavy,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isUploaded
                  ? AppColors.successGreen
                  : AppColors.navyBg,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Two-option pill toggle (left/right) backed by a value key.
  Widget _buildToggle2(
    String label,
    String leftLabel,
    String leftVal,
    String rightLabel,
    String rightVal,
    String current,
    ValueChanged<String> onChanged,
  ) {
    Widget opt(String text, String val) {
      final selected = current == val;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(val),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryNavy : AppColors.surfaceWhite,
              borderRadius: AppRadius.radiusMd,
              border: Border.all(
                color: selected ? AppColors.primaryNavy : AppColors.border,
                width: 1.5,
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        Row(
          children: [
            opt(leftLabel, leftVal),
            const SizedBox(width: 10),
            opt(rightLabel, rightVal),
          ],
        ),
      ],
    );
  }

  /// A tappable field that opens a searchable picker (bank/cabang/BUMN).
  Widget _buildPickerField(String label, String? value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 52,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.bgScreen,
              borderRadius: AppRadius.radiusMd,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value ?? 'Pilih & cari...',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: value == null
                          ? AppColors.grayStage
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(Icons.search, size: 18, color: AppColors.grayStage),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Dropdown backed by master-parameter key/value options.
  Widget _buildDropdownFieldKV(
    String label,
    String? valueKey,
    List<ParamRef> options,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          // Nilai di luar daftar opsi membuat DropdownButtonFormField melempar
          // assertion (layar mati), bukan sekadar tampil kosong. Master data
          // bisa berubah, jadi nilainya divalidasi dulu terhadap opsinya.
          initialValue:
              options.any((o) => o.key == valueKey) ? valueKey : null,
          style: AppInput.fieldText,
          isExpanded: true,
          items: options
              .map(
                (o) => DropdownMenuItem<String>(
                  value: o.key,
                  child: Text(
                    o.value,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.grayStage,
          ),
          decoration: _kvDecoration(),
        ),
      ],
    );
  }

  Widget _fieldLabel(String label) => fieldLabel(label);

  InputDecoration _kvDecoration() {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: AppRadius.radiusMd,
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      filled: true,
      fillColor: AppColors.bgScreen,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: b(AppColors.border),
      focusedBorder: b(AppColors.primaryNavy, 1.5),
    );
  }

  // ── Searchable pickers ──
  Future<void> _pickBank() async {
    final himbaraOnly = _isBumn;
    var source = himbaraOnly
        ? _banks.where((b) => (b.tipeBank ?? '') == 'HIMBARA').toList()
        : _banks;
    final picked = await _showSearchPicker<BankRef>(
      title: himbaraOnly ? 'Pilih Bank BUMN' : 'Pilih Bank',
      initial: source,
      labelOf: (b) => b.name,
      onSearch: (q) async => source
          .where((b) => b.name.toLowerCase().contains(q.toLowerCase()))
          .toList(),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedBank = picked;
        _selectedBranch = null;
      });
    }
  }

  Future<void> _pickBranch() async {
    final bank = _selectedBank;
    if (bank == null) return;
    // Reference repo dari provider (dulu field `_refRepo`, kini dikelola lewat
    // referenceRepoProvider). Selalu tersedia saat bank sudah dipilih.
    final refRepo = ref.read(referenceRepoProvider);
    // Preload the first page of branches so the list isn't empty until the user
    // types (the previous `initial: []` made the cabang picker look empty).
    final initial = await refRepo.branches(bank.id);
    if (!mounted) return;
    final picked = await _showSearchPicker<BankBranchRef>(
      title: 'Pilih Cabang',
      initial: initial,
      labelOf: (b) => b.name,
      onSearch: (q) => refRepo.branches(bank.id, q: q),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedBranch = picked;
        _alamat = picked.address ?? '';
      });
    }
  }

  Future<void> _pickBumn() async {
    final picked = await _showSearchPicker<BumnOption>(
      title: 'Pilih Perusahaan BUMN',
      initial: _bumnOptions,
      labelOf: (b) => b.name,
      onSearch: (q) async => _bumnOptions
          .where((b) => b.name.toLowerCase().contains(q.toLowerCase()))
          .toList(),
    );
    if (picked != null && mounted) {
      setState(() {
        _bumnId = picked.id;
        _bumnName = picked.name;
        // Struktur relasi diturunkan dari level node (mis. "Anak" -> "Anak Perusahaan"),
        // selaras dengan format param STRUKTUR_RELASI & seed.
        _strukturRelasi = (picked.level != null && picked.level!.isNotEmpty)
            ? '${picked.level} Perusahaan'
            : '';
        _bumnInduk = picked.parentName;
      });
    }
  }

  /// Generic searchable bottom-sheet picker.
  Future<T?> _showSearchPicker<T>({
    required String title,
    required List<T> initial,
    required String Function(T) labelOf,
    required Future<List<T>> Function(String) onSearch,
  }) {
    return showSearchPicker<T>(
      context,
      title: title,
      initial: initial,
      labelOf: labelOf,
      onSearch: onSearch,
    );
  }

  Future<void> _pickLocation() async {
    await locpick.loadLibrary();
    if (!mounted) return;
    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => locpick.LocationPickerScreen(
          initial: (_locationLat != null && _locationLng != null)
              ? PickedLocation(
                  _locationLat!,
                  _locationLng!,
                  address: _locationAddress.isEmpty ? null : _locationAddress,
                )
              : null,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _locationLat = result.latitude;
      _locationLng = result.longitude;
      _locationCoordinate = result.label;
      _locationAddress = result.address ?? '';
      // Auto-fill the address field, but never clobber what the user typed.
      if (_locationAddress.isNotEmpty && _alamat.trim().isEmpty) {
        _alamat = _locationAddress;
        _alamatController.text = _locationAddress;
      }
    });
  }

  Future<void> _pickDocument(String docType) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData:
          true, // ensures bytes are available on all platforms (incl. web)
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.first;
    if (file.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membaca file yang dipilih.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }
    setState(() {
      _uploadedDocs[docType] = _PickedDoc(file.name, file.bytes!);
    });
  }

  /// Nomor telepon opsional: kalau diisi harus 8–15 digit (abaikan +, -, spasi).
  String? _validatePhoneOptional(String? val) {
    if (val == null || val.trim().isEmpty) return null;
    final digits = val.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 8 || digits.length > 15) {
      return 'Nomor telepon 8–15 digit';
    }
    return null;
  }

  /// NPWP opsional: kalau diisi harus 15 digit (format XX.XXX.XXX.X-XXX.XXX).
  String? _validateNpwpOptional(String? val) {
    if (val == null || val.trim().isEmpty) return null;
    final digits = val.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 15) return 'NPWP harus 15 digit';
    return null;
  }

  void _handleSubmit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // Mode-specific required fields (pickers/KV dropdowns aren't form-validated).
    final messenger = ScaffoldMessenger.of(context);
    void warn(String m) => messenger.showSnackBar(
      SnackBar(content: Text(m), backgroundColor: AppColors.errorRed),
    );
    if (_isBank) {
      if (_selectedBank == null || _selectedBranch == null) {
        warn('Pilih bank & cabang');
        return;
      }
    } else if (_isBumn) {
      if (_bumnId == null || _bumnId!.isEmpty) {
        warn('Pilih perusahaan BUMN');
        return;
      }
    } else {
      if (_badanHukum.isEmpty || _namaCustomer.isEmpty || _entitas.isEmpty) {
        warn('Lengkapi badan hukum, nama, dan entitas customer');
        return;
      }
      if (_badanHukum.toUpperCase() == 'PERORANGAN' && _nik.isEmpty) {
        warn('NIK wajib diisi untuk perorangan');
        return;
      }
    }
    _showBlacklistDialog();
  }

  /// The effective customer name across modes (bank/BUMN derive it).
  String _effectiveName() {
    if (_isBank) {
      final bank = _selectedBank?.name ?? '';
      final branch = _selectedBranch?.name ?? '';
      return branch.isEmpty ? bank : '$bank - Cabang $branch';
    }
    if (_isBumn) return _bumnName ?? '';
    return _namaCustomer;
  }

  void _showBlacklistDialog() {
    _notifier.beginBlacklistCheck();

    // Sheet berlangganan state notifier (Consumer) → rebuild otomatis saat cek
    // selesai / status simpan berubah, menggantikan StatefulBuilder+setModalState.
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final status = ref.watch(addCustomerProvider).blacklistStatus;
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (status == 'checking') ...[
                    const BlacklistCheckingView(),
                  ] else ...[
                    ..._buildResultContent(sheetContext),
                  ],
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      // Jika sheet tertutup saat masih proses, reset agar tombol aktif lagi.
      if (_blacklistStatus == 'checking') {
        _notifier.resetBlacklistStatus();
      }
    });

    // Cek blacklist atas input (BELUM disimpan). Dijalankan dari sini (event
    // handler), bukan di dalam builder, agar mutasi state tak terjadi saat build.
    _runPreview();
  }

  /// Simpan customer lalu jalankan pengecekan blacklist (warning-only).
  /// Customer selalu tersimpan; hasil cek hanya jadi peringatan untuk RM.
  Map<String, dynamic> _payload() => {
    'name': _effectiveName(),
    'legalEntity': _hideCompanyIdentity ? null : _badanHukum,
    'entityCategory': _isBumn ? 'BUMN' : _entitas,
    'category': _kategori,
    'isBumn': _isBumn,
    'isHvc': _isHvc,
    'bumnId': _isBumn ? _bumnId : null,
    // struktur relasi + induk diturunkan server-side dari bumnId; dikirim juga
    // untuk kompatibilitas (backend menimpanya dari node master_bumn).
    'bumnName': _isBumn ? _bumnInduk : null,
    'bankBranchId': _isBank ? _selectedBranch?.id : null,
    'strukturRelasi': _isBumn ? _strukturRelasi : null,
    // NPWP dikirim sebagai angka murni (tanpa titik/strip) agar konsisten
    // dengan penyimpanan & pencocokan blacklist; UI hanya memformat tampilan.
    'npwp': _hideCompanyIdentity || _npwp.isEmpty
        ? null
        : _npwp.replaceAll(RegExp(r'[^0-9]'), ''),
    'nib': _hideCompanyIdentity ? null : _nib,
    'nik': _nik.isEmpty ? null : _nik,
    'address': _alamat,
    'companyEmail': _email,
    'companyPhone': _phone,
    'latitude': _locationLat?.toString(),
    'longitude': _locationLng?.toString(),
    'picTitle': _picTitle.isEmpty ? null : _picTitle,
    'picName': _picName,
    'picPhone': _picPhone,
    'picJabatan': _picJabatan.isEmpty ? null : _picJabatan,
    if (_isAgent && _selectedRmId != null) 'rmId': _selectedRmId,
  };

  /// Cek blacklist atas input (TANPA menyimpan) → delegasi ke notifier. Logika
  /// (similar + previewBlacklist) dipindah utuh ke AddCustomerNotifier.runPreview.
  Future<void> _runPreview() {
    return _notifier.runPreview(
      isBank: _isBank,
      isBumn: _isBumn,
      name: _effectiveName(),
      npwp: _npwp,
      payload: _payload(),
    );
  }

  /// Simpan customer setelah RM menekan konfirmasi. Penyimpanan + unggah dokumen
  /// (async, flag `saving`/error) dikelola notifier; navigasi & sumber upload map
  /// (input user) tetap di widget.
  Future<void> _confirmSave(BuildContext sheetContext) async {
    final nav = Navigator.of(sheetContext);
    // Bangun daftar upload dari map (input user, tetap di widget) untuk notifier.
    final uploads = <(String, List<int>, String)>[
      for (final entry in _uploadedDocs.entries)
        if (entry.value != null)
          (entry.key, entry.value!.bytes, entry.value!.fileName),
    ];
    final created = await _notifier.save(payload: _payload(), uploads: uploads);
    if (!mounted) return;
    if (created != null) {
      nav.pop(); // tutup sheet
      nav.pop(created); // kembali ke list (bawa customer baru) & refresh
    }
    // Gagal → notifier set status 'saveError'; Consumer sheet rebuild menampilkannya.
  }

  List<Widget> _buildResultContent(BuildContext sheetContext) {
    if (_blacklistStatus == 'saveError') {
      return _buildSaveErrorContent(sheetContext);
    }
    final result = _blacklistResult;
    if (result == null) return const [];

    final bool isWarning = _blacklistStatus == 'warning';
    final bool isError = _blacklistStatus == 'error';

    final Color accent = isWarning
        ? AppColors.errorRed
        : isError
        ? const Color(0xFFB7791F)
        : AppColors.successGreen;
    final Color accentBg = isWarning
        ? AppColors.redLight
        : isError
        ? const Color(0xFFFDF6E3)
        : AppColors.greenLight;
    final IconData icon = isWarning
        ? Icons.warning_amber_outlined
        : isError
        ? Icons.cloud_off_outlined
        : Icons.check_circle_outline;
    final String title = isWarning
        ? 'Perlu Perhatian'
        : isError
        ? 'Pengecekan Tidak Lengkap'
        : 'Status Bersih';
    final String subtitle = isWarning
        ? 'Customer tetap tersimpan. Tinjau temuan; keputusan di tangan Anda.'
        : isError
        ? 'Customer tersimpan, namun INAPROC tidak dapat dihubungi. Coba cek ulang nanti.'
        : 'Tidak ditemukan kecocokan di daftar hitam INAPROC.';

    return [
      Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: accentBg, shape: BoxShape.circle),
            child: Icon(icon, color: accent, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      NpwpStatusLine(result: result),
      if (isWarning) ...[
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${result.matches.length} kemungkinan kecocokan',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: Column(
              children: result.matches
                  .map((m) => BlacklistMatchCard(match: m))
                  .toList(),
            ),
          ),
        ),
      ],
      if (_similarCustomers.isNotEmpty) ...[
        const SizedBox(height: 16),
        SimilarCustomersSection(similarCustomers: _similarCustomers),
      ],
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _saving ? null : () => _confirmSave(sheetContext),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryNavy,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
            elevation: 0,
          ),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  isWarning
                      ? 'Simpan & Lanjut'
                      : isError
                      ? 'Tetap Simpan'
                      : 'Simpan',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: TextButton(
          onPressed: _saving
              ? null
              : () {
                  Navigator.of(
                    sheetContext,
                  ).pop(); // tutup sheet, tidak menyimpan apa pun
                  _notifier.resetBlacklistStatus();
                },
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          ),
          child: const Text(
            'Tidak Jadi Simpan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.errorRed,
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildSaveErrorContent(BuildContext sheetContext) {
    return [
      Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.redLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline,
              color: AppColors.errorRed,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Gagal Menyimpan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.errorRed,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        _saveErrorMsg.isEmpty
            ? 'Terjadi kesalahan. Silakan coba lagi.'
            : _saveErrorMsg,
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(sheetContext).pop();
            _notifier.resetBlacklistStatus();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.errorRed,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
            elevation: 0,
          ),
          child: const Text(
            'Tutup',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ];
  }
}
