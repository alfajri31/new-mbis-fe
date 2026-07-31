/// Rute publik kedua halaman kebijakan.
///
/// Dipisah ke berkas sendiri karena naskah kebijakan privasi menautkan ke halaman
/// hapus akun **dan** sebaliknya. Kalau konstantanya tinggal di berkas naskah
/// masing-masing, keduanya harus saling impor.
///
/// Kedua rute ini **dikecualikan dari gerbang auth** di `src/router.dart` — itu
/// yang membuatnya memenuhi syarat Google Play "dapat dibuka tanpa memasang
/// aplikasi dan tanpa login". Menghapus salah satunya dari daftar pengecualian
/// akan memulangkan reviewer ke layar login; `test/src/router_public_routes_test.dart`
/// menjaganya.
library;

/// Kebijakan privasi. URL publiknya dilampirkan ke kolom kebijakan privasi
/// Play Console.
const String rutePublikKebijakan = '/kebijakan-privasi';

/// Permintaan penghapusan akun. URL publiknya dilampirkan ke kolom
/// *Data deletion URL* di formulir Data safety.
const String rutePublikHapusAkun = '/hapus-akun';

/// Keduanya sekaligus — dipakai gerbang auth dan test.
const Set<String> rutePublikLegal = {rutePublikKebijakan, rutePublikHapusAkun};
