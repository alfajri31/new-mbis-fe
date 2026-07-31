import 'package:flutter/material.dart';

import '../../src/legal/kebijakan_privasi_content.dart';
import '../widgets/policy_view.dart';

/// Kebijakan privasi M-BIS.
///
/// Dipasang di **dua rute**:
///
///  - `/profil/privasi/kebijakan` (dan salinan shell Agen) — dibuka pengguna dari
///    dalam aplikasi, dengan tombol kembali;
///  - `/kebijakan-privasi` — rute **publik**, dikecualikan dari gerbang auth,
///    itulah URL yang dilampirkan ke Play Console. Tanpa tombol kembali karena
///    bisa dibuka sebagai tab pertama.
///
/// Naskahnya tidak ditulis di sini melainkan di
/// `src/legal/kebijakan_privasi_content.dart`; tata letaknya di [PolicyView].
/// Pemisahan itu yang membuat halaman publik dan halaman dalam aplikasi mustahil
/// berbeda isi — perbedaan di antara keduanya adalah salah satu yang
/// dibandingkan reviewer Google.
///
/// Layar ini **tidak menyentuh sesi**. Membaca `AuthSession` di sini akan
/// meledak justru pada pembaca yang belum login, yaitu reviewer.
class KebijakanPrivasiScreen extends StatelessWidget {
  final bool showBack;

  const KebijakanPrivasiScreen({super.key, this.showBack = true});

  @override
  Widget build(BuildContext context) {
    return PolicyView(
      appBarTitle: 'Kebijakan Privasi',
      documentTitle: judulKebijakan,
      subtitle: namaPerusahaan,
      meta: const [
        ('Tanggal berlaku', tanggalBerlaku),
        ('Terakhir diperbarui', tanggalPembaruan),
      ],
      banner: kebijakanMasihDraf
          ? 'DRAF — belum disahkan. Naskah ini masih menunggu peninjauan dan '
              'pengesahan Legal, sehingga belum berlaku sebagai kebijakan resmi.'
          : null,
      sections: kebijakanPrivasi,
      showBack: showBack,
    );
  }
}
