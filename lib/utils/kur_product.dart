/// Apakah kombinasi produk ini tergolong KUR (Kredit Usaha Rakyat).
///
/// CERMIN `TargetCategoryClassifier.baseGroup` di backend, cabang KUR-nya:
/// `toc.equals("KUR") || cob.equals("KREDIT USAHA RAKYAT")`, dengan normalisasi
/// yang sama (trim + huruf besar).
///
/// Klasifikasi backend sengaja mengunci ke NAMA, bukan kode, karena kolom `*_code`
/// di master_products tidak konsisten — kode yang sama dipakai untuk arti berbeda
/// antar baris. Satu-satunya yang stabil: `toc_code` (PK), `lob_name`, `cob_name`.
///
/// Dipakai form pipeline untuk melonggarkan TSI & rate premi pada KUR (CR-05).
/// Kalau aturan KUR di backend berubah, ubah di sini juga — pasangannya dijaga
/// oleh `test/utils/kur_product_test.dart`.
bool isKurProduct({String? tocCode, String? cobName}) {
  final toc = _norm(tocCode);
  final cob = _norm(cobName);
  return toc == 'KUR' || cob == 'KREDIT USAHA RAKYAT';
}

String _norm(String? s) => (s ?? '').trim().toUpperCase();
