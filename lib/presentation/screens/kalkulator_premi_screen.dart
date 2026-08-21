import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:printing/printing.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/input_formatters.dart';
import '../../data/premi_rates.dart';
import '../../src/app.dart';
import '../../src/network/api_client.dart';
import '../../src/customer/customer_repository.dart';
import '../../src/premi/premi_estimate_repository.dart';
import '../../src/premi/premi_rate_repository.dart';
import '../../src/pdf/premi_invoice_pdf.dart';
import '../providers/kalkulator_premi_provider.dart';
import '../widgets/back_app_bar.dart';
import '../widgets/state_views.dart';
import '../widgets/kalkulator_premi/premi_result_card.dart';

/// S-109 — Kalkulator Premi. Real-time, client-only computation.
///
/// Flow (calc.md): pilih kategori → pilih jenis produk → rate terisi dari default
/// admin dan masih bisa diketik ulang → khusus Asuransi Umum bisa isi diskon →
/// premi = TSI × rate, dikali (1 − diskon) bila ada diskon.
///
/// Rate (MTR-2): ADMIN mengisi rate default per slot pilihan lewat layar ini juga,
/// tersimpan di backend (`/api/premi-rates`). Pengguna kalkulator menerimanya sebagai
/// angka AWAL begitu pilihannya lengkap, dan boleh menimpanya — timpaan itu hanya
/// berlaku untuk perhitungan yang sedang berjalan dan TIDAK disimpan ke mana pun.
/// Slot yang belum diisi admin berperilaku seperti sebelum MTR-2: isian kosong, user
/// mengetik sendiri. Angka rate tetap tidak pernah ditulis di dalam kode aplikasi.
///
/// - Contractor's All Risk & Machinery Breakdown (Industry) memunculkan 3
///   kriteria (CAR-MB.png) hanya untuk label tier (High/Low/Normal Risk),
///   bukan untuk menentukan rate — rate tetap diisi manual.
/// - Surety Bond & KBG: pilih jenis jaminan × tenor. Custom Bond: pilih tenor.
///   Ketiganya kena minimum premi Rp25.000.
/// - Mata uang non-IDR dikonversi ke IDR memakai kurs indikatif ECB
///   (ExchangeRateService, pola sama seperti add_pipeline) — kurs bisa diedit.
class KalkulatorPremiScreen extends ConsumerStatefulWidget {
  const KalkulatorPremiScreen({super.key});

  @override
  ConsumerState<KalkulatorPremiScreen> createState() =>
      _KalkulatorPremiScreenState();
}

class _KalkulatorPremiScreenState extends ConsumerState<KalkulatorPremiScreen> {
  PremiCategory _category = PremiCategory.asuransiUmum;

  // Asuransi Umum selection.
  UmumProduct? _product;
  final Set<int> _checkedCriteria = {};

  // Bond selection (surety/kbg use jaminan; all bonds use tenor).
  int? _jaminanIdx;
  int? _tenorIdx;

  final TextEditingController _tsiController = TextEditingController();
  final TextEditingController _diskonController = TextEditingController(
    text: '0',
  );

  /// Biaya admin NOMINAL (rupiah) di luar premi (CR-21). Bukan persentase: ia
  /// tidak ikut dasar perhitungan premi maupun aturan minimum premi bond, hanya
  /// menambah total yang ditagihkan. Kosong/0 = perilaku lama persis.
  final TextEditingController _biayaAdminController = TextEditingController();

  /// Rate (%) is entered manually by the user — takedown of internal rate
  /// data means the app no longer auto-fills or stores it.
  final TextEditingController _rateController = TextEditingController();

  // Currency / FX — same approach as add_pipeline (indicative ECB rate, editable).
  static const List<String> _currencyOptions = [
    'IDR',
    'USD',
    'EUR',
    'SGD',
    'CNY',
    'MYR',
    'KRW',
    'AUD',
  ];
  String _currency = 'IDR';
  final TextEditingController _kursController = TextEditingController(
    text: '1',
  );

  // Flag loading kurs dipindah ke KalkulatorPremiNotifier (satu-satunya state
  // async layar ini). Diproksikan lewat getter agar kode build tetap sama.
  bool get _kursLoading => ref.read(kalkulatorPremiProvider).kursLoading;

  @override
  void initState() {
    super.initState();
    _kursController.addListener(() => setState(() {}));
    // Rate default milik admin dimuat sekali di sini, bukan per pilihan produk:
    // daftarnya kecil dan kalkulator jadi tidak menunggu jaringan tiap ganti pilihan.
    // Sesudah frame pertama karena butuh context (sesi) dan tidak boleh mengubah
    // state provider saat build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRateDefaults());
  }

  Future<void> _loadRateDefaults() async {
    if (!mounted) return;
    final repo = PremiRateRepository(
      apiClient: ApiClient(session: MbisApp.of(context)?.session),
    );
    await ref.read(kalkulatorPremiProvider.notifier).loadRateDefaults(repo);
    if (!mounted) return;
    // Hanya mengisi yang MASIH kosong: bila user sempat mengetik rate selagi
    // daftar dimuat, ketikannya tidak boleh tertimpa default yang baru datang.
    setState(() => _applyDefaultRate(onlyIfEmpty: true));
  }

  @override
  void dispose() {
    _tsiController.dispose();
    _diskonController.dispose();
    _biayaAdminController.dispose();
    _rateController.dispose();
    _kursController.dispose();
    super.dispose();
  }

  // ── derived values ─────────────────────────────────────────────────────────

  num get _tsiOriginal =>
      num.tryParse(_tsiController.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
  double get _kurs => double.tryParse(_kursController.text) ?? 1;
  num get _tsiIdr => _tsiOriginal * _kurs;
  num get _diskon => _category.allowsDiscount
      ? (num.tryParse(_diskonController.text) ?? 0)
      : 0;

  /// True when the product/jaminan/tenor selection for the current category
  /// is complete enough to enable manual rate entry.
  bool get _selectionComplete {
    switch (_category) {
      case PremiCategory.asuransiUmum:
        return _product != null;
      case PremiCategory.suretyBond:
      case PremiCategory.kbg:
        return _tenorIdx != null && _jaminanIdx != null;
      case PremiCategory.customBond:
        return _tenorIdx != null;
    }
  }

  /// Rate in percent, entered manually by the user (rate data is internal-
  /// company confidential and is no longer auto-filled/stored by the app).
  /// Null when the selection is incomplete or the field is empty.
  double? get _rate {
    if (!_selectionComplete) return null;
    return double.tryParse(_rateController.text);
  }

  // ── Rate default milik admin (MTR-2) ───────────────────────────────────────

  /// True bila pemakai layar ini ADMIN — satu-satunya peran yang boleh MENYIMPAN
  /// rate default. Gerbang di klien ini hanya menghindarkan pintu yang pasti
  /// tertutup; yang menentukan tetap server (`/api/admin/premi-rates` → 403).
  bool get _isAdmin =>
      (MbisApp.of(context)?.session?.user.roles ?? const <String>[]).contains(
        'ADMIN',
      );

  /// Kunci slot rate untuk pilihan saat ini; null bila pilihan belum lengkap.
  /// Untuk CAR & MB Industry kuncinya ikut berubah saat kriteria risiko dicentang
  /// — tier yang berbeda memang rate yang berbeda.
  String? get _slotKey {
    if (!_selectionComplete) return null;
    switch (_category) {
      case PremiCategory.asuransiUmum:
        final risk = _product!.risk;
        return premiSlotKeyUmum(
          _product!.name,
          riskTier: risk?.tierCode(_checkedCriteria.length),
        );
      case PremiCategory.suretyBond:
      case PremiCategory.kbg:
        return premiSlotKeyBond(
          _category,
          jaminan: kBondJaminan[_jaminanIdx!],
          tenor: kBondTenors[_tenorIdx!],
        );
      case PremiCategory.customBond:
        return premiSlotKeyBond(_category, tenor: kBondTenors[_tenorIdx!]);
    }
  }

  /// Rate default untuk slot terpilih; null bila belum diisi admin.
  PremiRateDefault? get _slotDefault {
    final key = _slotKey;
    if (key == null) return null;
    return ref.read(kalkulatorPremiProvider).defaultFor(key);
  }

  /// True bila isian rate sudah berbeda dari default admin — dipakai untuk
  /// menyatakan dengan jelas bahwa angka yang tampil bukan lagi angka acuan.
  bool get _rateOverridden {
    final def = _slotDefault;
    if (def == null) return false;
    return _rateController.text.trim() != _rateText(def.ratePercent);
  }

  /// Batas bawah rate untuk slot terpilih; null bila slot tanpa batas bawah.
  double? get _minRate => _slotDefault?.minRatePercent;

  /// True bila rate yang diketik ada DI BAWAH batas bawah slot. Ini kondisi
  /// terlarang, bukan sekadar peringatan: dokumen proforma tidak boleh terbit dengan
  /// rate di bawah batas, dan server pun menolaknya saat Estimasi Premi disimpan.
  bool get _belowMinRate => _slotDefault?.melanggarBatasBawah(_rate) ?? false;

  /// Rate persen untuk isian/label: buang nol berekor (3.5000 → "3.5").
  String _rateText(double v) {
    var s = v.toStringAsFixed(4);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  /// Tulis rate default slot terpilih ke isian rate; kosongkan bila slot belum
  /// lengkap atau belum punya default.
  ///
  /// TIDAK memanggil setState — semua pemanggilnya sudah berada di dalam setState
  /// milik perubahan pilihan yang memicunya. [onlyIfEmpty] dipakai saat daftar rate
  /// baru selesai dimuat, agar ketikan user yang sedang berjalan tidak tertimpa.
  void _applyDefaultRate({bool onlyIfEmpty = false}) {
    if (onlyIfEmpty && _rateController.text.trim().isNotEmpty) return;
    final def = _slotDefault;
    _rateController.text = def == null ? '' : _rateText(def.ratePercent);
  }

  /// Label slot untuk dialog konfirmasi admin — sebutkan persis apa yang diubah.
  String get _slotLabel {
    final tier = _riskTier;
    switch (_category) {
      case PremiCategory.asuransiUmum:
        return tier == null ? _breakdownToc : '$_breakdownToc · $tier';
      case PremiCategory.suretyBond:
      case PremiCategory.kbg:
        return '${_category.label} · ${kBondJaminan[_jaminanIdx!]} · '
            '${kBondTenors[_tenorIdx!]}';
      case PremiCategory.customBond:
        return '${_category.label} · ${kBondTenors[_tenorIdx!]}';
    }
  }

  bool get _isBond => _category != PremiCategory.asuransiUmum;

  /// Premi bruto (sebelum minimum premi bond), dalam IDR.
  num get _premiBruto {
    final rate = _rate;
    if (rate == null) return 0;
    var premi = _tsiIdr * (rate / 100);
    if (_category.allowsDiscount) premi *= (1 - _diskon / 100);
    return premi;
  }

  /// Premi final: bond dikenai minimum Rp25.000 bila hasil > 0.
  num get _premi {
    final premi = _premiBruto;
    if (_isBond && premi > 0 && premi < kBondMinPremi) return kBondMinPremi;
    return premi;
  }

  bool get _minPremiApplied =>
      _isBond && _premiBruto > 0 && _premiBruto < kBondMinPremi;

  /// Biaya admin yang diketik (rupiah, tanpa pemisah ribuan). Dibaca sama seperti
  /// TSI: karakter non-angka dibuang, supaya "25.000" yang diketik user tidak
  /// diam-diam terbaca 25.
  num get _biayaAdmin =>
      num.tryParse(
        _biayaAdminController.text.replaceAll(RegExp(r'[^\d]'), ''),
      ) ??
      0;

  /// Yang benar-benar ditagihkan ke nasabah: premi + biaya admin (CR-21).
  /// Sengaja dihitung DI ATAS [_premi] yang sudah final, bukan di dalamnya —
  /// aturan minimum premi bond hanya berlaku untuk preminya sendiri.
  num get _totalTagihan => _premi + _biayaAdmin;

  /// True when the current selection is complete enough to compute a premi.
  /// Rate di bawah batas bawah slot menutup ekspor — dokumen yang terbit di bawah
  /// batas sudah terlanjur sampai ke nasabah, jadi dicegat sebelum PDF dibuat.
  bool get _canExport => _rate != null && _tsiOriginal > 0 && !_belowMinRate;

  // Product breakdown for the invoice (COB → LOB → ToC seperti pipeline).
  String get _breakdownCob => _category == PremiCategory.asuransiUmum
      ? kCobAsuransiUmum
      : kCobSuretyship;

  String get _breakdownLob => _category == PremiCategory.asuransiUmum
      ? (_product?.lob ?? '-')
      : bondLob(_category);

  String get _breakdownToc {
    switch (_category) {
      case PremiCategory.asuransiUmum:
        return _product?.name ?? '-';
      case PremiCategory.suretyBond:
      case PremiCategory.kbg:
        return _jaminanIdx != null ? kBondJaminan[_jaminanIdx!] : '-';
      case PremiCategory.customBond:
        return 'All Jaminan';
    }
  }

  String? get _riskTier {
    final r = _product?.risk;
    return (_category == PremiCategory.asuransiUmum && r != null)
        ? r.tierLabel(_checkedCriteria.length)
        : null;
  }

  void _toggleCriterion(int i) {
    setState(() {
      if (!_checkedCriteria.add(i)) _checkedCriteria.remove(i);
      // Kriteria menentukan tier (High/Low/Normal), dan tier ikut membentuk kunci
      // slot — jadi mencentang kriteria berarti pindah ke rate default yang lain.
      _applyDefaultRate();
    });
  }

  // ── actions ────────────────────────────────────────────────────────────────

  void _onCategoryChanged(PremiCategory c) {
    setState(() {
      _category = c;
      _product = null;
      _checkedCriteria.clear();
      _jaminanIdx = null;
      _tenorIdx = null;
      _diskonController.text =
          '0'; // fix: reset diskon when leaving Asuransi Umum
      _applyDefaultRate();
    });
  }

  void _onTsiChanged(String v) => _formatRupiahField(_tsiController, v);

  /// Biaya admin memakai pemformat yang sama dengan TSI (CR-21): dua isian rupiah
  /// di satu layar yang berbeda cara ketiknya hanya bikin salah baca.
  void _onBiayaAdminChanged(String v) =>
      _formatRupiahField(_biayaAdminController, v);

  /// Menulis ulang isi [c] sebagai angka berpemisah ribuan sambil menjaga kursor
  /// tetap di ujung.
  void _formatRupiahField(TextEditingController c, String v) {
    final digits = v.replaceAll(RegExp(r'[^\d]'), '');
    final formatted = digits.isEmpty
        ? ''
        : AppFormat.thousands(int.parse(digits));
    c.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setState(() {});
  }

  /// Switches currency and auto-fills an indicative kurs (editable) for non-IDR —
  /// same approach as add_pipeline (ECB reference, manual override allowed).
  ///
  /// Mata uang terpilih (`_currency`) & penulisan kurs (`_kursController`) TETAP
  /// di widget; hanya flag loading + panggilan FX yang lewat notifier.
  Future<void> _onCurrencyChanged(String cur) async {
    final notifier = ref.read(kalkulatorPremiProvider.notifier);
    if (cur == 'IDR') {
      setState(() {
        _currency = cur;
        _kursController.text = '1';
      });
      notifier.setKursLoading(false);
      return;
    }
    // setState (currency) + loadKursToIdr (loading=true) berjalan sinkron sebelum
    // await pertama → dibatch Flutter jadi satu frame, sama seperti setState lama.
    setState(() => _currency = cur);
    final rate = await notifier.loadKursToIdr(cur);
    if (!mounted || _currency != cur) return;
    notifier.setKursLoading(false);
    setState(() {
      if (rate != null) {
        _kursController.text = rate == rate.roundToDouble()
            ? rate.toStringAsFixed(0)
            : rate.toStringAsFixed(2);
      }
    });
  }

  Future<void> _pickProduct() async {
    final selected = await showModalBottomSheet<UmumProduct>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ProductPickerSheet(selected: _product),
    );
    if (selected != null) {
      setState(() {
        _product = selected;
        _checkedCriteria.clear();
        _applyDefaultRate();
      });
    }
  }

  /// Pick a customer from this RM's list, then render & preview the proforma PDF.
  Future<void> _exportPdf() async {
    if (!_canExport) {
      _snack(
        _belowMinRate
            ? 'Rate di bawah batas bawah ${_rateText(_minRate!)}%. '
                  'Naikkan rate dulu sebelum ekspor.'
            : 'Lengkapi produk & TSI dulu sebelum ekspor.',
      );
      return;
    }
    final session = MbisApp.of(context)?.session;
    final apiClient = ApiClient(session: session);
    final customer = await showModalBottomSheet<CustomerListModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) =>
          _CustomerPickerSheet(repo: CustomerRepository(apiClient: apiClient)),
    );
    if (customer == null || !mounted) return;

    // 1) Issue the numbered record on the backend (returns doc number + office).
    final estRepo = PremiEstimateRepository(apiClient: apiClient);
    final PremiEstimateResult issued;
    try {
      issued = await estRepo.create({
        'customerId': customer.id,
        'customerName': customer.name,
        'customerCategory': customer.entityCategory,
        'category': _category.name,
        'cob': _breakdownCob,
        'lob': _breakdownLob,
        'toc': _breakdownToc,
        'riskTier': _riskTier,
        'currency': _currency,
        'tsiOriginal': _tsiOriginal,
        'kurs': _kurs,
        'tsiIdr': _tsiIdr,
        'ratePercent': _rate!,
        // Slot dikirim agar server bisa memvalidasi rate terhadap batas bawahnya
        // sendiri — gerbang layar saja bisa dilewati klien yang dimodifikasi.
        'slotKey': _slotKey,
        'diskonPercent': _diskon,
        'minPremiApplied': _minPremiApplied,
        'premi': _premi,
        // Disimpan terpisah dari premi (CR-21): dokumen yang terbit harus bisa
        // menjelaskan kembali angka totalnya, bukan hanya menampilkan hasil akhir.
        'biayaAdmin': _biayaAdmin,
      });
    } catch (e) {
      if (mounted) _snack('Gagal menerbitkan nomor dokumen: ${_clean(e)}');
      return;
    }

    // 2) Render the PDF with the issued number + office identity.
    final data = PremiInvoiceData(
      invoiceNo: issued.docNumber,
      date: issued.createdAt,
      rmName: issued.rmName,
      rmNip: issued.rmNip,
      officeBranchName: issued.officeBranchName,
      officeRegionalName: issued.officeRegionalName,
      customerName: customer.name,
      customerCategory: customer.entityCategory,
      cob: _breakdownCob,
      lob: _breakdownLob,
      toc: _breakdownToc,
      riskTier: _riskTier,
      currency: _currency,
      tsiOriginal: _tsiOriginal,
      kurs: _kurs,
      tsiIdr: _tsiIdr,
      ratePercent: _rate!,
      diskonPercent: _diskon,
      minPremiApplied: _minPremiApplied,
      premi: _premi,
      biayaAdmin: _biayaAdmin,
    );

    Uint8List bytes;
    try {
      bytes = await buildPremiInvoicePdf(data);
    } catch (e) {
      if (mounted) _snack('Gagal membuat PDF: ${_clean(e)}');
      return;
    }

    // 3) Store the PDF (gzip-compressed) on the backend — non-fatal if it fails.
    try {
      await estRepo.uploadPdf(issued.id, bytes);
    } catch (e) {
      if (mounted) _snack('PDF dibuat, gagal disimpan ke server: ${_clean(e)}');
    }

    // 4) Preview / print / share the same bytes. Lock the layout to a fixed A4 page:
    // dynamicLayout=false + a fixed format stop the print dialog from re-flowing/scaling the
    // document to a different paper size — the user prints exactly what was generated.
    await Printing.layoutPdf(
      name: '${issued.docNumber.replaceAll('/', '-')}.pdf',
      format: PdfPageFormat.a4,
      dynamicLayout: false,
      onLayout: (_) => bytes,
    );
  }

  String _clean(Object e) => e.toString().replaceAll('Exception: ', '');

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.watch(
      kalkulatorPremiProvider,
    ); // rebuild saat flag loading kurs berubah
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: const BackAppBar(title: 'Kalkulator Premi'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _buildInputCard(),
              const SizedBox(height: AppSpacing.lg),
              PremiResultCard(
                category: _category,
                rate: _rate,
                diskon: _diskon,
                currency: _currency,
                tsiOriginal: _tsiOriginal,
                tsiIdr: _tsiIdr,
                minPremiApplied: _minPremiApplied,
                premi: _premi,
                biayaAdmin: _biayaAdmin,
                totalTagihan: _totalTagihan,
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildExportButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _canExport ? _exportPdf : null,
        icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
        label: const Text(
          'Ekspor PDF (Proforma Invoice)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryNavy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.grayBg,
          disabledForegroundColor: AppColors.grayStage,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Parameter Perhitungan'),
          const SizedBox(height: 16),
          _fieldLabel('Kategori'),
          const SizedBox(height: 8),
          _buildCategoryChips(),
          const SizedBox(height: 18),
          ..._buildCategoryFields(),
          const SizedBox(height: 18),
          _buildTsiSection(),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _labeled('Rate (%)', _buildRateField())),
              const SizedBox(width: 14),
              Expanded(child: _labeled('Diskon (%)', _buildDiskonField())),
            ],
          ),
          ..._buildRateDefaultSection(),
          const SizedBox(height: 18),
          // Biaya admin (CR-21) berdiri sendiri, tidak di baris yang sama dengan
          // Rate/Diskon: keduanya persen, yang ini rupiah — disandingkan malah
          // mengundang salah isi.
          _labeled('Biaya Admin (Rp)', _buildBiayaAdminField()),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: PremiCategory.values.map((c) {
        final selected = _category == c;
        return ChoiceChip(
          label: Text(c.label),
          selected: selected,
          onSelected: (_) => _onCategoryChanged(c),
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
          backgroundColor: AppColors.surfaceWhite,
          selectedColor: AppColors.primaryNavy,
          side: BorderSide(
            color: selected ? AppColors.primaryNavy : AppColors.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }).toList(),
    );
  }

  /// The category-specific selectors (product / jaminan / tenor / criteria).
  List<Widget> _buildCategoryFields() {
    switch (_category) {
      case PremiCategory.asuransiUmum:
        return [
          _labeled('Jenis Produk', _buildProductSelector()),
          if (_product?.risk != null) ...[
            const SizedBox(height: 14),
            _buildCriteria(_product!.risk!),
          ],
        ];
      case PremiCategory.suretyBond:
      case PremiCategory.kbg:
        return [
          _labeled(
            'Jenis Jaminan',
            _buildIndexDropdown(
              hint: 'Pilih jaminan',
              items: kBondJaminan,
              value: _jaminanIdx,
              onChanged: (i) => setState(() {
                _jaminanIdx = i;
                _applyDefaultRate();
              }),
            ),
          ),
          const SizedBox(height: 14),
          _labeled(
            'Tenor / Durasi',
            _buildIndexDropdown(
              hint: 'Pilih tenor',
              items: kBondTenors,
              value: _tenorIdx,
              onChanged: (i) => setState(() {
                _tenorIdx = i;
                _applyDefaultRate();
              }),
            ),
          ),
        ];
      case PremiCategory.customBond:
        return [
          _labeled(
            'Tenor / Durasi',
            _buildIndexDropdown(
              hint: 'Pilih tenor',
              items: kBondTenors,
              value: _tenorIdx,
              onChanged: (i) => setState(() {
                _tenorIdx = i;
                _applyDefaultRate();
              }),
            ),
          ),
        ];
    }
  }

  /// Tappable field that opens the searchable product picker. No "--" prompt.
  Widget _buildProductSelector() {
    final has = _product != null;
    return InkWell(
      borderRadius: AppRadius.radiusMd,
      onTap: _pickProduct,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                has ? _product!.name : 'Pilih produk',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: has ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
            const Icon(Icons.search, size: 20, color: AppColors.grayStage),
          ],
        ),
      ),
    );
  }

  Widget _buildIndexDropdown({
    required String hint,
    required List<String> items,
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    return _dropdownShell(
      child: DropdownButton<int>(
        value: value,
        isExpanded: true,
        hint: Text(
          hint,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.grayStage),
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        items: [
          for (var i = 0; i < items.length; i++)
            DropdownMenuItem(value: i, child: Text(items[i])),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildCriteria(RiskModel risk) {
    final n = _checkedCriteria.length;
    final tier = risk.tierLabel(n);
    final tierColor = n >= 2
        ? AppColors.errorRed
        : (n == 0 && risk.hasNormalTier)
        ? AppColors.textSecondary
        : AppColors.secondaryOrange;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.bgScreen,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kriteria Risiko',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  tier,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: tierColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < risk.criteria.length; i++)
            InkWell(
              borderRadius: AppRadius.radiusSm,
              onTap: () => _toggleCriterion(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: _checkedCriteria.contains(i),
                        onChanged: (_) => _toggleCriterion(i),
                        activeColor: AppColors.primaryNavy,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        risk.criteria[i],
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            risk.hasNormalTier
                ? '≥2 kriteria → High · 1 → Low · 0 → Normal'
                : '≥2 kriteria → High · <2 → Low',
            style: const TextStyle(fontSize: 10.5, color: AppColors.grayStage),
          ),
        ],
      ),
    );
  }

  Widget _buildTsiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _fieldLabel('TSI/Plafond/Nilai Penjaminan'),
            _buildCurrencyDropdown(),
          ],
        ),
        const SizedBox(height: 8),
        _buildTsiField(),
        if (_currency != 'IDR') ...[
          const SizedBox(height: 12),
          _labeled('Kurs (1 $_currency ke IDR)', _buildKursField()),
          const SizedBox(height: 6),
          Text(
            _kursLoading
                ? 'Mengambil kurs referensi…'
                : '≈ ${AppFormat.rupiah(_tsiIdr)}  ·  kurs indikatif (referensi ECB)',
            style: const TextStyle(fontSize: 11, color: AppColors.grayStage),
          ),
        ],
      ],
    );
  }

  Widget _buildCurrencyDropdown() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.bgScreen,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _currency,
          isDense: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: AppColors.grayStage,
          ),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryNavy,
          ),
          items: _currencyOptions
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => _onCurrencyChanged(v ?? 'IDR'),
        ),
      ),
    );
  }

  Widget _buildTsiField() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 6),
            child: Text(
              _currency == 'IDR' ? 'Rp' : _currency,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _tsiController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _onTsiChanged,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(color: AppColors.grayStage),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKursField() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _kursController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [DecimalInputFormatter()],
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_kursLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  /// Isian rate (%). Terisi otomatis dari rate default milik admin begitu pilihan
  /// lengkap (MTR-2), dan tetap bisa diketik ulang — ketikan itu hanya berlaku untuk
  /// perhitungan yang sedang berjalan. Slot tanpa default tampil kosong seperti dulu.
  /// Tidak ada angka rate yang disimpan di dalam kode aplikasi.
  Widget _buildRateField() {
    final enabled = _selectionComplete;
    final melanggar = _belowMinRate;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: enabled ? AppColors.surfaceWhite : AppColors.grayBg,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(
          color: melanggar ? AppColors.errorRed : AppColors.border,
          width: melanggar ? 1.5 : 1,
        ),
      ),
      child: TextField(
        controller: _rateController,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: const [DecimalInputFormatter()],
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: enabled ? '0.000' : 'Pilih produk dulu',
          hintStyle: const TextStyle(
            color: AppColors.grayStage,
            fontSize: 12.5,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );
  }

  /// Keterangan + aksi rate default di bawah isian Rate (MTR-2).
  ///
  /// Tiga hal yang harus terbaca jelas di sini, karena angka rate kini bisa datang
  /// dari orang lain: (1) angka ini default dari admin dan kapan terakhir diubah,
  /// (2) begitu ditimpa, timpaannya HANYA untuk perhitungan ini, (3) khusus admin,
  /// dari sinilah default itu disimpan untuk semua pengguna.
  List<Widget> _buildRateDefaultSection() {
    final slot = _slotKey;
    if (slot == null) return const [];

    final def = _slotDefault;
    final rows = <Widget>[];

    // Pelanggaran batas bawah didahulukan: selama ini menyala, tidak ada yang lebih
    // penting untuk dibaca di sini.
    if (_belowMinRate) {
      rows.add(
        _rateNote(
          Icons.block_outlined,
          AppColors.errorRed,
          'Rate di bawah batas bawah ${_rateText(_minRate!)}%. Ekspor dokumen '
          'dinonaktifkan sampai rate dinaikkan.',
          trailing: TextButton(
            onPressed: () =>
                setState(() => _rateController.text = _rateText(_minRate!)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Pakai batas bawah',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
      );
    } else if (_minRate != null) {
      rows.add(
        _rateNote(
          Icons.south_east,
          AppColors.grayStage,
          'Batas bawah ${_rateText(_minRate!)}% — rate boleh dinaikkan, tidak boleh '
          'diturunkan di bawah angka ini.',
        ),
      );
    }

    // Selama pelanggaran batas bawah menyala, keterangan asal-usul angka ditahan:
    // yang perlu dikerjakan user cuma satu, dan dua baris nasihat sekaligus justru
    // mengaburkannya.
    if (!_belowMinRate) {
      if (def != null && _rateOverridden) {
        rows.add(
          _rateNote(
            Icons.edit_outlined,
            AppColors.secondaryOrange,
            'Default ${_rateText(def.ratePercent)}%',
            trailing: TextButton(
              onPressed: () => setState(_applyDefaultRate),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Pakai default',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        );
      } else if (def != null) {
        final oleh = (def.updatedByName ?? '').isEmpty
            ? ''
            : ' oleh ${def.updatedByName}';
        rows.add(
          _rateNote(
            Icons.verified_outlined,
            AppColors.successGreen,
            'Rate default dari admin · diperbarui '
            '${AppFormat.dateOnly(def.updatedAt)}$oleh.',
          ),
        );
      } else if (_isAdmin) {
        rows.add(
          _rateNote(
            Icons.info_outline,
            AppColors.grayStage,
            'Belum ada rate default untuk pilihan ini.',
          ),
        );
      }
    }

    if (_isAdmin) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            children: [
              TextButton.icon(
                onPressed: _editRateDefault,
                icon: const Icon(Icons.tune, size: 16),
                label: Text(
                  def == null
                      ? 'Atur rate default & batas bawah'
                      : 'Ubah rate default & batas bawah',
                  style: const TextStyle(fontSize: 12.5),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryNavy,
                ),
              ),
              if (def != null)
                TextButton.icon(
                  onPressed: _clearRateDefault,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text(
                    'Hapus default',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.errorRed,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (rows.isEmpty) return const [];
    return [const SizedBox(height: 8), ...rows];
  }

  Widget _rateNote(
    IconData icon,
    Color color,
    String text, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  /// Atur rate default + batas bawah slot ini (ADMIN).
  ///
  /// Keduanya di SATU dialog karena keduanya satu baris data yang sama dan saling
  /// terikat: default tidak boleh di bawah batas bawahnya sendiri (server menolak),
  /// dan mengubah salah satunya sendirian mudah menghasilkan pasangan yang mustahil.
  /// Isian default terisi dari angka yang sedang diketik admin di kalkulator, supaya
  /// alur "hitung dulu, baru tetapkan" tetap terasa menyambung.
  Future<void> _editRateDefault() async {
    final slot = _slotKey;
    if (slot == null) return;
    final def = _slotDefault;

    final rateCtrl = TextEditingController(
      text: _rate != null
          ? _rateText(_rate!)
          : (def == null ? '' : _rateText(def.ratePercent)),
    );
    final minCtrl = TextEditingController(
      text: def?.minRatePercent == null ? '' : _rateText(def!.minRatePercent!),
    );

    final hasil = await showDialog<({double rate, double? min})>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Rate default & batas bawah'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _slotLabel,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                _dialogRateField(
                  controller: rateCtrl,
                  label: 'Rate default (%)',
                  hint: 'Angka awal yang tampil ke semua pengguna',
                ),
                const SizedBox(height: 12),
                _dialogRateField(
                  controller: minCtrl,
                  label: 'Batas bawah (%)',
                  hint: 'Kosongkan bila slot ini tanpa batas bawah',
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.errorRed,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Rate default tampil sebagai angka awal untuk SEMUA pengguna '
                  'Kalkulator Premi. Batas bawah menolak rate yang lebih rendah, '
                  'di aplikasi maupun di server.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
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
                  final rate = double.tryParse(rateCtrl.text.trim());
                  final minText = minCtrl.text.trim();
                  final min = minText.isEmpty ? null : double.tryParse(minText);
                  if (rate == null) {
                    setDialogState(() => error = 'Rate default wajib diisi.');
                    return;
                  }
                  if (minText.isNotEmpty && min == null) {
                    setDialogState(() => error = 'Batas bawah bukan angka.');
                    return;
                  }
                  if (rate < 0 ||
                      rate > 100 ||
                      (min != null && (min < 0 || min > 100))) {
                    setDialogState(
                      () => error = 'Rate harus antara 0% dan 100%.',
                    );
                    return;
                  }
                  if (min != null && rate < min) {
                    setDialogState(
                      () => error =
                          'Rate default tidak boleh di bawah batas bawah.',
                    );
                    return;
                  }
                  Navigator.pop(ctx, (rate: rate, min: min));
                },
                child: const Text('Simpan'),
              ),
            ],
          ),
        );
      },
    );

    rateCtrl.dispose();
    minCtrl.dispose();
    if (hasil == null || !mounted) return;

    final repo = PremiRateRepository(
      apiClient: ApiClient(session: MbisApp.of(context)?.session),
    );
    try {
      await ref
          .read(kalkulatorPremiProvider.notifier)
          .saveRateDefault(
            repo,
            slotKey: slot,
            ratePercent: hasil.rate,
            minRatePercent: hasil.min,
            productName: _category == PremiCategory.asuransiUmum
                ? _product?.name
                : null,
            riskTier: _product?.risk?.tierCode(_checkedCriteria.length),
            jaminan: _jaminanIdx == null ? null : kBondJaminan[_jaminanIdx!],
            tenor: _tenorIdx == null ? null : kBondTenors[_tenorIdx!],
          );
      if (!mounted) return;
      // Isian kalkulator ikut disamakan dengan default yang baru: admin baru saja
      // menyatakan angka itulah acuannya, jadi layar tidak boleh tetap menampilkan
      // angka lain seolah-olah masih "ditimpa".
      setState(_applyDefaultRate);
      _snack('Rate default tersimpan.');
    } catch (e) {
      if (!mounted) return;
      _snack(_clean(e));
    }
  }

  Widget _dialogRateField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [DecimalInputFormatter()],
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 11.5,
              color: AppColors.grayStage,
            ),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  /// Hapus rate default slot ini (ADMIN) — kalkulator kembali ke isian kosong.
  Future<void> _clearRateDefault() async {
    final slot = _slotKey;
    if (slot == null || _slotDefault == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus rate default?'),
        content: Text(
          '$_slotLabel\n\n'
          'Setelah dihapus, pengguna kalkulator mengisi sendiri rate untuk '
          'pilihan ini seperti sebelumnya.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final repo = PremiRateRepository(
      apiClient: ApiClient(session: MbisApp.of(context)?.session),
    );
    try {
      await ref
          .read(kalkulatorPremiProvider.notifier)
          .clearRateDefault(repo, slot);
      if (!mounted) return;
      setState(_applyDefaultRate);
      _snack('Rate default dihapus.');
    } catch (e) {
      if (!mounted) return;
      _snack(_clean(e));
    }
  }

  /// Isian biaya admin (CR-21). Selalu aktif — biaya admin tidak bergantung
  /// kategori seperti diskon; kosong berarti tanpa biaya admin.
  Widget _buildBiayaAdminField() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 14, right: 6),
            child: Text(
              'Rp',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _biayaAdminController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _onBiayaAdminChanged,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(color: AppColors.grayStage),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiskonField() {
    final enabled = _category.allowsDiscount;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: enabled ? AppColors.surfaceWhite : AppColors.grayBg,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _diskonController,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: const [DecimalInputFormatter()],
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: enabled ? '0' : 'N/A',
          hintStyle: const TextStyle(color: AppColors.grayStage),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );
  }

  // ── shared bits ────────────────────────────────────────────────────────────

  Widget _labeled(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_fieldLabel(label), const SizedBox(height: 8), field],
    );
  }

  Widget _dropdownShell({required Widget child}) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(child: child),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    ),
  );

  Widget _fieldLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    ),
  );
}

/// Searchable bottom-sheet product picker for Asuransi Umum.
class _ProductPickerSheet extends StatefulWidget {
  final UmumProduct? selected;
  const _ProductPickerSheet({this.selected});

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? kAsuransiUmumProducts
        : kAsuransiUmumProducts
              .where((p) => p.name.toLowerCase().contains(q))
              .toList();
    // Height follows the area above the keyboard so the sheet never gets pushed
    // to the very top of the screen while searching.
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: (mq.size.height - mq.viewInsets.bottom) * 0.72,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Cari produk…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.bgScreen,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.radiusMd,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.radiusMd,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'Tidak ada produk cocok',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.border,
                      ),
                      itemBuilder: (context, i) {
                        final p = filtered[i];
                        final isSel = p.name == widget.selected?.name;
                        return ListTile(
                          dense: true,
                          title: Text(
                            p.name,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isSel
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSel
                                  ? AppColors.primaryNavy
                                  : AppColors.textPrimary,
                            ),
                          ),
                          trailing: p.risk != null
                              ? const Icon(
                                  Icons.tune,
                                  size: 16,
                                  color: AppColors.grayStage,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Searchable bottom-sheet customer picker — lists the RM's own customers
/// (GET /api/customers, office/RM-scoped by the backend).
class _CustomerPickerSheet extends StatefulWidget {
  final CustomerRepository repo;
  const _CustomerPickerSheet({required this.repo});

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  late Future<List<CustomerListModel>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = widget.repo.getCustomers();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pilih Nasabah',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Cari nasabah…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.bgScreen,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.radiusMd,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.radiusMd,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<CustomerListModel>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError || !snap.hasData) {
                    return ErrorStateView(
                      message: 'Gagal memuat nasabah',
                      onRetry: () async => setState(() {
                        _future = widget.repo.getCustomers();
                      }),
                    );
                  }
                  final q = _query.trim().toLowerCase();
                  final list = q.isEmpty
                      ? snap.data!
                      : snap.data!
                            .where((c) => c.name.toLowerCase().contains(q))
                            .toList();
                  if (list.isEmpty) {
                    return const EmptyStateView(
                      icon: Icons.person_search,
                      title: 'Tidak ada nasabah cocok',
                      subtitle: 'Coba kata kunci lain.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                    itemBuilder: (context, i) {
                      final c = list[i];
                      return ListTile(
                        dense: true,
                        title: Text(
                          c.name,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: c.entityCategory != null
                            ? Text(
                                c.entityCategory!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(c),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
