/// Bank tempat komisi agen dicairkan — himpunan TERTUTUP, ditetapkan unit bisnis.
///
/// **Bukan diambil dari master `/api/banks`, dan memang tidak boleh.** Master itu
/// berisi 108 bank induk + 23 ribu cabang, dan gunanya memilih cabang bank
/// NASABAH. Rekening komisi agen adalah urusan yang berbeda dengan daftar yang
/// jauh lebih pendek dan dikurasi sendiri. Kalau suatu saat tergoda menyatukan
/// keduanya, tiga hal ini yang akan patah:
///
///  * bentuk namanya beda — master menulis `BANK CENTRAL ASIA (BCA)`, di sini
///    `BANK BCA`;
///  * **SEABANK tidak ada sama sekali** di master, padahal ia salah satu tujuan
///    pencairan yang dipakai;
///  * `BANK SYARIAH INDONESIA` juga belum ada di master — di sana masih tercatat
///    `BANK SYARIAH MANDIRI`, nama sebelum merger.
///
/// Enum, bukan daftar string, supaya himpunannya benar-benar tertutup: menambah
/// bank menjadi keputusan sadar di satu tempat, dan salah ketik tertangkap saat
/// kompilasi alih-alih menjadi baris data yang tak cocok saat komisi dibayarkan.
library;

/// Pilihan bank pencairan komisi agen. Urutan deklarasi = urutan tampil.
enum BankKomisi {
  bca('BANK BCA'),
  bjb('BANK BJB'),
  bni('BANK BNI'),
  bri('BANK BRI'),
  btn('BANK BTN'),
  jateng('BANK JATENG'),
  mandiri('BANK MANDIRI'),
  sumut('BANK SUMUT'),
  syariahIndonesia('BANK SYARIAH INDONESIA'),
  bpdBali('BPD BALI'),
  cimbNiaga('CIMB NIAGA'),
  hanaBank('HANA BANK'),
  seabank('SEABANK');

  const BankKomisi(this.label);

  /// Nama yang ditampilkan DAN yang disimpan ke backend (`agents.bank_name`).
  ///
  /// Karena nilai inilah yang mendarat di basis data, mengganti nama konstanta
  /// Dart-nya aman, tetapi mengubah [label] berarti mengubah data — baris agen
  /// yang sudah tersimpan tidak ikut berubah sendiri.
  final String label;

  /// Anggota yang labelnya sama persis dengan [label], atau null bila tidak ada.
  static BankKomisi? dariLabel(String? label) {
    final nilai = label?.trim() ?? '';
    if (nilai.isEmpty) return null;
    for (final bank in BankKomisi.values) {
      if (bank.label == nilai) return bank;
    }
    return null;
  }
}

/// Label seluruh anggota, urut deklarasi — isi dropdown.
List<String> get labelBankKomisi =>
    BankKomisi.values.map((b) => b.label).toList(growable: false);

/// Opsi yang perlu ditampilkan agar [tersimpan] tidak hilang dari layar.
///
/// Data lama — atau pengajuan yang ditolak lalu dibuka kembali — bisa menyimpan
/// nama bank yang dulu diketik bebas, dan nilai seperti itu tidak akan pernah jadi
/// anggota enum. Nilai begitu ikut ditampilkan sebagai opsi tambahan, karena dua
/// alternatifnya sama-sama buruk: membuangnya diam-diam membuat RM mengira
/// rekeningnya belum pernah diisi, dan meneruskannya apa adanya ke
/// `DropdownButtonFormField` melempar assertion (nilai terpilih wajib ada di
/// antara item).
List<String> opsiBankKomisi(String? tersimpan) {
  final nilai = tersimpan?.trim() ?? '';
  if (nilai.isEmpty || BankKomisi.dariLabel(nilai) != null) {
    return labelBankKomisi;
  }
  return <String>[nilai, ...labelBankKomisi];
}
