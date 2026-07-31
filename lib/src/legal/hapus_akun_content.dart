/// Naskah halaman permintaan penghapusan akun — **satu-satunya sumber kebenaran**.
///
/// Dulu berkas HTML statis (`web/hapus-akun.html`) yang disajikan nginx. Kini rute
/// Flutter publik [rutePublikHapusAkun], sepola dengan kebijakan privasi: satu
/// jalur render, tidak ada salinan kedua yang bisa menyimpang, dan isinya ikut
/// terbundel ke aplikasi sehingga terbaca tanpa sinyal.
///
/// **Isi harus selalu sejalan dengan bagian 11 kebijakan privasi.** Reviewer
/// membandingkan halaman ini dengan kebijakan privasi, dan perbedaan di antara
/// keduanya adalah salah satu pemicu penolakan. Kalau salah satu diubah, ubah
/// keduanya — `test/src/legal/legal_content_test.dart` menjaga sebagian
/// kesejajaran itu.
///
/// Berkas ini murni Dart, tanpa import Flutter.
library;

import 'kebijakan_privasi_content.dart';
import 'legal_routes.dart';
import 'policy_document.dart';

const String judulHapusAkun = 'Permintaan Penghapusan Akun M-BIS';

const List<PolicySection> hapusAkun = [
  PolicySection('', 'Tentang aplikasi ini', [
    PolicyText(
      'M-BIS (Marketing/Business Information System) adalah aplikasi **internal** '
      '$namaPerusahaan, dipakai pegawai serta Agen dan Tenaga Pemasar resmi. '
      'Aplikasi ini tidak ditujukan untuk masyarakat umum.',
    ),
    PolicyCallout(
      'Akun M-BIS **tidak dibuat sendiri oleh pengguna**. Akun dibuat oleh '
      'Administrator, dan akun Agen didaftarkan oleh Relationship Manager. Karena '
      'itu penghapusan diproses melalui permohonan terverifikasi, bukan tombol '
      'hapus seketika — agar akun tidak dapat dihapus oleh pihak yang bukan '
      'pemiliknya.',
    ),
  ]),

  PolicySection('', 'Cara mengajukan penghapusan', [
    PolicySubheading('Dari dalam aplikasi'),
    PolicyText('Buka **Profil → Privasi & Akun → Ajukan Penghapusan Akun**.'),
    PolicySubheading('Tanpa memasang aplikasi'),
    PolicyText(
      'Kirim surel ke alamat di bawah dengan subjek '
      '**"Permintaan Penghapusan Akun M-BIS"**.',
    ),
    PolicyMailLink(
      'Kirim Permintaan Penghapusan',
      emailPrivasi,
      'Permintaan Penghapusan Akun M-BIS',
    ),
    PolicyText('Atau salin alamat ini: $emailPrivasi'),
    PolicySubheading('Sertakan dalam permohonan Anda'),
    PolicyList(
      [
        'Nama lengkap sesuai yang terdaftar di aplikasi.',
        'NIP (untuk pegawai) atau nomor CIF Agen.',
        'Unit kerja atau kantor cabang.',
        'Alasan permohonan (opsional).',
      ],
      numbered: true,
    ),
    PolicyText(
      'Permohonan diverifikasi dan diproses oleh **Divisi Pengelolaan Jaringan**. '
      'Anda akan menerima konfirmasi melalui surel yang sama setelah penghapusan '
      'dilakukan.',
    ),
  ]),

  PolicySection('', 'Data yang dihapus permanen', [
    PolicyText(
      'Setelah permohonan disetujui, data berikut dihapus dan **tidak dapat '
      'dipulihkan**:',
    ),
    PolicyList([
      'NIP, nama, alamat surel, dan jabatan.',
      'Kata sandi serta seluruh sesi login yang masih berjalan.',
      'Tautan akun Single Sign-On, apabila ada.',
      'Token perangkat untuk notifikasi dan seluruh riwayat notifikasi.',
    ]),
    PolicyText(
      'Apabila akun tidak pernah dipakai membuat catatan apa pun, seluruh datanya '
      'dibuang dari basis data tanpa menyisakan apa-apa.',
    ),
  ]),

  PolicySection('', 'Data yang tetap disimpan', [
    PolicyCallout(
      'Sebagian catatan **wajib diarsipkan** dan tidak dapat ikut dihapus, karena '
      'ketentuan penyimpanan dokumen perusahaan asuransi.',
      warning: true,
    ),
    PolicyText('Yang tetap disimpan:'),
    PolicyList([
      'Catatan pipeline, kunjungan, target, dan serah terima portofolio.',
      'Data komisi, transaksi, dan polis yang telah terbit.',
    ]),
    PolicyText(
      'Catatan tersebut **tidak lagi menunjuk ke identitas Anda** — kaitannya '
      'diputus sehingga tidak dapat dihubungkan kembali ke seorang pengguna.',
    ),
    PolicySubheading('Jangka waktu penyimpanan'),
    PolicyList([
      '**Dokumen dan data keuangan** (komisi, transaksi, polis): 10 tahun sejak '
          'akhir tahun buku, sesuai Undang-Undang No. 8 Tahun 1997 tentang '
          'Dokumen Perusahaan.',
      '**Log aktivitas sistem**: minimal 5 tahun.',
      '**Catatan operasional lain**: mengikuti jadwal retensi dokumen internal '
          'perusahaan.',
    ]),
  ]),

  PolicySection('', 'Hak Anda sebagai subjek data', [
    PolicyText(
      'Sesuai Undang-Undang No. 27 Tahun 2022 tentang Pelindungan Data Pribadi, '
      'Anda berhak memperoleh informasi, mengakses, memperbaiki, menghapus, '
      'membatasi pemrosesan, serta mengajukan keberatan atas pemrosesan data '
      'pribadi Anda. Permohonan penggunaan hak tersebut disampaikan ke kontak '
      'yang sama.',
    ),
    PolicyRouteLink('Baca Kebijakan Privasi', rutePublikKebijakan),
  ]),

  PolicySection('', 'Kontak', [
    PolicyText(
      '**Divisi Pengelolaan Jaringan**\n'
      '$namaPerusahaan\n'
      'Graha Askrindo, Jl. Angkasa Blok B-9 Kav. 8\n'
      'Kota Baru Bandar Kemayoran, Jakarta Pusat 10610\n'
      'Telepon: (021) 6546471 / 6546472\n'
      'Surel: $emailPrivasi',
    ),
  ]),
];
