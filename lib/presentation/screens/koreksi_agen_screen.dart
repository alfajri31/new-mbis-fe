import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../src/agent/agent_repository.dart';
import '../../src/region/region_repository.dart';
import '../../core/providers/repository_providers.dart';
import '../widgets/back_app_bar.dart';
import '../widgets/field_label.dart';
import '../widgets/region_address_fields.dart';

/// Koreksi data agen oleh pengelola agen kantor pusat (ADMIN & DIV_AGEN) —
/// `PUT /api/agents/{id}/profile`.
///
/// Layar ini ADA justru karena jalur RM (`PUT /api/agents/{id}`) hanya melayani
/// agen DRAFT/REJECTED: begitu pengajuan diproses, datanya membeku, termasuk saat
/// rekening komisinya pindah bank atau namanya salah ketik.
///
/// Dua hal yang membedakannya dari form pengajuan:
///  * **Hanya yang berubah yang dikirim.** Field disetel dari nilai sekarang, lalu
///    dibandingkan dengan nilai awal saat simpan. Mengirim payload penuh berisiko
///    menimpa field yang tidak sedang dikoreksi.
///  * **Alasan wajib**, dan tersimpan sebagai jejak permanen — mengubah nomor
///    rekening agen aktif berarti menggeser ke mana komisi dibayarkan.
class KoreksiAgenScreen extends ConsumerStatefulWidget {
  final AgentModel agent;
  const KoreksiAgenScreen({super.key, required this.agent});

  @override
  ConsumerState<KoreksiAgenScreen> createState() => _KoreksiAgenScreenState();
}

class _KoreksiAgenScreenState extends ConsumerState<KoreksiAgenScreen> {
  final _formKey = GlobalKey<FormState>();

  final _reason = TextEditingController();

  // Satu controller per field yang boleh dikoreksi. `_awal` menyimpan nilai
  // sebelum disunting — itulah pembanding yang menentukan apa yang dikirim.
  late final Map<String, TextEditingController> _c;
  late final Map<String, String> _awal;
  String _gender = '';
  DateTime? _birthDate;

  bool _saving = false;

  RegionRepository get _regionRepo => ref.read(regionRepoProvider);
  AgentRepository get _repo => ref.read(agentRepoProvider);

  /// Label yang dipakai di ringkasan "yang akan berubah". Sengaja disamakan
  /// dengan label yang dicatat server di jejak koreksi, supaya apa yang dibaca
  /// operator sebelum menyimpan sama persis dengan yang muncul di riwayat.
  static const _labels = {
    'name': 'Nama Lengkap',
    'ktpNumber': 'No. KTP',
    'email': 'Email',
    'phone': 'No. Telepon',
    'npwp': 'NPWP',
    'address': 'Alamat',
    'bankName': 'Nama Bank',
    'accountNumber': 'No. Rekening',
    'ktpAddress': 'Alamat KTP',
    'ktpProvince': 'Provinsi (KTP)',
    'ktpCity': 'Kota/Kabupaten (KTP)',
    'ktpDistrict': 'Kecamatan (KTP)',
    'ktpSubdistrict': 'Kelurahan/Desa (KTP)',
    'ktpRt': 'RT (KTP)',
    'ktpRw': 'RW (KTP)',
    'ktpPostalCode': 'Kodepos (KTP)',
    'domicileAddress': 'Alamat Domisili',
    'domicileProvince': 'Provinsi (Domisili)',
    'domicileCity': 'Kota/Kabupaten (Domisili)',
    'domicileDistrict': 'Kecamatan (Domisili)',
    'domicileSubdistrict': 'Kelurahan/Desa (Domisili)',
    'domicileRt': 'RT (Domisili)',
    'domicileRw': 'RW (Domisili)',
    'domicilePostalCode': 'Kodepos (Domisili)',
  };

  @override
  void initState() {
    super.initState();
    final a = widget.agent;
    _awal = {
      'name': a.name,
      'ktpNumber': a.ktpNumber,
      'email': a.email,
      'phone': a.phone,
      'npwp': a.npwp,
      'address': a.address,
      'bankName': a.bankName,
      'accountNumber': a.accountNumber,
      'ktpAddress': a.ktpAddress,
      'ktpProvince': a.ktpProvince,
      'ktpCity': a.ktpCity,
      'ktpDistrict': a.ktpDistrict,
      'ktpSubdistrict': a.ktpSubdistrict,
      'ktpRt': a.ktpRt,
      'ktpRw': a.ktpRw,
      'ktpPostalCode': a.ktpPostalCode,
      'domicileAddress': a.domicileAddress,
      'domicileProvince': a.domicileProvince,
      'domicileCity': a.domicileCity,
      'domicileDistrict': a.domicileDistrict,
      'domicileSubdistrict': a.domicileSubdistrict,
      'domicileRt': a.domicileRt,
      'domicileRw': a.domicileRw,
      'domicilePostalCode': a.domicilePostalCode,
    };
    _c = {
      for (final e in _awal.entries) e.key: TextEditingController(text: e.value)
    };
    // Dropdown alamat (RegionAddressFields) menulis langsung ke controller, bukan
    // lewat onChanged milik layar ini. Tanpa listener, ringkasan "Akan berubah"
    // dan hitungan di tombol Simpan tidak ikut bergerak saat provinsi/kota diganti.
    for (final key in const [
      'ktpProvince', 'ktpCity', 'ktpDistrict', 'ktpSubdistrict', 'ktpPostalCode',
      'domicileProvince', 'domicileCity', 'domicileDistrict',
      'domicileSubdistrict', 'domicilePostalCode',
    ]) {
      _c[key]!.addListener(_onRegionChanged);
    }
    _gender = a.gender;
    _birthDate = a.birthDate.isEmpty ? null : DateTime.tryParse(a.birthDate);
  }

  void _onRegionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _reason.dispose();
    for (final c in _c.values) {
      c.removeListener(_onRegionChanged);
      c.dispose();
    }
    super.dispose();
  }

  String get _birthIso => _birthDate == null
      ? ''
      : '${_birthDate!.year.toString().padLeft(4, '0')}-'
          '${_birthDate!.month.toString().padLeft(2, '0')}-'
          '${_birthDate!.day.toString().padLeft(2, '0')}';

  /// Field yang isinya benar-benar berbeda dari nilai awal — inilah yang dikirim.
  Map<String, String> get _perubahan {
    final out = <String, String>{};
    for (final e in _c.entries) {
      final baru = e.value.text.trim();
      if (baru != (_awal[e.key] ?? '').trim()) out[e.key] = baru;
    }
    if (_gender != widget.agent.gender) out['gender'] = _gender;
    if (_birthIso != widget.agent.birthDate) out['birthDate'] = _birthIso;
    return out;
  }

  String _labelOf(String key) => switch (key) {
        'gender' => 'Jenis Kelamin',
        'birthDate' => 'Tanggal Lahir',
        _ => _labels[key] ?? key,
      };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ubah = _perubahan;
    final messenger = ScaffoldMessenger.of(context);
    if (ubah.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Belum ada data yang diubah.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final setuju = await _konfirmasi(ubah);
    if (setuju != true || !mounted) return;

    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    try {
      await _repo.updateAgentProfile(
        widget.agent.id,
        reason: _reason.text.trim(),
        name: ubah['name'],
        phone: ubah['phone'],
        email: ubah['email'],
        npwp: ubah['npwp'],
        address: ubah['address'],
        bankName: ubah['bankName'],
        accountNumber: ubah['accountNumber'],
        ktpNumber: ubah['ktpNumber'],
        birthDate: ubah['birthDate'],
        gender: ubah['gender'],
        ktpAddress: ubah['ktpAddress'],
        ktpProvince: ubah['ktpProvince'],
        ktpCity: ubah['ktpCity'],
        ktpDistrict: ubah['ktpDistrict'],
        ktpSubdistrict: ubah['ktpSubdistrict'],
        ktpRt: ubah['ktpRt'],
        ktpRw: ubah['ktpRw'],
        ktpPostalCode: ubah['ktpPostalCode'],
        domicileAddress: ubah['domicileAddress'],
        domicileProvince: ubah['domicileProvince'],
        domicileCity: ubah['domicileCity'],
        domicileDistrict: ubah['domicileDistrict'],
        domicileSubdistrict: ubah['domicileSubdistrict'],
        domicileRt: ubah['domicileRt'],
        domicileRw: ubah['domicileRw'],
        domicilePostalCode: ubah['domicilePostalCode'],
      );
      if (!mounted) return;
      navigator.pop(true);
      messenger.showSnackBar(const SnackBar(
        content: Text('Data agen dikoreksi. RM pengaju & agen diberi tahu.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.successGreen,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  /// Konfirmasi yang MENYEBUT field apa saja yang akan berubah. Koreksi data agen
  /// aktif menyentuh hal yang berkonsekuensi uang (rekening komisi), jadi jangan
  /// sampai tersimpan hanya karena satu ketukan tak sengaja.
  Future<bool?> _konfirmasi(Map<String, String> ubah) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Simpan koreksi?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${ubah.length} field akan berubah:',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            ...ubah.keys.map((k) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• ${_labelOf(k)}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                )),
            const SizedBox(height: 12),
            const Text(
              'Perubahan ini tercatat permanen beserta alasannya, dan RM pengaju '
              'serta agen menerima notifikasi.',
              style: TextStyle(fontSize: 12, color: AppColors.grayStage),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ubah = _perubahan;
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: BackAppBar(
        title: 'Koreksi Data Agen',
        actions: [
          IconButton(
            tooltip: 'Riwayat koreksi',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => RiwayatKoreksiAgenScreen(agent: widget.agent),
            )),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _notice(),
              const SizedBox(height: 16),
              _section('Alasan Koreksi', [
                TextFormField(
                  controller: _reason,
                  style: AppInput.fieldText,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: _dec(
                      'Mis. rekening pindah bank sesuai surat agen tertanggal …'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Alasan koreksi wajib diisi'
                      : null,
                ),
              ]),
              const SizedBox(height: 16),
              _section('Data Pribadi', [
                _text('name', 'Nama Lengkap'),
                _text('ktpNumber', 'No. KTP',
                    keyboardType: TextInputType.number),
                _genderField(),
                _birthField(),
                _text('email', 'Email', keyboardType: TextInputType.emailAddress),
                _text('phone', 'No. Telepon', keyboardType: TextInputType.phone),
                _text('npwp', 'NPWP', keyboardType: TextInputType.number),
              ]),
              const SizedBox(height: 16),
              _section('Rekening Komisi', [
                _text('bankName', 'Nama Bank'),
                _text('accountNumber', 'No. Rekening',
                    keyboardType: TextInputType.number),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Mengubah rekening menggeser ke mana komisi agen ini dibayarkan.',
                    style: TextStyle(fontSize: 11, color: AppColors.secondaryOrange),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              _section('Alamat KTP', [
                _text('ktpAddress', 'Alamat KTP'),
                RegionAddressFields(
                  repo: _regionRepo,
                  province: _c['ktpProvince']!,
                  city: _c['ktpCity']!,
                  district: _c['ktpDistrict']!,
                  subdistrict: _c['ktpSubdistrict']!,
                  postalCode: _c['ktpPostalCode'],
                ),
                Row(children: [
                  Expanded(child: _text('ktpRt', 'RT')),
                  const SizedBox(width: 12),
                  Expanded(child: _text('ktpRw', 'RW')),
                ]),
              ]),
              const SizedBox(height: 16),
              _section('Alamat Domisili', [
                _text('domicileAddress', 'Alamat Domisili'),
                RegionAddressFields(
                  repo: _regionRepo,
                  province: _c['domicileProvince']!,
                  city: _c['domicileCity']!,
                  district: _c['domicileDistrict']!,
                  subdistrict: _c['domicileSubdistrict']!,
                  postalCode: _c['domicilePostalCode'],
                ),
                Row(children: [
                  Expanded(child: _text('domicileRt', 'RT')),
                  const SizedBox(width: 12),
                  Expanded(child: _text('domicileRw', 'RW')),
                ]),
              ]),
              const SizedBox(height: 20),
              if (ubah.isNotEmpty) _ringkasan(ubah),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                    shape:
                        RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          ubah.isEmpty
                              ? 'Belum ada perubahan'
                              : 'Simpan Koreksi (${ubah.length} field)',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notice() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.navyBg,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Hanya field yang kamu ubah yang dikirim; sisanya dibiarkan apa adanya. '
          'Jenis agen, kantor, status, lisensi, PKS, dan CIF tidak dikoreksi di '
          'sini — masing-masing punya alurnya sendiri.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      );

  Widget _ringkasan(Map<String, String> ubah) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(color: AppColors.secondaryOrange),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Akan berubah',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final k in ubah.keys)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.navyBg,
                      borderRadius: AppRadius.radiusSm,
                    ),
                    child: Text(_labelOf(k),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _section(String title, List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.border),
          boxShadow: const [AppShadows.level1],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );

  Widget _text(String key, String label, {TextInputType? keyboardType}) {
    final berubah = _c[key]!.text.trim() != (_awal[key] ?? '').trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fieldLabel(label),
          const SizedBox(height: 6),
          TextFormField(
            controller: _c[key],
            style: AppInput.fieldText,
            keyboardType: keyboardType,
            // Menandai field yang berbeda dari nilai tersimpan, supaya operator
            // bisa melihat sekilas apa saja yang akan ikut terkirim.
            decoration: _dec(label).copyWith(
              suffixIcon: berubah
                  ? const Icon(Icons.edit, size: 16, color: AppColors.secondaryOrange)
                  : null,
            ),
            validator: key == 'name'
                ? (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama tidak boleh dikosongkan'
                    : null
                : null,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _genderField() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            fieldLabel('Jenis Kelamin'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: const ['Laki-laki', 'Perempuan'].contains(_gender)
                  ? _gender
                  : null,
              style: AppInput.fieldText,
              isExpanded: true,
              hint: const Text('Pilih jenis kelamin',
                  style: TextStyle(color: AppColors.grayStage, fontSize: 14)),
              items: const ['Laki-laki', 'Perempuan']
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _gender = v ?? ''),
              decoration: _dec('Jenis Kelamin'),
            ),
          ],
        ),
      );

  Widget _birthField() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            fieldLabel('Tanggal Lahir'),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: AppRadius.radiusMd,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _birthDate ?? DateTime(1990),
                  firstDate: DateTime(1940),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _birthDate = picked);
              },
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: AppRadius.radiusMd,
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(_birthIso.isEmpty ? 'Pilih tanggal' : _birthIso,
                    style: TextStyle(
                        fontSize: 14,
                        color: _birthIso.isEmpty
                            ? AppColors.grayStage
                            : AppColors.textPrimary)),
              ),
            ),
          ],
        ),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surfaceWhite,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: const BorderSide(color: AppColors.primaryNavy, width: 1.5),
        ),
      );
}

/// Riwayat koreksi profil satu agen (GET /api/agents/{id}/profile-changes).
///
/// Yang ditampilkan: siapa, kapan, alasan, dan NAMA field yang berubah. Nilai
/// lama/barunya memang tidak ada — server sengaja tidak menyimpannya karena PII
/// (NIK, NPWP, no. rekening). Catatan itu ditulis di layar supaya pembacanya
/// tidak mengira datanya hilang.
class RiwayatKoreksiAgenScreen extends ConsumerStatefulWidget {
  final AgentModel agent;
  const RiwayatKoreksiAgenScreen({super.key, required this.agent});

  @override
  ConsumerState<RiwayatKoreksiAgenScreen> createState() =>
      _RiwayatKoreksiAgenScreenState();
}

class _RiwayatKoreksiAgenScreenState
    extends ConsumerState<RiwayatKoreksiAgenScreen> {
  late Future<List<AgentProfileChangeModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(agentRepoProvider).getProfileChanges(widget.agent.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: const BackAppBar(title: 'Riwayat Koreksi'),
      body: SafeArea(
        child: FutureBuilder<List<AgentProfileChangeModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _pesan(snap.error
                  .toString()
                  .replaceAll('Exception: ', ''));
            }
            final items = snap.data ?? const <AgentProfileChangeModel>[];
            if (items.isEmpty) {
              return _pesan('Belum ada koreksi data untuk agen ini.');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (i == items.length) return _catatanPii();
                return _kartu(items[i]);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _kartu(AgentProfileChangeModel c) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(c.changedByName,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
                Text(_tanggal(c.changedAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.grayStage)),
              ],
            ),
            const SizedBox(height: 8),
            Text(c.reason,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in c.fields)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.navyBg,
                      borderRadius: AppRadius.radiusSm,
                    ),
                    child: Text(f,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _catatanPii() => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: const Text(
          'Riwayat mencatat field apa yang berubah, bukan nilai lama & barunya — '
          'nilai itu berisi data pribadi (NIK, NPWP, no. rekening) dan sengaja '
          'tidak disalin ke luar data agen.',
          style: TextStyle(fontSize: 11, color: AppColors.grayStage),
        ),
      );

  /// `changedAt` datang sebagai ISO UTC dari server; tampilkan tanggal + jam saja.
  String _tanggal(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final l = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  Widget _pesan(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ),
      );
}
