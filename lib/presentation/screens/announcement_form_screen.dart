import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // TextInputFormatter + Uint8List
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../src/announcement/announcement_repository.dart';
import '../../src/network/api_client.dart';
import '../../src/network/auth_image.dart';
import '../providers/announcement_form_provider.dart';
import '../widgets/glass_app_bar.dart';

/// Create or edit a single announcement. Audience is set automatically on the server
/// from the author's role/office, so it isn't shown here.
class AnnouncementFormScreen extends ConsumerStatefulWidget {
  final AnnouncementRepository repo;
  final ApiClient apiClient;

  /// When non-null the form edits this announcement; otherwise it creates a new one.
  final Announcement? existing;

  const AnnouncementFormScreen({
    super.key,
    required this.repo,
    required this.apiClient,
    this.existing,
  });

  @override
  ConsumerState<AnnouncementFormScreen> createState() =>
      _AnnouncementFormScreenState();
}

class _AnnouncementFormScreenState
    extends ConsumerState<AnnouncementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();

  /// Jenis pengumuman tidak lagi dipilih di UI (tanpa Apresiasi/Kebijakan).
  /// Nilai lama dipertahankan saat edit, dan POLICY dipakai untuk yang baru,
  /// karena backend masih mewajibkan kolom ini.
  String _type = 'POLICY';
  bool _active = true;
  DateTime? _startsAt;
  DateTime? _endsAt;

  // New image picked in this session (overrides any existing one on save).
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;

  // State async (flag menyimpan + pesan error simpan) dikelola
  // AnnouncementFormNotifier. Field lama `_submitting` diproksikan lewat getter
  // agar build/tombol tetap memakai nama yang sama. Input form interaktif
  // (controller, jenis, toggle, tanggal, gambar) TETAP di widget ini.
  AnnouncementFormState get _afs => ref.read(announcementFormProvider);
  AnnouncementFormNotifier get _notifier =>
      ref.read(announcementFormProvider.notifier);

  bool get _submitting => _afs.submitting;
  String get _saveErrorMsg => _afs.saveErrorMsg;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    // Bersihkan sisa state simpan dari pembukaan form sebelumnya (provider ini
    // bukan autoDispose) — tanpa ini tombol simpan bisa terkunci loading.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifier.reset();
    });
    final a = widget.existing;
    if (a != null) {
      _titleCtrl.text = a.title;
      _bodyCtrl.text = a.body ?? '';
      _categoryCtrl.text = a.category ?? '';
      _type = a.type;
      _active = a.active;
      _startsAt = _parse(a.startsAt);
      _endsAt = _parse(a.endsAt);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  DateTime? _parse(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    return DateTime.tryParse(iso);
  }

  String? _fmtIso(DateTime? d) =>
      d == null ? null : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtLabel(DateTime? d) => d == null ? 'Pilih tanggal' : _fmtIso(d)!;

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat flag simpan berubah
    // (mengganti setState untuk bagian yang dipindah ke notifier).
    ref.watch(announcementFormProvider);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: _isEdit ? 'Edit Pengumuman' : 'Buat Pengumuman', showBack: true),
      body: SafeArea(
        child: Form(
          key: _formKey,
          // Cap the form width and centre it on desktop; on phones it fills width.
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _label('Kategori (opsional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _categoryCtrl,
                style: AppInput.fieldText,
                decoration: _inputDecoration('Mis. UNDERWRITING'),
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                // Ketik bebas, otomatis huruf besar (auto-KAPITAL) selagi mengetik.
                inputFormatters: [
                  TextInputFormatter.withFunction(
                    (oldValue, newValue) =>
                        newValue.copyWith(text: newValue.text.toUpperCase()),
                  ),
                  LengthLimitingTextInputFormatter(60),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _label('Judul'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleCtrl,
                style: AppInput.fieldText,
                decoration: _inputDecoration('Mis. Kebijakan Underwriting Terbaru'),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Judul wajib diisi' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              _label('Isi Pengumuman'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _bodyCtrl,
                style: AppInput.fieldText,
                decoration: _inputDecoration('Tulis detail pengumuman...'),
                minLines: 4,
                maxLines: 8,
                maxLength: 2000,
              ),
              const SizedBox(height: AppSpacing.sm),
              _label('Gambar Banner (opsional)'),
              const SizedBox(height: 6),
              _buildImagePicker(),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(child: _buildDateField('Mulai', _startsAt, () => _pickDate(true))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDateField('Berakhir', _endsAt, () => _pickDate(false))),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktif',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                subtitle: const Text('Tampilkan sebagai banner di home',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                value: _active,
                activeThumbColor: AppColors.successGreen,
                onChanged: (v) => setState(() => _active = v),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isEdit ? 'Simpan Perubahan' : 'Terbitkan',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary));

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.grayStage, fontSize: 13),
        filled: true,
        fillColor: AppColors.surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: AppRadius.radiusLg,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusLg,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusLg,
          borderSide: const BorderSide(color: AppColors.primaryNavy, width: 1.5),
        ),
      );

  Widget _buildImagePicker() {
    final hasNew = _pickedImageBytes != null;
    final existingUrl = widget.existing?.imageUrl;
    final showPreview = hasNew || existingUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showPreview) ...[
          ClipRRect(
            borderRadius: AppRadius.radiusLg,
            child: hasNew
                ? Image.memory(
                    _pickedImageBytes!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : AuthImage(
                    apiClient: widget.apiClient,
                    path: existingUrl!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image_outlined, size: 18),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryNavy,
                side: const BorderSide(color: AppColors.primaryNavy),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
              ),
              label: Text(showPreview ? 'Ganti Gambar' : 'Unggah Gambar'),
            ),
            if (hasNew) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() {
                  _pickedImageBytes = null;
                  _pickedImageName = null;
                }),
                child: const Text('Batal', style: TextStyle(color: AppColors.errorRed)),
              ),
            ],
          ],
        ),
        if (hasNew && _pickedImageName != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_pickedImageName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.successGreen,
                    fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  Widget _buildDateField(String label, DateTime? value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: AppRadius.radiusLg,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: AppRadius.radiusLg,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: AppColors.grayStage),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_fmtLabel(value),
                      style: TextStyle(
                          fontSize: 13,
                          color: value == null
                              ? AppColors.grayStage
                              : AppColors.textPrimary)),
                ),
                if (value != null)
                  GestureDetector(
                    onTap: () => setState(() {
                      if (label == 'Mulai') {
                        _startsAt = null;
                      } else {
                        _endsAt = null;
                      }
                    }),
                    child: const Icon(Icons.close, size: 16, color: AppColors.grayStage),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = (isStart ? _startsAt : _endsAt) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryNavy,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startsAt = picked;
      } else {
        _endsAt = picked;
      }
    });
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.first;
    if (file.bytes == null) {
      _snack('Gagal membaca gambar yang dipilih.', isError: true);
      return;
    }
    setState(() {
      _pickedImageBytes = file.bytes;
      _pickedImageName = file.name;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_startsAt != null && _endsAt != null && _endsAt!.isBefore(_startsAt!)) {
      _snack('Tanggal berakhir tidak boleh sebelum tanggal mulai.', isError: true);
      return;
    }
    // Penyimpanan (create/update + unggah gambar, flag `submitting`/error) di-
    // delegasikan ke notifier; nilai form (input user) tetap dibangun di sini.
    // Navigasi & snack tetap di widget.
    final saved = await _notifier.save(
      isEdit: _isEdit,
      existingId: widget.existing?.id,
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      type: _type,
      category: _categoryCtrl.text.trim(),
      active: _active,
      startsAt: _fmtIso(_startsAt),
      endsAt: _fmtIso(_endsAt),
      imageBytes: _pickedImageBytes,
      imageName: _pickedImageName,
    );
    if (!mounted) return;
    if (saved != null) {
      Navigator.of(context).pop(true);
    } else {
      _snack(_saveErrorMsg, isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.errorRed : AppColors.successGreen,
    ));
  }
}
