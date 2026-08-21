import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../utils/input_formatters.dart';
import '../../utils/kur_product.dart';
import '../../utils/pipeline_nilai_wajib.dart';
import '../widgets/field_label.dart';
import '../widgets/missing_fields_notice.dart';
import '../widgets/search_picker_sheet.dart';
import '../widgets/add_pipeline/form_section.dart';
import '../widgets/add_pipeline/readonly_box.dart';
import '../widgets/add_pipeline/polis_preview.dart';
import '../widgets/add_pipeline/locked_text_field.dart';
import '../widgets/add_pipeline/locked_process_field.dart';
import '../../core/providers/repository_providers.dart';
import '../providers/add_pipeline_provider.dart';
import '../../src/pipeline/pipeline_repository.dart';
import '../../src/pipeline/pipeline_stage.dart';
import '../../src/broker/broker_repository.dart';
import '../../src/customer/customer_repository.dart';
import '../../src/reference/reference_repository.dart';
import '../../src/referral/referral_repository.dart';

/// One co-party row (badan hukum + customer) for KSO/JO/JV/QQ/Cabang.
/// [customerName] is picked from the RM's existing customers (searchable),
/// not typed free-form.
class _PartyInput {
  String? legalEntity;
  String? customerName;
  String?
  customerId; // customer terkait (agar pipeline bisa diakses dari mitra)
  /// Identitas kartu di widget tree. Karena kunci ikut objeknya (bukan posisi),
  /// state kartu tetap menempel pada baris yang benar saat daftar diurutkan
  /// ulang atau ada baris dihapus di tengah.
  final GlobalKey cardKey = GlobalKey();
}

/// One tender-process row (proses + tanggal mulai/selesai).
/// [mandatory] rows are the wajib steps (Pendaftaran/Scoring/Won) seeded
/// automatically — the process can't be changed or removed, only its dates.
class _TenderInput {
  String? processType;
  DateTime? start;
  DateTime? end;
  final bool mandatory;

  /// Lihat [_PartyInput.cardKey]. Penting di sini karena `_sortTenders()`
  /// mengurutkan ulang daftar setiap kali user memilih proses.
  final GlobalKey cardKey = GlobalKey();
  _TenderInput({this.processType, this.mandatory = false});
}

/// Wajib tender steps auto-added when Tender is selected (kept in enum order).
const List<String> _mandatoryTenderSteps = [
  'PENDAFTARAN_TENDER',
  'SCORING_PENGUMUMAN',
  'WON_TENDER',
];

/// Canonical tender flow order (mirrors backend TenderProcessType enum). New
/// optional steps slot into their correct position relative to the wajib steps
/// automatically, so the user doesn't have to arrange the cards manually.
const List<String> _tenderFlowOrder = [
  'PENGUMPULAN_INFORMASI',
  'PENDAFTARAN_TENDER',
  'PEMENUHAN_DOKUMEN',
  'SUBMIT_DOKUMEN',
  'KLARIFIKASI_NEGO',
  'SCORING_PENGUMUMAN',
  'WON_TENDER',
  'LOSS_TENDER',
];

/// Formulir pipeline — dipakai untuk TAMBAH maupun EDIT.
///
/// Beri [existing] untuk membuka dalam mode edit. Yang SENGAJA tidak ikut diedit
/// di sini karena punya alur & aturannya sendiri: stage/detail stage (lewat
/// editor status, yang mewajibkan nilai realisasi saat WON dan mengirim
/// notifikasi), serta referral lintas cabang (butuh persetujuan dua BM).
class AddPipelineScreen extends ConsumerStatefulWidget {
  final String customerId;
  final String?
  customerName; // nama customer utama (auto-isi sbg pihak pertama kerja sama)
  final String?
  customerLegalEntity; // badan hukum customer utama (auto-isi pihak pertama)
  final PipelineDetailModel? existing;

  const AddPipelineScreen({
    super.key,
    required this.customerId,
    this.customerName,
    this.customerLegalEntity,
    this.existing,
  });

  @override
  ConsumerState<AddPipelineScreen> createState() => _AddPipelineScreenState();
}

class _AddPipelineScreenState extends ConsumerState<AddPipelineScreen> {
  final _formKey = GlobalKey<FormState>();

  /// Baru menyala setelah percobaan simpan pertama yang gagal, supaya pesan
  /// error mengikuti perbaikan user secara langsung tanpa memerahkan seluruh
  /// form sejak layar dibuka.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  // ── Sumber bisnis ──
  String _sumberBisnis = '';
  String _namaSumber = '';
  String _namaProyek = '';

  // ── Status kerja sama (Individu/KSO/JO/QQ/JV/Cabang) + co-parties ──
  String _statusKerjaSama = 'INDIVIDU';
  final List<_PartyInput> _parties = [];

  // ── Produk (COB -> LOB -> ToC) ──
  String? _cob;
  String? _lob;

  /// Produk KUR: TSI & rate premi boleh 0 dulu lalu diedit kemudian (CR-05, umpan
  /// balik piloting Makassar). Aturannya cermin `TargetCategoryClassifier` di backend.
  bool get _isKur => isKurProduct(tocCode: _tocCode, cobName: _cob);
  String? _tocCode;
  String? _tocName;

  // ── Nilai ──
  String _currency = 'IDR';
  double _kurs = 1.0;
  double _tsiOriginal = 0.0;
  double _ratePremi = 0.0; // percent

  // ── Tender ──
  bool _isTender = false;
  String _namaTender = ''; // wajib saat tender
  final List<_TenderInput> _tenders = [];

  // ── Referral lintas cabang (RM saja) ──
  // _isReferral (toggle) & _referralToOfficeId (nilai terpilih) = input user →
  // TETAP di sini; daftar cabang tujuan (async) dikelola notifier (getter di bawah).
  bool _isReferral = false;
  String? _referralToOfficeId;

  // ── Stage ──
  String _stage = 'P3';
  String _detailStage = '';
  DateTime? _estimasiClosing;

  // State async (peran sesi, opsi referensi/produk/broker/customer, flag muat,
  // kurs loading, flag simpan) dikelola AddPipelineNotifier. Field lama
  // diproksikan lewat getter di bawah agar seluruh kode build/form tetap memakai
  // nama yang sama tanpa diubah. Input form interaktif (controller, nilai
  // terpilih, toggle, daftar parties & tender, tanggal) TETAP di sini.
  AddPipelineState get _aps => ref.read(addPipelineProvider);
  AddPipelineNotifier get _notifier => ref.read(addPipelineProvider.notifier);

  bool get _saving => _aps.saving;

  /// Agents submit leads attributed to themselves. The backend forces the source
  /// (the logged-in agent), the owning RM (customer's assigned RM) and the initial
  /// stage, so the "Sumber Bisnis" picker is hidden for agents.
  bool get _isAgent => _aps.isAgent;
  // Referral (cross-branch handover) is an RM-only action; agents can't refer.
  bool get _isRm => _aps.isRm;

  // Reference data (async, dikelola notifier)
  List<BrokerModel> get _brokers => _aps.brokers;
  bool get _brokersLoading => _aps.brokersLoading;
  ProductCascade get _cascade => _aps.cascade ?? ProductCascade(const []);
  List<ParamRef> get _kerjaSamaOptions => _aps.kerjaSamaOptions;
  List<ParamRef> get _badanHukumOptions => _aps.badanHukumOptions;
  List<ParamRef> get _tenderStepOptions => _aps.tenderStepOptions;
  List<AgentRef> get _agents =>
      _aps.agents; // region-scoped agents for the Agen dropdown
  String? _agentId;
  String? _brokerId; // selected broker (searchable picker)
  List<CustomerListModel> get _customers =>
      _aps.customers; // RM's existing customers (co-party picker)
  bool get _customersLoading => _aps.customersLoading;
  List<BranchOffice> get _branchOffices => _aps.branchOffices;

  final TextEditingController _kursController = TextEditingController(
    text: '1.0',
  );
  final TextEditingController _tsiController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();

  // Sumber bisnis: param SUMBER_BISNIS (key = enum PipelineSourceType, value = label),
  // admin-editable di Kelola Master Data. _sumberBisnis menyimpan KEY. Fallback dipakai
  // bila param belum termuat. Opsi (async) dikelola notifier.
  List<ParamRef> get _sumberOptions => _aps.sumberOptions;

  // Mata uang: param CURRENCY (admin-editable); fallback bila belum termuat.
  List<String> get _currencyOptions => _aps.currencyOptions;

  bool get _kursLoading => _aps.kursLoading;

  Map<String, List<String>> get _stageOptions => {
    for (final b in const ['P3', 'P2', 'P1'])
      b: PipelineStages.byBucket[b]!.map((s) => s.label).toList(),
  };

  String? _subStageValue() {
    if (_detailStage.isEmpty) return null;
    for (final s in PipelineStages.byBucket[_stage] ?? const <SubStage>[]) {
      if (s.label == _detailStage) return s.value;
    }
    return null;
  }

  bool get _isEdit => widget.existing != null;
  bool _savingEdit = false;

  /// Isi state form dari pipeline yang sedang diedit.
  ///
  /// Nilai dropdown (sumber bisnis, kerja sama, COB/LOB/ToC) dipasang apa adanya;
  /// tiap dropdown sudah menyaring nilainya terhadap daftar opsinya sendiri dan
  /// dibangun ulang begitu opsi itu tiba, jadi tak perlu menunggu data referensi.
  ///
  /// Valuta asal & kurs dipulihkan dari server (V64). Sebelum itu keduanya tidak
  /// pernah disimpan, jadi pipeline lama tetap tampil sebagai rupiah hasil konversi
  /// — di situ `currency` null dan IDR/1.0 memang satu-satunya isian yang jujur.
  void _prefillFromExisting() {
    final p = widget.existing;
    if (p == null) return;
    _sumberBisnis = p.sourceType ?? 'DIRECT';
    if (_sumberBisnis == 'BROKER') _brokerId = p.refId;
    if (_sumberBisnis == 'AGENT') _agentId = p.refId;
    _namaProyek = p.projectName ?? '';
    _statusKerjaSama = p.statusKerjaSama ?? 'INDIVIDU';
    _cob = p.cobName;
    _lob = p.lobName;
    _tocCode = p.tocCode;
    _tocName = p.product;
    _isTender = p.isTender;
    _namaTender = p.tenderName ?? '';
    _stage = p.stage.isEmpty ? 'P3' : p.stage;
    _currency = p.currency ?? 'IDR';
    _kurs = p.kurs ?? 1.0;
    _kursController.text = _trimTrailingZeros(_kurs);
    // TSI ditampilkan dalam valuta asalnya bila diketahui; kalau tidak, nilai
    // rupiahnya (kurs 1.0 di atas menjaga _tsiIdr tetap sama saat disimpan ulang).
    _tsiOriginal = p.tsiOriginal ?? p.tsiIdr;
    if (_tsiOriginal > 0) {
      // Titik ribuan dipasang manual: inputFormatters hanya jalan saat pemakai
      // mengetik, tidak saat teks controller diisi dari kode.
      _tsiController.text = _formatCurrency(_tsiOriginal, symbol: '').trim();
    }
    if (p.ratePremi != null) {
      _ratePremi = p.ratePremi!;
      _rateController.text = _trimTrailingZeros(p.ratePremi!);
    }
    _estimasiClosing = p.closingEstimasi != null
        ? DateTime.tryParse(p.closingEstimasi!)
        : null;
    for (final party in p.parties) {
      _parties.add(
        _PartyInput()
          ..legalEntity = party.legalEntity
          ..customerName = party.customerName,
      );
    }
    for (final t in p.tenderProcesses) {
      _tenders.add(
        _TenderInput(
          processType: t.processType,
          mandatory: _mandatoryTenderSteps.contains(t.processType),
        )
          ..start = t.startDate != null ? DateTime.tryParse(t.startDate!) : null
          ..end = t.endDate != null ? DateTime.tryParse(t.endDate!) : null,
      );
    }
  }

  /// "2.5000" → "2.5"; rate disimpan double, tampilannya jangan berekor nol.
  static String _trimTrailingZeros(double v) {
    var s = v.toStringAsFixed(4);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  @override
  void initState() {
    super.initState();
    // Prefill SEBELUM listener dipasang: listener menulis ulang _tsiOriginal &
    // _ratePremi dari teks controller, dan itu memicu setState di initState.
    _prefillFromExisting();
    _kursController.addListener(_onCalculationsChanged);
    _tsiController.addListener(_onCalculationsChanged);
    _rateController.addListener(_onCalculationsChanged);
    // Bootstrap notifier setelah frame pertama: deteksi peran + muat
    // broker/referensi/customer (dan cabang referral bila RM). Sesi & repository
    // dibaca notifier dari provider — tak perlu context. (Dulu di
    // didChangeDependencies dengan guard `_apiClient == null`.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start();
      // Source is the agent themselves (backend enforces); default so the hidden
      // required dropdown never blocks submission. `_sumberBisnis` (input user)
      // tetap di widget; start() sudah men-set peran secara sinkron.
      if (_aps.isAgent) {
        setState(() => _sumberBisnis = 'AGENT');
      }
    });
  }

  @override
  void dispose() {
    _kursController.dispose();
    _tsiController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _onCalculationsChanged() {
    setState(() {
      _kurs = double.tryParse(_kursController.text) ?? 1.0;
      final tsiDigits = _tsiController.text.replaceAll(RegExp(r'[^0-9]'), '');
      _tsiOriginal = tsiDigits.isEmpty ? 0.0 : double.parse(tsiDigits);
      _ratePremi = double.tryParse(_rateController.text) ?? 0.0;
    });
  }

  double get _tsiIdr => _tsiOriginal * _kurs;
  double get _totalPremiIdr => _tsiIdr * (_ratePremi / 100);

  /// Switches currency and auto-fills an indicative kurs (editable) for non-IDR.
  /// Trigger dari dropdown onChanged tetap di widget; ambil kurs (async) + flag
  /// `kursLoading` didelegasikan ke notifier. Staleness (`_currency`) & penulisan
  /// hasil ke `_kursController` tetap di sini karena bergantung input user.
  Future<void> _onCurrencyChanged(String? val) async {
    final cur = val ?? 'IDR';
    setState(() {
      _currency = cur;
      if (cur == 'IDR') {
        _kursController.text = '1.0';
      }
    });
    if (cur == 'IDR') {
      _notifier.clearKursLoading();
      return;
    }
    final rate = await _notifier.loadKurs(cur); // menandai kursLoading = true
    if (!mounted || _currency != cur) return;
    _notifier.clearKursLoading();
    setState(() {
      if (rate != null) {
        // Keep up to 2 decimals; the live calc strips formatting itself.
        _kursController.text = rate == rate.roundToDouble()
            ? rate.toStringAsFixed(0)
            : rate.toStringAsFixed(2);
      }
    });
  }

  String _formatCurrency(double val, {String symbol = 'Rp'}) {
    if (val <= 0) return '0';
    final s = val.toInt().toString();
    final buf = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      count++;
      if (count % 3 == 0 && i != 0) buf.write('.');
    }
    return '$symbol ${buf.toString().split('').reversed.join('')}';
  }

  String _labelOfParam(List<ParamRef> opts, String? key) {
    for (final o in opts) {
      if (o.key == key) return o.value;
    }
    return key ?? '';
  }

  /// Nama customer utama pipeline ini — dipakai sebagai pihak pertama kerja sama.
  String get _mainCustomerName {
    if (widget.customerName != null && widget.customerName!.trim().isNotEmpty) {
      return widget.customerName!.trim();
    }
    for (final c in _customers) {
      if (c.id == widget.customerId) return c.name;
    }
    return '';
  }

  /// Map badan hukum customer (bisa berupa key 'PT_TBK' atau value 'PT Tbk') ke
  /// key opsi dropdown supaya cocok dengan _badanHukumOptions.
  String? _mapBadanHukumKey(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final r = raw.trim();
    for (final o in _badanHukumOptions) {
      if (o.key == r) return o.key;
    }
    for (final o in _badanHukumOptions) {
      if (o.value.toLowerCase() == r.toLowerCase()) return o.key;
    }
    return r; // fallback apa adanya
  }

  void _onStatusKerjaSamaChanged(String? key) {
    setState(() {
      _statusKerjaSama = key ?? 'INDIVIDU';
      if (_statusKerjaSama != 'INDIVIDU') {
        // Minimal 2 badan hukum; pihak pertama otomatis = customer pipeline ini.
        while (_parties.length < 2) {
          _parties.add(_PartyInput());
        }
        _parties[0].customerName = _mainCustomerName;
        _parties[0].customerId = widget.customerId;
        _parties[0].legalEntity = _mapBadanHukumKey(widget.customerLegalEntity);
      } else {
        _parties.clear();
      }
    });
  }

  /// "Preview Nama pada Polis" dari pihak-pihak kerja sama. Selain QQ:
  /// "XX A - B - ..." (XX = jenis kerja sama). QQ: "A QQ B QQ ...".
  String _previewPolisName() {
    final names = _parties
        .map((p) => p.customerName?.trim() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
    if (names.length < 2) return '';
    if (_statusKerjaSama == 'QQ') return names.join(' QQ ');
    final xx = _labelOfParam(_kerjaSamaOptions, _statusKerjaSama);
    return '$xx ${names.join(' - ')}';
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat opsi/flag async berubah
    // (mengganti setState untuk bagian yang dipindah ke notifier).
    ref.watch(addPipelineProvider);
    final detailStageList = _stageOptions[_stage] ?? [];

    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEdit ? 'Edit Pipeline' : 'Tambah Pipeline',
          style: const TextStyle(
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
              autovalidateMode: _autovalidate,
              child: Column(
                children: [
                  // ─────────── SUMBER BISNIS ───────────
                  // Hidden for agents: their leads are auto-attributed to themselves.
                  if (!_isAgent)
                    FormSection(
                      title: 'Sumber Bisnis',
                      children: [
                        _buildDropdownFieldKV(
                          label: 'Sumber Bisnis *',
                          valueKey: _sumberBisnis.isEmpty
                              ? null
                              : _sumberBisnis,
                          options: _sumberOptions,
                          onChanged: (val) => setState(() {
                            _sumberBisnis = val ?? '';
                            _namaSumber = '';
                            _brokerId = null;
                            _agentId = null;
                          }),
                          validator: (val) =>
                              val == null ? 'Pilih sumber bisnis' : null,
                        ),
                        if (_sumberBisnis == 'BROKER') ...[
                          const SizedBox(height: 12),
                          _buildPickerField(
                            'Nama Broker *',
                            _namaSumber.isEmpty ? null : _namaSumber,
                            _pickBroker,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _brokersLoading
                                ? '* Memuat daftar broker...'
                                : '* Cari & pilih dari daftar broker terdaftar',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ] else if (_sumberBisnis == 'AGENT') ...[
                          const SizedBox(height: 12),
                          Builder(
                            builder: (_) {
                              final agentItems = _agents
                                  .where(
                                    (a) =>
                                        a.type == 'AGENT' &&
                                        a.status == 'ACTIVE',
                                  )
                                  .toList();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _fieldLabel('Nama Agen *'),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    // Lihat catatan di _buildDropdownFieldKV.
                                    initialValue: agentItems
                                            .any((a) => a.id == _agentId)
                                        ? _agentId
                                        : null,
                                    style: AppInput.fieldText,
                                    isExpanded: true,
                                    items: agentItems
                                        .map(
                                          (a) => DropdownMenuItem<String>(
                                            value: a.id,
                                            child: Text(
                                              a.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) => setState(() {
                                      _agentId = val;
                                      final m = agentItems.where(
                                        (a) => a.id == val,
                                      );
                                      _namaSumber = m.isNotEmpty
                                          ? m.first.name
                                          : '';
                                    }),
                                    validator: (val) =>
                                        val == null ? 'Pilih agen' : null,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: AppColors.grayStage,
                                    ),
                                    decoration: _fieldDecoration(),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    agentItems.isEmpty
                                        ? '* Belum ada agen aktif di wilayah Anda'
                                        : '* Agen aktif di wilayah Anda',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        // Status Kerja Sama (dropdown) — selain Individu butuh >=2 badan hukum.
                        _buildDropdownFieldKV(
                          label: 'Status Kerja Sama *',
                          valueKey: _statusKerjaSama,
                          options: _kerjaSamaOptions,
                          onChanged: _onStatusKerjaSamaChanged,
                        ),
                        if (_statusKerjaSama != 'INDIVIDU') ...[
                          const SizedBox(height: 12),
                          _buildPartiesSection(),
                        ],
                      ],
                    ),
                  const SizedBox(height: 16),

                  // ─────────── INFORMASI PRODUK (COB -> LOB -> ToC) ───────────
                  FormSection(
                    title: 'Informasi Produk',
                    children: [
                      _buildDropdownField(
                        label: 'COB (Class of Business) *',
                        value: _cob,
                        items: _cascade.cobs,
                        onChanged: (val) => setState(() {
                          _cob = val;
                          _lob = null;
                          _tocCode = null;
                          _tocName = null;
                        }),
                        validator: (val) => val == null ? 'Pilih COB' : null,
                      ),
                      if (_cob != null) ...[
                        const SizedBox(height: 12),
                        _buildDropdownField(
                          label: 'LOB (Line of Business) *',
                          value: _lob,
                          items: _cascade.lobs(_cob!),
                          onChanged: (val) => setState(() {
                            _lob = val;
                            _tocCode = null;
                            _tocName = null;
                          }),
                          validator: (val) => val == null ? 'Pilih LOB' : null,
                        ),
                      ],
                      if (_cob != null && _lob != null) ...[
                        const SizedBox(height: 12),
                        _buildTocDropdown(),
                      ],
                      const SizedBox(height: 12),
                      _buildDropdownField(
                        label: 'Currency',
                        value: _currency,
                        items: _currencyOptions,
                        onChanged: _onCurrencyChanged,
                      ),
                      if (_currency != 'IDR') ...[
                        const SizedBox(height: 12),
                        _buildTextField(
                          label: 'Kurs (ke IDR) *',
                          hint: _kursLoading
                              ? 'Mengambil kurs...'
                              : 'Kurs nilai tukar',
                          controller: _kursController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          // Tanpa formatter, koma dari papan ketik ponsel masuk ke
                          // isian tapi `double.tryParse` menolaknya — pemakai divonis
                          // "nilai kurs tidak valid" untuk angka yang ia lihat benar.
                          inputFormatters: const [DecimalInputFormatter()],
                          onChanged: (_) {},
                          validator: (val) =>
                              val == null || double.tryParse(val) == null
                              ? 'Masukkan nilai kurs valid'
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _kursLoading
                              ? '* Mengambil kurs referensi...'
                              : '* Kurs indikatif (referensi ECB) — bisa diubah manual',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextField(
                              label: _isKur
                                  ? 'TSI/Plafond (Original)'
                                  : 'TSI/Plafond (Original) *',
                              hint: '0',
                              controller: _tsiController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [ThousandsInputFormatter()],
                              onChanged: (_) {},
                              validator: (val) {
                                final d = (val ?? '').replaceAll(
                                  RegExp(r'[^0-9]'),
                                  '',
                                );
                                // KUR (CR-05): nilainya sering belum keluar saat RM
                                // mencatat pipeline, jadi 0 diterima dan diedit nanti.
                                // Tetap harus ada isinya supaya 0 itu pilihan sadar,
                                // bukan kolom yang terlewat.
                                if (d.isEmpty) {
                                  return _isKur
                                      ? 'Isi 0 dulu bila nilainya belum keluar'
                                      : 'TSI/Plafond wajib diisi';
                                }
                                if (!_isKur && int.parse(d) <= 0) {
                                  return 'TSI/Plafond wajib diisi';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ReadonlyBox(
                              label: 'TSI/Plafond (IDR)',
                              text: _tsiOriginal > 0
                                  ? _formatCurrency(_tsiIdr)
                                  : 'Auto kalkulasi',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextField(
                              label: _isKur
                                  ? 'Rate Premi (%)'
                                  : 'Rate Premi (%) *',
                              hint: '0.00',
                              controller: _rateController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: const [DecimalInputFormatter()],
                              onChanged: (_) {},
                              validator: (val) {
                                final r = double.tryParse((val ?? '').trim());
                                if (r == null) {
                                  return _isKur
                                      ? 'Isi 0 dulu bila ratenya belum keluar'
                                      : 'Rate premi wajib diisi';
                                }
                                // KUR (CR-05): 0 diterima, diedit setelah ratenya keluar.
                                if (!_isKur && r <= 0) {
                                  return 'Rate premi wajib diisi';
                                }
                                if (r > 100) return 'Rate premi maks 100%';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ReadonlyBox(
                              label: 'Total Premi (IDR)',
                              text: _ratePremi > 0 && _tsiOriginal > 0
                                  ? _formatCurrency(_totalPremiIdr)
                                  : 'Auto kalkulasi',
                            ),
                          ),
                        ],
                      ),
                      // Keterangan hanya muncul untuk KUR, supaya kelonggaran ini
                      // tidak terbaca sebagai izin mengosongkan nilai di produk lain.
                      if (_isKur) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Untuk KUR, TSI dan rate premi boleh diisi 0 dulu bila '
                          'nilainya belum keluar, lalu diedit setelah tersedia.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ─────────── INFORMASI PROYEK ───────────
                  FormSection(
                    title: 'Informasi Proyek',
                    children: [
                      _buildTextField(
                        label: 'Nama Proyek',
                        hint: 'mis. Pembangunan Jalan Tol Seksi 2',
                        initialValue: _namaProyek,
                        onChanged: (val) => setState(() => _namaProyek = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ─────────── TENDER ───────────
                  FormSection(
                    title: 'Tender',
                    children: [
                      const Text(
                        'Status Tender',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: _buildTenderToggle('Tender', true)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTenderToggle('Non Tender', false),
                          ),
                        ],
                      ),
                      if (_isTender) ...[
                        const SizedBox(height: 14),
                        _buildTextField(
                          // Wajib saat Tender (divalidasi di _handleSubmit),
                          // jadi tandai bintang seperti field wajib lain.
                          label: 'Nama Tender *',
                          hint: 'mis. Tender Asuransi Proyek IKN 2026',
                          initialValue: _namaTender,
                          onChanged: (val) => setState(() => _namaTender = val),
                        ),
                        const SizedBox(height: 14),
                        _buildTenderSection(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ─────────── REFERRAL (RM only) ───────────
                  // Hanya saat menambah: referral butuh persetujuan BM cabang asal
                  // & tujuan, jadi mengubahnya dari formulir edit akan melewati
                  // alur persetujuan itu.
                  if (_isRm && !_isEdit) ...[
                    FormSection(
                      title: 'Referral',
                      children: [
                        // Material transparan: tanpa ini ripple & warna tile
                        // dilukis di Material terdekat lalu TERTUTUP oleh
                        // background FormSection, jadi barisnya tak memberi
                        // respons sentuh (Flutter juga melaporkannya di debug).
                        Material(
                          type: MaterialType.transparency,
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text(
                              'Referral ke cabang lain',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            subtitle: const Text(
                              'Menunggu approval BM cabang asal & tujuan',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            value: _isReferral,
                            activeThumbColor: AppColors.primaryNavy,
                            onChanged: (v) => setState(() {
                              _isReferral = v;
                              if (!v) _referralToOfficeId = null;
                            }),
                          ),
                        ),
                        if (_isReferral) ...[
                          const SizedBox(height: 8),
                          _buildDropdownFieldKV(
                            label: 'Cabang Tujuan *',
                            valueKey: _referralToOfficeId,
                            options: _branchOffices
                                .map((o) => ParamRef(o.id, o.name))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _referralToOfficeId = v),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ─────────── STAGE PIPELINE ───────────
                  FormSection(
                    title: 'Stage Pipeline',
                    children: [
                      // Untuk Tender, stage & detail stage ditentukan otomatis dari
                      // proses tender (mulai dari "Pendaftaran Tender"), jadi cukup
                      // tampilkan estimasi closing saja. Saat mengedit stage juga
                      // disembunyikan: perpindahannya lewat editor status, yang
                      // mewajibkan nilai realisasi di WON dan menulis riwayat.
                      if (!_isTender && !_isEdit) ...[
                        _fieldLabel('Stage *'),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStageToggle(
                                'P3',
                                AppColors.grayStage,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildStageToggle(
                                'P2',
                                AppColors.secondaryOrange,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildStageToggle(
                                'P1',
                                AppColors.primaryNavy,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildDropdownField(
                          label: 'Detail Stage',
                          value:
                              _detailStage.isEmpty ||
                                  !detailStageList.contains(_detailStage)
                              ? null
                              : _detailStage,
                          items: detailStageList,
                          onChanged: (val) =>
                              setState(() => _detailStage = val ?? ''),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _fieldLabel('Estimasi Closing *'),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _showClosingDatePicker,
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _estimasiClosing == null
                                    ? 'Pilih tanggal'
                                    : '${_estimasiClosing!.day} ${_getMonthName(_estimasiClosing!.month)} ${_estimasiClosing!.year}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _estimasiClosing == null
                                      ? AppColors.grayStage
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const Icon(
                                Icons.calendar_today_outlined,
                                color: AppColors.grayStage,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_saving || _savingEdit) ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryNavy,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.radiusLg,
                        ),
                        elevation: 0,
                      ),
                      child: (_saving || _savingEdit)
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isEdit ? 'Simpan Perubahan' : 'Simpan Pipeline',
                              style: const TextStyle(
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

  // ── Parties (co-badan hukum) ──
  Widget _buildPartiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Badan Hukum (minimal 2)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < _parties.length; i++) _buildPartyCard(i),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => setState(() => _parties.add(_PartyInput())),
          icon: const Icon(Icons.add, size: 16, color: AppColors.primaryNavy),
          label: const Text(
            'Tambah Badan Hukum',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primaryNavy,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.primaryNavy),
          ),
        ),
        if (_previewPolisName().isNotEmpty) ...[
          const SizedBox(height: 12),
          PolisPreview(previewName: _previewPolisName()),
        ],
      ],
    );
  }

  Widget _buildPartyCard(int i) {
    final p = _parties[i];
    final isMain =
        i == 0; // pihak pertama = customer pipeline ini (auto, terkunci)
    return Container(
      key: p.cardKey,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
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
              Text(
                isMain ? 'Perusahaan 1 (Customer)' : 'Perusahaan ${i + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (!isMain && _parties.length > 2)
                InkWell(
                  onTap: () => setState(() => _parties.removeAt(i)),
                  child: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.errorRed,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (isMain && p.legalEntity != null)
            LockedTextField(
              label: 'Badan Hukum *',
              value: _labelOfParam(_badanHukumOptions, p.legalEntity),
            )
          else
            _buildDropdownFieldKV(
              label: 'Badan Hukum *',
              valueKey: p.legalEntity,
              options: _badanHukumOptions,
              onChanged: (v) => setState(() => p.legalEntity = v),
            ),
          const SizedBox(height: 8),
          if (isMain)
            LockedTextField(
              label: 'Nama Customer *',
              value: p.customerName ?? _mainCustomerName,
            )
          else ...[
            _buildPickerField(
              'Nama Customer *',
              p.customerName,
              () => _pickPartyCustomer(i),
            ),
            const SizedBox(height: 4),
            Text(
              _customersLoading
                  ? '* Memuat daftar customer...'
                  : '* Pilih dari customer yang sudah Anda buat',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tender processes ──
  /// Seed the wajib steps (Pendaftaran/Scoring/Won) so they're visible and
  /// can't be forgotten. User fills the dates; the backend keeps them in order
  /// and re-adds any that go missing.
  void _seedMandatoryTenders() {
    for (final step in _mandatoryTenderSteps) {
      _tenders.add(_TenderInput(processType: step, mandatory: true));
    }
  }

  /// Keep the tender cards ordered by the canonical flow. Rows that don't have a
  /// process picked yet (just added) stay at the bottom until the user chooses.
  void _sortTenders() {
    int rank(_TenderInput t) {
      if (t.processType == null) return 999;
      final i = _tenderFlowOrder.indexOf(t.processType!);
      return i < 0 ? 998 : i;
    }

    _tenders.sort((a, b) => rank(a).compareTo(rank(b)));
  }

  Widget _buildTenderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Proses Tender (wajib, minimal 1)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < _tenders.length; i++) _buildTenderCard(i),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => setState(() => _tenders.add(_TenderInput())),
          icon: const Icon(Icons.add, size: 16, color: AppColors.primaryNavy),
          label: const Text(
            'Tambah Proses Tender',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primaryNavy,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.primaryNavy),
          ),
        ),
      ],
    );
  }

  Widget _buildTenderCard(int i) {
    final t = _tenders[i];
    return Container(
      key: t.cardKey,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
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
              Text(
                'Proses ${i + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (t.mandatory)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.navyBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text(
                    'Wajib',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                )
              else
                InkWell(
                  onTap: () => setState(() => _tenders.removeAt(i)),
                  child: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.errorRed,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (t.mandatory)
            LockedProcessField(
              label: _labelOfParam(_tenderStepOptions, t.processType),
            )
          else
            _buildDropdownFieldKV(
              label: 'Proses Tender *',
              valueKey: t.processType,
              // Sembunyikan proses yang sudah dipakai baris lain (termasuk wajib)
              // supaya tidak ada duplikat.
              options: _tenderStepOptions
                  .where(
                    (o) =>
                        o.key == t.processType ||
                        !_tenders.any(
                          (x) => !identical(x, t) && x.processType == o.key,
                        ),
                  )
                  .toList(),
              onChanged: (v) => setState(() {
                t.processType = v;
                _sortTenders();
              }),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _tenderDateField(
                  'Tgl Mulai *',
                  t.start,
                  (d) => setState(() {
                    t.start = d;
                    // Kalau tanggal selesai jadi lebih awal dari mulai, kosongkan.
                    if (t.end != null && t.end!.isBefore(d)) t.end = null;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _tenderDateField(
                  'Tgl Selesai *',
                  t.end,
                  (d) => setState(() => t.end = d),
                  minDate: t.start,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tenderDateField(
    String label,
    DateTime? value,
    ValueChanged<DateTime> onPick, {
    DateTime? minDate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final now = DateTime.now();
            // Tgl selesai tidak boleh sebelum tgl mulai: batasi firstDate ke minDate.
            final first = minDate ?? now.subtract(const Duration(days: 365));
            final last = now.add(const Duration(days: 365 * 3));
            var init = value ?? (first.isAfter(now) ? first : now);
            if (init.isBefore(first)) init = first;
            if (init.isAfter(last)) init = last;
            final picked = await showDatePicker(
              context: context,
              initialDate: init,
              firstDate: first,
              lastDate: last,
            );
            if (picked != null) onPick(picked);
          },
          child: Container(
            height: 46,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: AppRadius.radiusMd,
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              value == null
                  ? 'Pilih'
                  : '${value.day} ${_getMonthName(value.month)} ${value.year}',
              style: TextStyle(
                fontSize: 13,
                color: value == null
                    ? AppColors.grayStage
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTocDropdown() {
    final tocs = _cascade.tocs(_cob!, _lob!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('ToC (Type of Coverage) *'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          // Lihat catatan di _buildDropdownFieldKV.
          initialValue: tocs.any((t) => t.tocCode == _tocCode) ? _tocCode : null,
          style: AppInput.fieldText,
          isExpanded: true,
          items: tocs
              .map(
                (t) => DropdownMenuItem<String>(
                  value: t.tocCode,
                  child: Text(
                    t.tocName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() {
            _tocCode = val;
            _tocName = tocs
                .firstWhere((t) => t.tocCode == val, orElse: () => tocs.first)
                .tocName;
          }),
          validator: (val) => val == null ? 'Pilih ToC' : null,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.grayStage,
          ),
          decoration: _fieldDecoration(),
        ),
      ],
    );
  }

  // ── reusable widgets ──
  /// [initialValue] hanya berlaku bila [controller] tidak diberi (TextFormField
  /// melarang keduanya) dan hanya dibaca pada build pertama — cukup, karena isian
  /// teks di-prefill sinkron di initState.
  Widget _buildTextField({
    required String label,
    required String hint,
    TextEditingController? controller,
    String? initialValue,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    required void Function(String) onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: _fieldDecoration(hint: hint),
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
    // Lihat catatan di _buildDropdownFieldKV: nilai di luar daftar opsi bikin
    // Flutter melempar assertion, bukan sekadar tampil kosong.
    final safeValue = items.contains(value) ? value : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          // Lihat catatan key di _buildDropdownFieldKV.
          key: ValueKey('dd-$label-${items.length}'),
          initialValue: safeValue,
          style: AppInput.fieldText,
          isExpanded: true,
          // Let a long selected value wrap to 2 lines so the field grows to fit
          // (e.g. long broker names) instead of being clipped.
          selectedItemBuilder: (context) => items
              .map(
                (item) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item,
                    maxLines: 2,
                    softWrap: true,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              )
              .toList(),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          validator: validator,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.grayStage,
          ),
          decoration: _fieldDecoration(),
        ),
      ],
    );
  }

  /// Dropdown backed by master-parameter key/value options.
  Widget _buildDropdownFieldKV({
    required String label,
    required String? valueKey,
    required List<ParamRef> options,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    // Opsi dropdown ini datang dari master data yang bisa diubah admin. Kalau
    // nilai terpilih tak ada di daftar (opsi dinonaktifkan/diganti, atau daftar
    // belum termuat), DropdownButtonFormField melempar assertion dan layar mati
    // total. Tampilkan kosong saja — user tinggal memilih ulang.
    final safeValue = options.any((o) => o.key == valueKey) ? valueKey : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          // `initialValue` hanya dibaca sekali. Saat mengedit, nilai tersimpan
          // sudah ada sebelum daftar opsinya selesai diunduh, jadi build pertama
          // menyaringnya jadi null dan pilihan itu tak pernah muncul. Key yang
          // ikut jumlah opsi membuat field dibangun ulang begitu opsinya tiba.
          key: ValueKey('kv-$label-${options.length}'),
          initialValue: safeValue,
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
          validator: validator,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.grayStage,
          ),
          decoration: _fieldDecoration(),
        ),
      ],
    );
  }

  Widget _fieldLabel(String label) => fieldLabel(label);

  InputDecoration _fieldDecoration({String? hint}) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.grayStage, fontSize: 14),
      filled: true,
      fillColor: AppColors.bgScreen,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.primaryNavy, 1.5),
      errorBorder: border(AppColors.errorRed),
      focusedErrorBorder: border(AppColors.errorRed, 1.5),
      errorStyle: const TextStyle(fontSize: 12, color: AppColors.errorRed),
    );
  }

  Widget _buildTenderToggle(String label, bool tenderValue) {
    final selected = _isTender == tenderValue;
    return GestureDetector(
      onTap: () => setState(() {
        _isTender = tenderValue;
        if (_isTender && _tenders.isEmpty) _seedMandatoryTenders();
      }),
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
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildStageToggle(String stageName, Color stageColor) {
    final isSelected = _stage == stageName;
    return GestureDetector(
      onTap: () => setState(() {
        _stage = stageName;
        _detailStage = '';
      }),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? stageColor : AppColors.surfaceWhite,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(
            color: isSelected ? stageColor : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          stageName,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  void _showClosingDatePicker() {
    showDatePicker(
      context: context,
      initialDate: _estimasiClosing ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    ).then((selectedDate) {
      if (selectedDate != null) setState(() => _estimasiClosing = selectedDate);
    });
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
    return (month >= 1 && month <= 12) ? months[month - 1] : '';
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// A tappable field that opens the searchable broker picker.
  Widget _buildPickerField(String label, String? value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

  /// Open the searchable broker picker; sets name + id (used as refId).
  Future<void> _pickBroker() async {
    final picked = await _showSearchPicker<BrokerModel>(
      title: 'Pilih Broker',
      initial: _brokers,
      labelOf: (b) => b.name,
      onSearch: (q) async => _brokers
          .where((b) => b.name.toLowerCase().contains(q.toLowerCase()))
          .toList(),
    );
    if (picked != null && mounted) {
      setState(() {
        _brokerId = picked.id;
        _namaSumber = picked.name;
      });
    }
  }

  /// Open the searchable customer picker for co-party [i]; sets the party name
  /// from the RM's existing customers.
  Future<void> _pickPartyCustomer(int i) async {
    final picked = await _showSearchPicker<CustomerListModel>(
      title: 'Pilih Customer',
      initial: _customers,
      labelOf: (c) => c.name,
      onSearch: (q) async => _customers
          .where((c) => c.name.toLowerCase().contains(q.toLowerCase()))
          .toList(),
    );
    if (picked != null && mounted) {
      setState(() {
        _parties[i].customerName = picked.name;
        _parties[i].customerId = picked.id;
      });
    }
  }

  /// Generic searchable bottom-sheet picker (height-capped so the title stays visible).
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
      emptyLabel: 'Tidak ada hasil',
    );
  }

  /// Simpan perubahan pipeline yang sudah ada.
  ///
  /// Body-nya cerminan jalur tambah dikurangi hal-hal yang punya alur sendiri:
  /// stage/sub-stage (editor status) dan referral (butuh persetujuan BM). Sisanya
  /// dikirim lengkap, itulah sebabnya layar ini dipakai ulang alih-alih sheet
  /// berisi sebagian field.
  Future<void> _saveEdit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    String? refId;
    if (_sumberBisnis == 'BROKER') {
      refId = _brokerId;
    } else if (_sumberBisnis == 'AGENT') {
      refId = _agentId;
    }

    final body = <String, dynamic>{
      'product': _tocName,
      'projectName': _namaProyek.isEmpty ? null : _namaProyek,
      'tenderName': _isTender && _namaTender.trim().isNotEmpty
          ? _namaTender.trim()
          : null,
      'statusKerjaSama': _statusKerjaSama,
      'isTender': _isTender,
      'cobName': _cob,
      'lobName': _lob,
      'tocCode': _tocCode,
      'tocName': _tocName,
      'tsiIdr': _tsiIdr,
      // Asal-usul _tsiIdr (V64): tanpa ketiganya, pipeline valas tersimpan
      // tak terbedakan dari pipeline rupiah dan tidak bisa dilaporkan.
      'currency': _currency,
      'kurs': _kurs,
      'tsiOriginal': _tsiOriginal,
      'ratePremi': _ratePremi,
      'closingEstimasi': _estimasiClosing?.toIso8601String(),
      'sourceType': _sumberBisnis.isEmpty ? 'DIRECT' : _sumberBisnis,
      'refId': refId,
      // Koleksi dikirim hanya bila relevan: backend memperlakukan non-null
      // sebagai "ganti seluruh isinya", jadi mengirim daftar kosong untuk
      // pipeline individu/non-tender justru akan menghapus baris yang sah.
      if (_statusKerjaSama != 'INDIVIDU')
        'parties': _parties
            .map((p) => {
                  'legalEntity': p.legalEntity,
                  'customerName': p.customerName?.trim(),
                })
            .toList(),
      if (_isTender)
        'tenderProcesses': _tenders
            .map((t) => {
                  'processType': t.processType,
                  'startDate': _iso(t.start!),
                  'endDate': _iso(t.end!),
                })
            .toList(),
    };

    setState(() => _savingEdit = true);
    try {
      await ref
          .read(pipelineRepoProvider)
          .updatePipeline(widget.existing!.id, body);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('Pipeline diperbarui'),
        backgroundColor: AppColors.successGreen,
      ));
      navigator.pop(true); // detail pipeline memuat ulang
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingEdit = false);
      messenger.showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.errorRed,
      ));
    }
  }

  /// Daftar isian wajib yang masih kurang, URUT sesuai posisinya di layar.
  ///
  /// Semua aturan wajib dikumpulkan di SATU tempat (bukan tersebar antara
  /// `validator` Form dan pengecekan manual) supaya notifikasi bawah bisa
  /// menyebut seluruh yang kurang sekaligus — user tidak perlu menekan Simpan
  /// berkali-kali untuk menemukan satu per satu.
  List<String> _missingRequiredFields() {
    final missing = <String>[];

    if (!_isAgent) {
      if (_sumberBisnis.isEmpty) {
        missing.add('Sumber Bisnis');
      } else if (_sumberBisnis == 'BROKER' && _brokerId == null) {
        missing.add('Nama Broker');
      } else if (_sumberBisnis == 'AGENT' && _agentId == null) {
        missing.add('Nama Agen');
      }
      if (_statusKerjaSama != 'INDIVIDU') {
        final jenis = _labelOfParam(_kerjaSamaOptions, _statusKerjaSama);
        if (_parties.length < 2) {
          missing.add('Badan Hukum (minimal 2 untuk $jenis)');
        } else {
          for (int i = 0; i < _parties.length; i++) {
            final p = _parties[i];
            if (p.legalEntity == null ||
                p.customerName == null ||
                p.customerName!.trim().isEmpty) {
              missing.add('Badan hukum & nama customer pada Perusahaan ${i + 1}');
            }
          }
        }
      }
    }

    if (_cob == null) missing.add('COB (Class of Business)');
    if (_cob != null && _lob == null) missing.add('LOB (Line of Business)');
    if (_cob != null && _lob != null && _tocCode == null) {
      missing.add('ToC (Type of Coverage)');
    }
    if (_currency != 'IDR' && double.tryParse(_kursController.text) == null) {
      missing.add('Kurs (ke IDR)');
    }
    // Aturannya satu, dipakai bersama validator tiap isian (lihat
    // pipeline_nilai_wajib.dart). Dulu pemeriksaan di sini memakai `<= 0` tanpa
    // pengecualian KUR sehingga _handleSubmit berhenti lebih dulu dan validator
    // yang sudah benar tidak pernah sempat dipakai.
    if (tsiBelumLengkap(teks: _tsiController.text, isKur: _isKur)) {
      missing.add('TSI/Plafond (Original)');
    }
    if (rateBelumLengkap(teks: _rateController.text, isKur: _isKur)) {
      missing.add('Rate Premi (%)');
    } else if ((double.tryParse(_rateController.text.trim()) ?? 0) > 100) {
      missing.add('Rate Premi maksimal 100%');
    }

    if (_isTender) {
      if (_namaTender.trim().isEmpty) missing.add('Nama Tender');
      if (_tenders.isEmpty) {
        missing.add('Proses Tender (minimal 1)');
      } else {
        for (int i = 0; i < _tenders.length; i++) {
          final t = _tenders[i];
          final label = t.processType == null
              ? 'Proses ${i + 1}'
              : _labelOfParam(_tenderStepOptions, t.processType);
          if (t.processType == null || t.start == null || t.end == null) {
            missing.add('Proses & tanggal pada $label');
          } else if (t.end!.isBefore(t.start!)) {
            missing.add('Tgl selesai $label tidak boleh sebelum tgl mulai');
          }
        }
      }
    }

    if (_isReferral &&
        (_referralToOfficeId == null || _referralToOfficeId!.isEmpty)) {
      missing.add('Cabang Tujuan referral');
    }
    if (_estimasiClosing == null) missing.add('Estimasi Closing');

    return missing;
  }

  Future<void> _handleSubmit() async {
    final messenger = ScaffoldMessenger.of(context);
    void warn(String m) => messenger.showSnackBar(
      SnackBar(content: Text(m), backgroundColor: AppColors.errorRed),
    );

    final missing = _missingRequiredFields();
    if (missing.isNotEmpty) {
      // Tandai merah di tempatnya + mulai autovalidate agar error ikut hilang
      // saat user memperbaiki, lalu tampilkan pop-up bawah yang MENYEBUT apa
      // saja yang kurang (dulu layar melompat-lompat karena auto-scroll).
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      _formKey.currentState?.validate();
      showMissingFieldsNotice(messenger, missing);
      return;
    }
    // Jaring pengaman: aturan `validator` bawaan Form yang belum tercermin di
    // _missingRequiredFields (mis. format angka) tetap harus lolos.
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      warn('Ada isian yang belum valid');
      return;
    }

    if (_isEdit) {
      await _saveEdit();
      return;
    }

    // Flag simpan (async) + panggilan addPipeline dikelola AddPipelineNotifier.save();
    // body dibangun di sini dari input form lalu diserahkan ke notifier.
    String? refId;
    if (_sumberBisnis == 'BROKER') {
      refId = _brokerId; // backend validates this is a real broker
    } else if (_sumberBisnis == 'AGENT') {
      refId = _agentId; // backend validates this is a real AGENT
    }

    final navigator = Navigator.of(context);

    final body = <String, dynamic>{
      'customerId': widget.customerId,
      'name': _tocName ?? 'Pipeline',
      'product': _tocName,
      'projectName': _namaProyek.isEmpty ? null : _namaProyek,
      'tenderName': _isTender && _namaTender.trim().isNotEmpty
          ? _namaTender.trim()
          : null,
      'isReferral': _isReferral,
      'referralToOfficeId': _isReferral ? _referralToOfficeId : null,
      'statusKerjaSama': _statusKerjaSama,
      'isTender': _isTender,
      'cobName': _cob,
      'lobName': _lob,
      'tocCode': _tocCode,
      'tocName': _tocName,
      'stage': _stage,
      'tsiIdr': _tsiIdr,
      // Asal-usul _tsiIdr (V64): tanpa ketiganya, pipeline valas tersimpan
      // tak terbedakan dari pipeline rupiah dan tidak bisa dilaporkan.
      'currency': _currency,
      'kurs': _kurs,
      'tsiOriginal': _tsiOriginal,
      'ratePremi': _ratePremi,
      'premi': _totalPremiIdr.toString(),
      'closingEstimasi': _estimasiClosing!.toIso8601String(),
      'sourceType': _sumberBisnis.isEmpty ? 'DIRECT' : _sumberBisnis,
    };
    final subStage = _subStageValue();
    if (subStage != null) body['subStage'] = subStage;
    if (refId != null) body['refId'] = refId;
    if (_statusKerjaSama != 'INDIVIDU') {
      body['parties'] = _parties
          .map(
            (p) => {
              'legalEntity': p.legalEntity,
              'customerName': p.customerName?.trim(),
              'customerId': p.customerId,
            },
          )
          .toList();
    }
    if (_isTender) {
      body['tenderProcesses'] = _tenders
          .map(
            (t) => {
              'processType': t.processType,
              'startDate': _iso(t.start!),
              'endDate': _iso(t.end!),
            },
          )
          .toList();
    }

    final error = await _notifier.save(body);
    if (!mounted) return;
    if (error == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Pipeline berhasil ditambahkan!'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      navigator.pop(true);
    } else {
      warn('Gagal menambah pipeline: $error');
    }
  }
}
