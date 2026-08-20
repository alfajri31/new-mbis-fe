/// Aturan "isian nilai pipeline masih kurang atau tidak" untuk TSI/Plafond dan
/// Rate Premi.
///
/// **Kenapa dipisah ke sini.** Aturannya dulu ditulis dua kali di
/// `add_pipeline_screen.dart`: sekali pada `validator` masing-masing isian, dan
/// sekali lagi pada `_missingRequiredFields()` yang dipanggil `_handleSubmit`
/// sebelum form divalidasi. Saat CR-05 dikerjakan, hanya salinan pertama yang
/// diperbaiki. Akibatnya layar sudah menjanjikan "Untuk KUR, TSI dan rate premi
/// boleh diisi 0 dulu", tetapi menyimpannya tetap ditolak dengan "2 isian wajib
/// belum lengkap" karena salinan kedua masih memakai `<= 0` tanpa pengecualian.
/// Ditemukan saat SIT 20 Agustus 2026 (TC-16).
///
/// Sekarang pemeriksaan sebelum simpan memakai fungsi di berkas ini, dan
/// aturannya bisa dikunci tes tanpa perlu merender seluruh formulir. Validator
/// tiap isian tetap ditulis terpisah karena pesannya berbeda antara "kosong" dan
/// "nol", tetapi keputusannya harus selalu sama dengan fungsi di sini.
///
/// **Aturannya.** Isian KOSONG selalu kurang, termasuk untuk KUR — supaya angka
/// 0 tetap pilihan sadar dan bukan kolom yang terlewat. Nilai 0 diterima hanya
/// untuk produk KUR, karena TSI dan ratenya memang sering belum keluar saat RM
/// mencatat pipelinenya, lalu diedit setelah nilainya turun.
library;

/// True bila isian TSI/Plafond belum memenuhi syarat simpan.
///
/// [teks] diambil apa adanya dari controller, termasuk pemisah ribuan.
bool tsiBelumLengkap({required String teks, required bool isKur}) {
  final digits = teks.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return true;
  if (isKur) return false;
  return int.parse(digits) <= 0;
}

/// True bila isian Rate Premi belum memenuhi syarat simpan.
///
/// Rate di atas 100 persen ditangani terpisah oleh pemanggil karena pesannya
/// berbeda ("maksimal 100%"), bukan "belum lengkap".
bool rateBelumLengkap({required String teks, required bool isKur}) {
  final nilai = double.tryParse(teks.trim());
  if (nilai == null) return true;
  if (isKur) return false;
  return nilai <= 0;
}
