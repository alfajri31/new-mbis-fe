/// Naskah kebijakan privasi M-BIS — **satu-satunya sumber kebenaran**.
///
/// Dirender oleh `KebijakanPrivasiScreen`, yang dipasang di dua rute: di dalam
/// aplikasi (`/profil/privasi/kebijakan`) dan sebagai rute **publik**
/// `/kebijakan-privasi` yang dapat dibuka tanpa login — URL yang dilampirkan ke
/// Play Console.
///
/// Sebelumnya naskah ini juga dibangkitkan jadi HTML statis supaya URL publiknya
/// tidak bergantung pada Flutter. Itu dibatalkan: rute Flutter yang dikecualikan
/// dari gerbang auth sudah memenuhi syarat Google, dan satu jalur render berarti
/// tidak ada salinan kedua yang bisa menyimpang — sehingga generator, halaman
/// HTML, dan test drift-nya tidak lagi diperlukan.
///
/// Berkas ini **murni Dart** (tanpa import Flutter) supaya isinya bisa diperiksa
/// test tanpa membangun widget. Model dokumennya di `policy_document.dart`.
///
/// Naskahnya berasal dari `../draft-kebijakan-privasi.md` di umbrella repo.
/// Catatan internal untuk Legal/IT di draft itu **sengaja tidak ikut** ke sini
/// (daftar persisnya di `docs/HALAMAN-KEBIJAKAN-PUBLIK.md`).
library;

import 'legal_routes.dart';
import 'policy_document.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Status pengesahan
// ─────────────────────────────────────────────────────────────────────────────

/// Naskah ini masih **draf** sampai Legal Askrindo mengesahkannya.
///
/// Selama `true`, kedua halaman menampilkan spanduk peringatan dan
/// `scripts/build-aab.*` menolak membangun rilis produksi. Menerbitkan draf
/// sebagai kebijakan resmi adalah risiko hukum, sedangkan draf yang diam-diam
/// terlihat seperti final adalah risiko yang lebih buruk lagi — karena tidak ada
/// yang sadar ia belum ditinjau.
///
/// Saat disahkan: setel `false`, lalu isi [tanggalBerlaku] dan [tanggalPembaruan].
const bool kebijakanMasihDraf = false;

/// Tanggal kebijakan mulai berlaku.
///
/// Tanggal ini **tercetak di kebijakan yang terbit**, jadi ia harus sama dengan
/// tanggal pengesahan yang sebenarnya. Kalau jadwal Legal bergeser, perbarui di
/// sini lebih dulu — bukan biarkan halaman menyatakan tanggal yang tidak pernah
/// terjadi.
const String tanggalBerlaku = '3 Agustus 2026';

/// Tanggal revisi terakhir. Diisi bersamaan dengan [tanggalBerlaku].
const String tanggalPembaruan = '3 Agustus 2026';

// ─────────────────────────────────────────────────────────────────────────────
// Naskah
// ─────────────────────────────────────────────────────────────────────────────

const String judulKebijakan = 'Kebijakan Privasi M-BIS';
const String namaPerusahaan = 'PT Asuransi Kredit Indonesia (Persero)';
const String emailPrivasi = 'alfian.yoripta@askrindo.co.id';

const List<PolicySection> kebijakanPrivasi = [
  PolicySection('1', 'Pengendali Data', [
    PolicyText(
      'Kebijakan privasi ini mengatur pemrosesan data pribadi dalam aplikasi '
      '**M-BIS (Marketing/Business Information System)** yang dikelola oleh:',
    ),
    PolicyText(
      '**PT Asuransi Kredit Indonesia (Persero)**\n'
      'Graha Askrindo, Jl. Angkasa Blok B-9 Kav. 8,\n'
      'Kota Baru Bandar Kemayoran, Jakarta Pusat 10610\n'
      'Telepon: (021) 6546471 / 6546472',
    ),
    PolicyText(
      'Kontak urusan data pribadi / Pejabat Pelindungan Data: $emailPrivasi',
    ),
  ]),

  PolicySection('2', 'Cakupan dan Pengguna Aplikasi', [
    PolicyText(
      'M-BIS adalah aplikasi **internal** untuk pengguna resmi Askrindo, dengan '
      'peran: Divisi Penjaminan (DPJ), Regional Office (RO), Branch Manager (BM), '
      'Kepala Unit Penjaminan (KUP), Relationship Manager (RM), Agen, dan '
      'Administrator. Aplikasi ini **tidak ditujukan untuk masyarakat umum atau '
      'nasabah akhir**, dan **tidak menyediakan pendaftaran akun mandiri** — '
      'seluruh akun dibuat oleh Administrator, sedangkan akun Agen didaftarkan '
      'oleh RM.',
    ),
    PolicyText('Aplikasi memproses tiga kelompok subjek data:'),
    PolicyList([
      '**Pengguna internal** (pegawai Askrindo yang login).',
      '**Agen dan Tenaga Pemasar (TPM)** — mitra yang juga merupakan pengguna '
          'aplikasi, dan datanya diadministrasikan lebih rinci karena keperluan '
          'lisensi dan komisi.',
      '**Nasabah/calon nasabah** yang datanya dikelola pengguna dalam '
          'menjalankan tugas.',
    ]),
  ]),

  PolicySection('3', 'Data Pribadi yang Kami Kumpulkan', [
    PolicySubheading('3.1 Data pengguna internal (pegawai)'),
    PolicyList([
      '**Identitas & akun kerja:** NIP, nama, alamat email kerja, jabatan, '
          'peran, dan penempatan kantor.',
      '**Kredensial:** masuk aplikasi menggunakan NIP dan kata sandi. Kata sandi '
          'tidak pernah disimpan dalam bentuk aslinya — yang disimpan adalah '
          'hash bcrypt yang bersifat searah dan tidak dapat dikembalikan '
          'menjadi kata sandi semula. Disimpan pula waktu penggantian kata sandi '
          'terakhir dan penanda wajib ganti kata sandi.',
      '**Catatan aktivitas akun:** waktu login terakhir dan status keaktifan akun.',
      '**Data lokasi presisi (GPS):** dikumpulkan **hanya ketika pengguna secara '
          'aktif merekam kegiatan kunjungan**. Aplikasi **tidak** mengumpulkan '
          'lokasi di latar belakang — izin lokasi latar belakang tidak diminta '
          'sama sekali.',
      '**Foto dan berkas:** foto yang diambil langsung dari kamera saat '
          'mendokumentasikan kegiatan, serta dokumen (PDF/JPG/PNG) yang dipilih '
          'pengguna melalui pemilih berkas sistem. Aplikasi tidak menelusuri '
          'galeri foto perangkat.',
      '**Token perangkat untuk notifikasi:** pengenal perangkat (push token) '
          'untuk pengiriman notifikasi melalui Firebase Cloud Messaging.',
    ]),
    PolicyCallout(
      'Autentikasi tunggal (SSO) Microsoft Entra ID **sedang disiapkan dan belum '
      'aktif**. Selama belum diaktifkan, tidak ada data akun yang mengalir ke '
      'Microsoft. Kebijakan ini akan diperbarui lebih dahulu sebelum SSO '
      'dinyalakan, karena penyalaannya menambah penerima data baru.',
    ),
    PolicySubheading('3.2 Data Agen dan Tenaga Pemasar'),
    PolicyText(
      'Karena keperluan lisensi keagenan dan pembayaran komisi, data Agen '
      'diadministrasikan lebih luas daripada data pegawai:',
    ),
    PolicyList([
      '**Identitas:** nama, nomor KTP, tanggal lahir, jenis kelamin, NPWP.',
      '**Alamat:** alamat sesuai KTP secara lengkap (provinsi, kota/kabupaten, '
          'kecamatan, kelurahan, RT/RW) dan alamat domisili apabila berbeda.',
      '**Kontak:** nomor telepon dan alamat email.',
      '**Data keuangan:** nama bank dan nomor rekening untuk keperluan '
          'pencairan komisi.',
      '**Data kemitraan:** nomor dan masa berlaku lisensi, nomor dan periode '
          'Perjanjian Kerja Sama (PKS), serta dokumen pendukung yang diunggah '
          '(mis. pakta integritas).',
    ]),
    PolicySubheading('3.3 Data nasabah/calon nasabah'),
    PolicyText(
      'Dalam menjalankan tugasnya, pengguna memasukkan dan mengelola data berikut:',
    ),
    PolicyList([
      'Nama dan bentuk badan usaha, kategori entitas, nomor CIF.',
      '**NIK** (untuk nasabah perorangan), **NPWP**, dan **NIB**.',
      'Alamat, alamat surel dan nomor telepon perusahaan.',
      'Titik koordinat lokasi usaha (garis lintang dan bujur).',
      'Nama, nomor telepon, dan jabatan narahubung (PIC).',
      'Penanda status internal, termasuk status daftar hitam dan penanda '
          'nasabah bernilai tinggi.',
      'Catatan kunjungan, riwayat pipeline, estimasi premi, dan dokumen yang '
          'diunggah.',
    ]),
  ]),

  PolicySection('4', 'Tujuan dan Dasar Hukum Pemrosesan', [
    PolicyText(
      'Kami memproses data pribadi untuk tujuan: autentikasi dan pengendalian '
      'akses berbasis peran serta kantor; pengelolaan pipeline, kunjungan, dan '
      'analisis kinerja pemasaran; verifikasi lokasi kegiatan; administrasi '
      'keagenan dan pembayaran komisi; serta pengiriman notifikasi operasional.',
    ),
    PolicyText('**Dasar hukum pemrosesan** (Pasal 20 UU PDP):'),
    PolicyTable(
      ['Kelompok data', 'Dasar hukum'],
      [
        [
          'Data pengguna internal (pegawai)',
          'Pemenuhan kewajiban dalam **hubungan kerja**',
        ],
        [
          'Data Agen/TPM',
          'Pelaksanaan **perjanjian kerja sama** yang menjadikan subjek data '
              'sebagai pihak',
        ],
        [
          'Data nasabah/calon nasabah',
          '**Kepentingan sah pengendali** dalam menjalankan kegiatan usaha '
              'penjaminan dan asuransi, serta **pemenuhan kewajiban hukum** di '
              'sektor jasa keuangan',
        ],
      ],
    ),
  ]),

  PolicySection('5', 'Berbagi Data dengan Pihak Ketiga', [
    PolicyText(
      'Aplikasi dan basis datanya berjalan pada **infrastruktur penyedia layanan '
      'di Indonesia**, dan seluruh berkas unggahan (foto kunjungan, dokumen '
      'nasabah) disimpan pada layanan object storage penyedia yang sama. '
      'Penyedia bertindak sebagai **pemroses data** — mereka menyediakan server '
      'dan penyimpanan, tidak menggunakan data M-BIS untuk kepentingan sendiri, '
      'dan terikat ketentuan layanan yang berlaku.',
    ),
    PolicyText('Pihak ketiga yang terlibat:'),
    PolicyTable(
      ['Pihak ketiga', 'Untuk apa', 'Data yang keluar'],
      [
        [
          '**Penyedia infrastruktur** (server & object storage, di Indonesia)',
          'Menjalankan aplikasi, basis data, dan penyimpanan berkas',
          'Seluruh data aplikasi tersimpan pada infrastruktur mereka',
        ],
        [
          '**Microsoft** (Entra ID)',
          'Autentikasi SSO — **belum aktif**, lihat bagian 3.1',
          'Identitas akun kerja, begitu SSO diaktifkan',
        ],
        [
          '**Google** (Firebase Cloud Messaging)',
          'Pengiriman notifikasi',
          'Token perangkat **dan isi notifikasi**, yang dapat memuat nama orang '
              '(mis. pemberitahuan lisensi agen akan berakhir). Isi ini dapat '
              'tampil di layar kunci perangkat',
        ],
        [
          '**Google** (Firebase Crashlytics)',
          'Pelaporan kerusakan aplikasi',
          'Jenis galat, jejak kesalahan teknis, model perangkat, versi sistem '
              'operasi, dan id akun (bukan nama, NIP, atau surel). Tidak memuat '
              'data nasabah',
        ],
        [
          '**Google** (Gemini)',
          'Fitur Asisten AI',
          'Lihat rincian di bagian 6',
        ],
        [
          '**OpenStreetMap**',
          'Ubin peta di dalam aplikasi',
          'Alamat IP perangkat dan area peta yang sedang dilihat',
        ],
        [
          '**Portal Fintrack**',
          'Pencairan komisi, diproses di luar aplikasi ini',
          'Berlaku kebijakan privasi Fintrack saat pengguna membukanya',
        ],
      ],
    ),
    PolicyText(
      'Kami **tidak menjual data pribadi**, dan tidak menyerahkan data kepada '
      'pihak ketiga untuk kepentingan mereka sendiri. Aplikasi **tidak memuat** '
      'perangkat analitik penggunaan, periklanan, maupun pelacakan lintas '
      'aplikasi.',
    ),
  ]),

  PolicySection('6', 'Fitur Asisten AI', [
    PolicyText(
      'M-BIS menyediakan fitur Asisten AI yang membantu pengguna menganalisis '
      'calon nasabah dan menyarankan produk. Untuk menjalankannya, sebagian data '
      'dikirim ke penyedia model bahasa pihak ketiga, yaitu **Google (Gemini)**. '
      'Hanya penyedia inilah yang disetujui dan diaktifkan; sistem menolak '
      'mengaktifkan penyedia lain.',
    ),
    PolicyText('**Data yang dikirim** ketika pengguna menjalankan aktivitas AI:'),
    PolicyList([
      'Nama nasabah, bentuk badan usaha, kategori entitas, dan status BUMN.',
      'Alamat/lokasi nasabah.',
      'Catatan kunjungan yang telah dicatat pengguna.',
      'Katalog produk Askrindo sebagai rujukan.',
    ]),
    PolicyText(
      '**Data yang tidak pernah dikirim:** NIK, NPWP, NIB, nomor telepon, alamat '
      'surel, nomor rekening, dan dokumen yang diunggah.',
    ),
    PolicyCallout(
      '**Aktivitas dengan pencarian web.** Sebagian aktivitas AI melakukan riset '
      'di internet mengenai calon nasabah. Pada aktivitas jenis ini, nama '
      'nasabah menjadi bagian dari kueri pencarian, sehingga dapat diterima '
      'mesin pencari. Sebagai pengamanan tambahan, alamat nasabah tidak '
      'disertakan pada aktivitas berjenis pencarian web.',
      warning: true,
    ),
    PolicyText(
      '**Pembatasan yang diterapkan:** hanya penyedia yang telah disetujui secara '
      'resmi yang boleh diaktifkan Administrator; jumlah pemakaian AI dibatasi '
      'per pengguna per hari; dan hasil AI disimpan sebagai rangkuman pada data '
      'nasabah yang bersangkutan.',
    ),
    PolicyText(
      'Ketentuan perlindungan data Google Gemini telah ditinjau Askrindo sebelum '
      'fitur ini diaktifkan.',
    ),
  ]),

  PolicySection('7', 'Transfer Data ke Luar Wilayah Indonesia', [
    PolicyText(
      'Server dan penyimpanan berkas M-BIS berada **di wilayah Indonesia**, '
      'sehingga data inti aplikasi tidak ditransfer ke luar negeri. Transfer '
      'lintas negara hanya terjadi pada layanan pihak ketiga di bagian 5 dan 6, '
      'yaitu Microsoft dan Google, yang dapat memproses data pada server di luar '
      'Indonesia.',
    ),
    PolicyText(
      'Sesuai Pasal 56 UU PDP, transfer tersebut dilakukan dengan dasar adanya '
      'perjanjian dan komitmen perlindungan data yang mengikat dari penyedia '
      'layanan, yang telah ditinjau Askrindo sebelum layanan diaktifkan.',
    ),
  ]),

  PolicySection('8', 'Penyimpanan dan Retensi Data', [
    PolicyText(
      'Token sesi disimpan secara aman di perangkat menggunakan penyimpanan '
      'terenkripsi sistem operasi (Android Keystore / iOS Keychain), bukan '
      'sebagai teks biasa. Pencadangan otomatis data aplikasi ke layanan awan '
      'dan pemindahan antarperangkat dinonaktifkan, sehingga data aplikasi tidak '
      'dapat diekstraksi melalui fitur pencadangan perangkat.',
    ),
    PolicyText('**Periode retensi di server:**'),
    PolicyTable(
      ['Jenis data', 'Retensi', 'Dasar'],
      [
        [
          'Akun pengguna',
          '**Dinonaktifkan paling lambat 30 hari** sejak berakhirnya hubungan '
              'kerja atau kemitraan',
          'Kebijakan internal',
        ],
        [
          'Log aktivitas sistem / audit',
          '**Minimal 5 tahun**',
          'Kebijakan internal',
        ],
        [
          'Dokumen dan data keuangan (komisi, transaksi, polis)',
          '**10 tahun** sejak akhir tahun buku',
          'UU No. 8/1997 tentang Dokumen Perusahaan',
        ],
        [
          'Data keagenan (lisensi, PKS)',
          'Selama kemitraan berjalan, lalu mengikuti jadwal retensi dokumen '
              'internal',
          'Kebijakan internal',
        ],
        [
          'Data nasabah, pipeline, dan kunjungan',
          'Mengikuti jadwal retensi dokumen internal perusahaan',
          'Kebijakan internal',
        ],
      ],
    ),
  ]),

  PolicySection('9', 'Keamanan Data', [
    PolicyText('Langkah pengamanan yang diterapkan:'),
    PolicyList([
      'Autentikasi berbasis token dengan masa berlaku terbatas.',
      'Pembatasan akses data per kantor dan per peran, **dipaksakan di sisi '
          'server** — penyaringan dari aplikasi klien tidak dipercaya begitu saja.',
      'Pembatasan laju percobaan login untuk menghambat penebakan kata sandi.',
      'Komunikasi terenkripsi HTTPS; aplikasi versi produksi menolak koneksi '
          'tanpa enkripsi sepenuhnya.',
      'Penyimpanan token terenkripsi di perangkat (Android Keystore / iOS '
          'Keychain).',
      'Pencadangan awan dan pemindahan data antarperangkat dinonaktifkan.',
      'Pembatasan penyedia AI yang boleh diaktifkan, serta penyaringan data yang '
          'dikirim ke layanan AI (bagian 6).',
    ]),
  ]),

  PolicySection('10', 'Hak Anda sebagai Subjek Data (UU PDP)', [
    PolicyText(
      'Sesuai UU PDP No. 27/2022, Anda berhak untuk: memperoleh informasi, '
      'mengakses, memperbaiki, menghapus, menarik persetujuan, membatasi '
      'pemrosesan, mengajukan keberatan atas pengambilan keputusan otomatis, '
      'serta menuntut ganti rugi.',
    ),
    PolicyText(
      'Permohonan penggunaan hak disampaikan ke unit pada bagian 12.',
    ),
  ]),

  PolicySection('11', 'Penghapusan Akun dan Data', [
    PolicyText(
      'Akun M-BIS dibuat dan dikelola oleh Administrator; **tidak ada pendaftaran '
      'akun mandiri di dalam aplikasi**. Karena itu penghapusan akun diproses '
      'melalui permohonan terverifikasi, bukan tombol hapus seketika — '
      'penghapusan sepihak dari perangkat akan memutus catatan kegiatan yang '
      'masih dipakai unit kerja lain.',
    ),
    PolicySubheading('Cara mengajukan'),
    PolicyList(
      [
        'Dari dalam aplikasi: **Profil → Privasi & Akun → Ajukan Penghapusan Akun**.',
        'Tanpa memasang aplikasi: melalui tautan web di bawah.',
      ],
      numbered: true,
    ),
    PolicyText(
      'Permohonan diproses oleh **Divisi Pengelolaan Jaringan** selaku '
      'Administrator sistem.',
    ),
    PolicyRouteLink(
        'Buka halaman permintaan penghapusan akun', rutePublikHapusAkun),
    PolicySubheading('Data yang dihapus permanen dan tidak dapat dipulihkan'),
    PolicyList([
      'NIP, nama, alamat surel, dan jabatan.',
      'Kata sandi dan seluruh sesi login yang masih berjalan.',
      'Tautan akun SSO.',
      'Token perangkat untuk notifikasi dan seluruh riwayat notifikasi.',
    ]),
    PolicyText(
      'Apabila akun tidak pernah dipakai membuat catatan apa pun, seluruh '
      'barisnya dibuang dari basis data tanpa menyisakan apa-apa.',
    ),
    PolicySubheading('Data yang tetap disimpan'),
    PolicyCallout(
      'Sebagian catatan **wajib diarsipkan** dan tidak dapat ikut dihapus, karena '
      'ketentuan penyimpanan dokumen perusahaan asuransi.',
      warning: true,
    ),
    PolicyText(
      'Yang tetap disimpan: catatan pipeline, kunjungan, target, serah terima RM, '
      'komisi, dan transaksi yang telah tercatat, karena kewajiban penyimpanan '
      'dokumen perusahaan dan ketentuan sektor jasa keuangan. Catatan tersebut '
      '**tidak lagi menunjuk ke identitas Anda** — kaitannya diputus, sehingga '
      'tidak dapat lagi dihubungkan kembali ke seorang pengguna. Jangka waktu '
      'penyimpanannya mengikuti bagian 8.',
    ),
  ]),

  PolicySection('12', 'Kontak', [
    PolicyText(
      'Untuk pertanyaan terkait kebijakan ini, penggunaan hak sebagai subjek '
      'data, atau permohonan penghapusan akun:',
    ),
    PolicyText(
      '**Divisi Pengelolaan Jaringan — $namaPerusahaan**\n'
      'Graha Askrindo, Jl. Angkasa Blok B-9 Kav. 8,\n'
      'Kota Baru Bandar Kemayoran, Jakarta Pusat 10610\n'
      'Email: $emailPrivasi\n'
      'Telepon: (021) 6546471 / 6546472\n'
      'Situs: www.askrindo.co.id',
    ),
  ]),

  PolicySection('13', 'Perubahan atas Kebijakan Ini', [
    PolicyText(
      'Kami dapat memperbarui kebijakan ini dari waktu ke waktu. Perubahan '
      'material akan diberitahukan melalui aplikasi dan/atau kanal resmi. '
      'Tanggal "Terakhir diperbarui" di atas menunjukkan versi yang berlaku.',
    ),
  ]),
];
