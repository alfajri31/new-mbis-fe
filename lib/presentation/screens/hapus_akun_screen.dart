import 'package:flutter/material.dart';

import '../../src/legal/hapus_akun_content.dart';
import '../../src/legal/kebijakan_privasi_content.dart' show namaPerusahaan;
import '../widgets/policy_view.dart';

/// Halaman permintaan penghapusan akun.
///
/// Google Play mensyaratkan jalur penghapusan yang dapat diakses **tanpa
/// memasang aplikasi**, dan URL-nya dilampirkan di formulir Data safety. Layar
/// ini dipasang di rute publik `/hapus-akun` yang dikecualikan dari gerbang auth,
/// serta dapat dibuka dari dalam aplikasi lewat kebijakan privasi bagian 11.
///
/// Dulu berkas HTML statis; disatukan ke sini supaya isinya sepola dengan
/// kebijakan privasi dan tidak ada salinan kedua yang bisa menyimpang.
///
/// Layar ini **tidak menyentuh sesi** — pembaca utamanya justru orang yang tidak
/// bisa (atau tidak lagi bisa) login.
class HapusAkunScreen extends StatelessWidget {
  final bool showBack;

  const HapusAkunScreen({super.key, this.showBack = true});

  @override
  Widget build(BuildContext context) {
    return PolicyView(
      appBarTitle: 'Hapus Akun',
      documentTitle: judulHapusAkun,
      subtitle: namaPerusahaan,
      sections: hapusAkun,
      showBack: showBack,
    );
  }
}
