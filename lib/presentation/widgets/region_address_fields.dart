import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../src/region/region_repository.dart';
import 'field_label.dart';

/// Empat dropdown alamat berjenjang (provinsi → kota/kabupaten → kecamatan →
/// kelurahan) yang menarik data dari [RegionRepository] (proxy API wilayah).
///
/// Sumber kebenaran untuk SUBMIT tetap keempat controller teks yang dioper —
/// menyimpan NAMA, sesuai skema Agent yang bebas-teks. Memilih dropdown menulis
/// nama terpilih ke controller & mereset level di bawahnya. Di mode edit,
/// controller sudah berisi nama tersimpan tapi dropdown mulai kosong: nilai lama
/// tetap tampil sebagai "Tersimpan: …" dan tetap ikut submit bila tak diubah.
class RegionAddressFields extends StatefulWidget {
  final RegionRepository repo;
  final TextEditingController province;
  final TextEditingController city;
  final TextEditingController district;
  final TextEditingController subdistrict;

  /// Bila diisi, field Kode Pos ditampilkan & di-autofill saat kelurahan dipilih.
  final TextEditingController? postalCode;

  /// Bila true: label diberi tanda "*" merah dan tiap level divalidasi wajib
  /// (validasi berdasar isi controller, sehingga nilai tersimpan mode edit lolos).
  final bool required;

  const RegionAddressFields({
    super.key,
    required this.repo,
    required this.province,
    required this.city,
    required this.district,
    required this.subdistrict,
    this.postalCode,
    this.required = false,
  });

  @override
  State<RegionAddressFields> createState() => _RegionAddressFieldsState();
}

class _RegionAddressFieldsState extends State<RegionAddressFields> {
  List<RegionOption> _prov = const [];
  List<RegionOption> _city = const [];
  List<RegionOption> _dist = const [];
  List<RegionOption> _vill = const [];

  String? _provId, _cityId, _distId, _villId;
  bool _loadingProv = false, _loadingCity = false, _loadingDist = false, _loadingVill = false;
  bool _loadingPos = false;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  Future<void> _loadProvinces() async {
    setState(() => _loadingProv = true);
    try {
      final list = await widget.repo.provinces();
      if (mounted) setState(() => _prov = list);
    } catch (_) {
      // Biarkan kosong bila sumber tak tersedia; nilai tersimpan tetap terkirim.
    } finally {
      if (mounted) setState(() => _loadingProv = false);
    }
  }

  Future<void> _onProv(RegionOption? o) async {
    if (o == null) return;
    setState(() {
      _provId = o.id;
      widget.province.text = o.name;
      _cityId = _distId = _villId = null;
      _city = _dist = _vill = const [];
      widget.city.clear();
      widget.district.clear();
      widget.subdistrict.clear();
      _loadingCity = true;
    });
    try {
      final list = await widget.repo.regencies(o.id);
      if (mounted) setState(() => _city = list);
    } catch (_) {
      // abaikan; dropdown anak tinggal kosong
    } finally {
      if (mounted) setState(() => _loadingCity = false);
    }
  }

  Future<void> _onCity(RegionOption? o) async {
    if (o == null) return;
    setState(() {
      _cityId = o.id;
      widget.city.text = o.name;
      _distId = _villId = null;
      _dist = _vill = const [];
      widget.district.clear();
      widget.subdistrict.clear();
      _loadingDist = true;
    });
    try {
      final list = await widget.repo.districts(o.id);
      if (mounted) setState(() => _dist = list);
    } catch (_) {
      // abaikan
    } finally {
      if (mounted) setState(() => _loadingDist = false);
    }
  }

  Future<void> _onDist(RegionOption? o) async {
    if (o == null) return;
    setState(() {
      _distId = o.id;
      widget.district.text = o.name;
      _villId = null;
      _vill = const [];
      widget.subdistrict.clear();
      _loadingVill = true;
    });
    try {
      final list = await widget.repo.villages(o.id);
      if (mounted) setState(() => _vill = list);
    } catch (_) {
      // abaikan
    } finally {
      if (mounted) setState(() => _loadingVill = false);
    }
  }

  Future<void> _onVill(RegionOption? o) async {
    if (o == null) return;
    setState(() {
      _villId = o.id;
      widget.subdistrict.text = o.name;
      _loadingPos = widget.postalCode != null;
    });
    if (widget.postalCode == null) return;
    try {
      // Autofill kodepos dari nama kelurahan (disambiguasi kecamatan + kota).
      final code = await widget.repo.postalCode(o.name,
          district: widget.district.text, regency: widget.city.text);
      if (mounted && code != null && code.isNotEmpty) {
        widget.postalCode!.text = code;
      }
    } catch (_) {
      // biarkan manual bila lookup gagal
    } finally {
      if (mounted) setState(() => _loadingPos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dropdown('Provinsi', _prov, _provId, widget.province, _onProv,
            enabled: true, loading: _loadingProv),
        const SizedBox(height: 12),
        _dropdown('Kota / Kabupaten', _city, _cityId, widget.city, _onCity,
            enabled: _provId != null, loading: _loadingCity),
        const SizedBox(height: 12),
        _dropdown('Kecamatan', _dist, _distId, widget.district, _onDist,
            enabled: _cityId != null, loading: _loadingDist),
        const SizedBox(height: 12),
        _dropdown('Kelurahan / Desa', _vill, _villId, widget.subdistrict, _onVill,
            enabled: _distId != null, loading: _loadingVill),
        if (widget.postalCode != null) ...[
          const SizedBox(height: 12),
          fieldLabel(widget.required ? 'Kode Pos *' : 'Kode Pos'),
          const SizedBox(height: 6),
          TextFormField(
            controller: widget.postalCode,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5),
            ],
            validator: widget.required
                ? (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null
                : null,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: _decoration().copyWith(
              hintText: _loadingPos ? 'Mengambil kode pos…' : 'mis. 40123',
              hintStyle: const TextStyle(color: AppColors.grayStage, fontSize: 14),
              suffixIcon: _loadingPos
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                  : null,
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Terisi otomatis dari kelurahan — bisa diedit manual.',
                style: TextStyle(fontSize: 11, color: AppColors.grayStage)),
          ),
        ],
      ],
    );
  }

  Widget _dropdown(String label, List<RegionOption> options, String? selectedId,
      TextEditingController controller, ValueChanged<RegionOption?> onChanged,
      {required bool enabled, required bool loading}) {
    final stored = controller.text.trim();
    final showStored = selectedId == null && stored.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        fieldLabel(widget.required ? '$label *' : label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: selectedId,
          isExpanded: true,
          // Validasi berdasar isi controller (nama), bukan id dropdown — supaya
          // nilai tersimpan (mode edit) tetap dianggap terisi.
          validator: widget.required
              ? (_) => controller.text.trim().isEmpty ? 'Wajib dipilih' : null
              : null,
          hint: Text(
            loading ? 'Memuat…' : (enabled ? 'Pilih $label' : 'Pilih level di atas dulu'),
            style: const TextStyle(color: AppColors.grayStage, fontSize: 14),
          ),
          items: [
            for (final o in options)
              DropdownMenuItem<String>(
                value: o.id,
                child: Text(o.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (enabled && !loading)
              ? (id) {
                  RegionOption? sel;
                  for (final o in options) {
                    if (o.id == id) {
                      sel = o;
                      break;
                    }
                  }
                  onChanged(sel);
                }
              : null,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.grayStage),
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: _decoration(),
        ),
        if (showStored)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Tersimpan: $stored',
                style: const TextStyle(fontSize: 11, color: AppColors.grayStage)),
          ),
      ],
    );
  }

  InputDecoration _decoration() {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: AppRadius.radiusMd, borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      filled: true,
      fillColor: AppColors.bgScreen,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: b(AppColors.border),
      focusedBorder: b(AppColors.primaryNavy, 1.5),
      disabledBorder: b(AppColors.border),
      errorBorder: b(AppColors.errorRed),
      focusedErrorBorder: b(AppColors.errorRed, 1.5),
      errorStyle: const TextStyle(fontSize: 12, color: AppColors.errorRed),
    );
  }
}
