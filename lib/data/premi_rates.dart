/// Premium-calculator product/category catalog — S-109.
///
/// The actual numeric rates ("Rate Produk") used to be hardcoded here, sourced
/// from the internal "Rate Produk" sheet. That data is internal-company
/// confidential and was taken down after piloting feedback. This file only keeps
/// the non-confidential catalog structure (product names, LOB grouping,
/// risk-tier criteria/labels, tenor & jaminan buckets) needed to label the
/// selection and the resulting invoice — no rate number ever returns here.
///
/// Rate-nya sendiri kini datang dari BACKEND (MTR-2): admin mengisinya per slot
/// lewat kalkulator, tersimpan di tabel `premi_rates`, dan pengguna kalkulator
/// menerimanya sebagai angka awal yang boleh ditimpa untuk satu perhitungan
/// (timpaannya tidak disimpan). Slot yang belum diisi admin berperilaku persis
/// seperti sebelumnya: isian kosong, user mengetik sendiri. Kunci slot dibentuk
/// di bagian bawah berkas ini.
///
/// The calculator applies `premi = TSI × rate/100 × (1 − diskon)` using whatever
/// rate is in the field — default dari admin maupun ketikan user.
library;

/// The four top-level buckets a user picks first.
enum PremiCategory { asuransiUmum, suretyBond, kbg, customBond }

extension PremiCategoryLabel on PremiCategory {
  String get label => switch (this) {
        PremiCategory.asuransiUmum => 'Asuransi Umum',
        PremiCategory.suretyBond => 'Surety Bond',
        PremiCategory.kbg => 'KBG',
        PremiCategory.customBond => 'Custom Bond',
      };

  /// Only Asuransi Umum allows a discount input (per calc.md).
  bool get allowsDiscount => this == PremiCategory.asuransiUmum;
}

/// Risk classification for products whose tier label depends on checked
/// criteria (Contractor's All Risk & Machinery Breakdown Industry) — see
/// CAR-MB.png. The actual rate for each tier is entered manually by the user;
/// this only drives the High/Low/Normal tier label shown alongside the input.
class RiskModel {
  /// The three criteria shown as checkboxes.
  final List<String> criteria;

  /// Whether a "Normal" tier exists for 0 checked criteria (MB Industry only).
  /// False for CAR — CAR has no "normal" tier, so 0 criteria → Low Risk.
  final bool hasNormalTier;

  const RiskModel({
    required this.criteria,
    this.hasNormalTier = false,
  });

  /// Human-readable tier name for the result card.
  /// - ≥2 checked            → High
  /// - 0 checked & hasNormalTier → Normal (MB Industry)
  /// - otherwise (1, or 0 for CAR) → Low
  String tierLabel(int checkedCount) {
    if (checkedCount >= 2) return 'High Risk';
    if (checkedCount == 0 && hasNormalTier) return 'Normal';
    return 'Low Risk';
  }

  /// Kode tier untuk kunci slot rate default (MTR-2). Dipisah dari [tierLabel]
  /// dengan sengaja: label boleh diperbaiki kapan saja demi tampilan, sedangkan
  /// kode ini ikut membentuk kunci yang tersimpan di backend — mengubahnya
  /// membuat rate yang sudah diisi admin jadi yatim.
  String tierCode(int checkedCount) {
    if (checkedCount >= 2) return 'HIGH';
    if (checkedCount == 0 && hasNormalTier) return 'NORMAL';
    return 'LOW';
  }
}

/// COB (Class of Business) untuk seluruh produk Asuransi Umum.
const String kCobAsuransiUmum = 'Asuransi Umum';

/// COB untuk produk bond (Surety Bond / KBG / Custom Bond).
const String kCobSuretyship = 'Suretyship';

// LOB (Line of Business) — grup produk untuk invoice. Pemetaan indikatif,
// silakan diverifikasi tim underwriting.
const String kLobEngineering = 'Engineering / Rekayasa';
const String kLobMarineCargo = 'Marine Cargo';
const String kLobMarineHull = 'Marine Hull';
const String kLobOilGas = 'Oil & Gas';
const String kLobAneka = 'Aneka / Harta Benda';
const String kLobLiability = 'Liability / Tanggung Gugat';
const String kLobAviation = 'Aviation';
const String kLobPersonalAccident = 'Personal Accident';

/// A single Asuransi Umum product. [lob] = Line of Business (grup produk untuk
/// invoice); COB semua produk ini = [kCobAsuransiUmum]. [risk] is non-null only
/// for CAR & MB Industry, whose rate tier depends on checked criteria — the
/// rate itself is entered manually by the user.
class UmumProduct {
  final String name;

  /// Line of Business — grup produk (Engineering, Marine Cargo, dst).
  final String lob;

  /// Non-null for CAR & MB Industry; drives the risk-tier label via checked
  /// criteria (rate itself is entered manually).
  final RiskModel? risk;

  const UmumProduct(this.name, {required this.lob, this.risk});
}

/// Asuransi Umum catalog — order follows the sheet. CAR & MB Industry carry a
/// [RiskModel] for the risk-tier label; every product's rate is entered
/// manually by the user.
const List<UmumProduct> kAsuransiUmumProducts = [
  UmumProduct(
    "Contractor's All Risk",
    lob: kLobEngineering,
    risk: RiskModel(
      criteria: [
        'Nilai pertanggungan (TSI) > Rp250 miliar',
        'Durasi proyek > 18 bulan',
        'Complexity project (Dermaga, Power Plant, Bendungan, Kilang, dll)',
      ],
    ),
  ),
  UmumProduct('Erection All Risk', lob: kLobEngineering),
  UmumProduct(
    'Machinery Breakdown (Industry)',
    lob: kLobEngineering,
    risk: RiskModel(
      criteria: [
        'Beban mesin berat (panas tinggi / abrasive dust explosion / bahan kimia)',
        'Operational > 18 jam',
        'Usia mesin > 10 tahun',
      ],
      hasNormalTier: true,
    ),
  ),
  UmumProduct('Machinery Breakdown (Non-Industry)', lob: kLobEngineering),
  UmumProduct('Civil Engineering Completed Risk', lob: kLobEngineering),
  UmumProduct('Electronic Equipment Insurance', lob: kLobEngineering),
  UmumProduct('Contractor Plant & Machinery (All Risk)', lob: kLobEngineering),
  UmumProduct('Contractor Plant & Machinery (Total Loss Only)', lob: kLobEngineering),
  UmumProduct('Heavy Equipment (All Risk)', lob: kLobEngineering),
  UmumProduct('Heavy Equipment (Total Loss Only)', lob: kLobEngineering),
  UmumProduct('Marine Cargo (ICC A)', lob: kLobMarineCargo),
  UmumProduct('Marine Cargo (ICC B)', lob: kLobMarineCargo),
  UmumProduct('Marine Cargo (ICC C)', lob: kLobMarineCargo),
  UmumProduct('Marine Cargo (Air Cargo)', lob: kLobMarineCargo),
  UmumProduct('Marine Cargo (Inland Transit - Impor)', lob: kLobMarineCargo),
  UmumProduct('Marine Cargo (Inland Transit - Domestik)', lob: kLobMarineCargo),
  UmumProduct('Marine Cargo (Open Cover)', lob: kLobMarineCargo),
  UmumProduct('Marine Hull (Kapal Besi)', lob: kLobMarineHull),
  UmumProduct('Marine Hull (Tongkang/LCT/LST/LCM)', lob: kLobMarineHull),
  UmumProduct('Marine Hull (Kapal Kayu)', lob: kLobMarineHull),
  UmumProduct('Marine Hull (Kapal Fiber/Aluminium)', lob: kLobMarineHull),
  UmumProduct("Marine Builder's Risk", lob: kLobMarineCargo),
  UmumProduct('Marine Protection & Indemnity', lob: kLobMarineHull),
  UmumProduct('Oil Gas (Onshore Property)', lob: kLobOilGas),
  UmumProduct('Oil Gas (Offshore Property)', lob: kLobOilGas),
  UmumProduct('Oil Rig Insurance', lob: kLobOilGas),
  UmumProduct('WellCar', lob: kLobOilGas),
  UmumProduct('Cash in Save Bank', lob: kLobAneka),
  UmumProduct('Cash in Save Non Bank', lob: kLobAneka),
  UmumProduct('Cash in Save ATM', lob: kLobAneka),
  UmumProduct('Cash in Transit', lob: kLobAneka),
  UmumProduct('Cash in Save Document', lob: kLobAneka),
  UmumProduct('Fidelity Guarantee', lob: kLobAneka),
  UmumProduct('Burglary & Theft', lob: kLobAneka),
  UmumProduct('Moveable All Risk', lob: kLobAneka),
  UmumProduct('Cyber Insurance', lob: kLobLiability),
  UmumProduct('Public Liability', lob: kLobLiability),
  UmumProduct('Comprehensive General Liability', lob: kLobLiability),
  UmumProduct('Workmen Compensation Act', lob: kLobLiability),
  UmumProduct('Aviation Loss of License', lob: kLobAviation),
  UmumProduct('Professional Indemnity', lob: kLobLiability),
  UmumProduct("Director's & Officer Liability", lob: kLobLiability),
  UmumProduct('Port & Terminal Liability', lob: kLobLiability),
  UmumProduct('Personal Accident', lob: kLobPersonalAccident),
];

/// Tenor buckets shared by all bond tables.
const List<String> kBondTenors = [
  '>0-3 bulan',
  '>3-6 bulan',
  '>6-9 bulan',
  '>9-12 bulan',
];

/// Jenis jaminan for Surety Bond & KBG.
const List<String> kBondJaminan = [
  'Penawaran',
  'Pelaksanaan',
  'Uang Muka',
  'Pemeliharaan',
];

/// Minimum premium (IDR) applied to any bond (surety/KBG/custom) per the
/// suretyship rules ("Minimum premi ... adalah Rp25 ribu").
const double kBondMinPremi = 25000;

/// LOB label untuk kategori bond (dipakai pada invoice).
String bondLob(PremiCategory category) => switch (category) {
      PremiCategory.suretyBond => 'Surety Bond',
      PremiCategory.kbg => 'Kontra Bank Garansi (KBG)',
      PremiCategory.customBond => 'Custom Bond',
      PremiCategory.asuransiUmum => kCobAsuransiUmum,
    };

// ── Kunci slot rate default (MTR-2) ─────────────────────────────────────────
//
// Rate default yang diisi ADMIN disimpan backend per "slot", yaitu satu kombinasi
// pilihan kalkulator yang punya satu angka rate. Kuncinya dibentuk DI SINI karena
// katalognya ada di sini juga — backend hanya menyimpan pasangan kunci→rate dan
// tidak tahu apa-apa soal isi katalog.
//
// Bentuk kunci (tiga bagian, dipisah '|', tanpa spasi tambahan):
//
//   UMUM|<nama produk>|<HIGH|LOW|NORMAL|->   Asuransi Umum
//   SURETY|<jaminan>|<tenor>                 Surety Bond
//   KBG|<jaminan>|<tenor>                    KBG
//   CUSTOM|-|<tenor>                         Custom Bond
//
// Bagian yang tidak berlaku diisi '-' (bukan kosong) supaya jumlah bagiannya
// selalu tiga — backend memagari bentuk itu, dan kunci berbagian kosong akan
// ditolak sebagai "slotKey tidak dikenali".
//
// PERINGATAN: mengubah teks nama produk / label jaminan / label tenor di berkas ini
// akan MENGUBAH KUNCI-nya, dan rate default yang sudah diisi admin untuk nama lama
// jadi yatim (tidak lagi ketemu, tidak error). Kalau suatu saat nama produk direvisi,
// rate-nya harus diisi ulang untuk nama baru.

/// Kode kategori pada kunci slot. Sengaja dipisah dari [PremiCategoryLabel.label]:
/// label boleh diperbaiki kapan saja demi tampilan, kode ini tidak boleh berubah.
extension PremiCategorySlotCode on PremiCategory {
  String get slotCode => switch (this) {
        PremiCategory.asuransiUmum => 'UMUM',
        PremiCategory.suretyBond => 'SURETY',
        PremiCategory.kbg => 'KBG',
        PremiCategory.customBond => 'CUSTOM',
      };
}

/// Bagian kunci yang kosong. Bukan string kosong — lihat catatan di atas.
const String kSlotNone = '-';

/// Kunci slot untuk produk Asuransi Umum. [riskTier] hanya diisi untuk produk
/// ber-[RiskModel] (CAR & MB Industry) — produk lain memakai [kSlotNone].
String premiSlotKeyUmum(String productName, {String? riskTier}) =>
    '${PremiCategory.asuransiUmum.slotCode}|$productName|${riskTier ?? kSlotNone}';

/// Kunci slot untuk bond. Surety & KBG memakai jaminan × tenor; Custom Bond hanya
/// tenor, jadi bagian jaminannya [kSlotNone].
String premiSlotKeyBond(
  PremiCategory category, {
  String? jaminan,
  required String tenor,
}) =>
    '${category.slotCode}|${jaminan ?? kSlotNone}|$tenor';
