/// Merender naskah kebijakan (data terstruktur di `src/legal/`) menjadi HTML
/// mandiri yang disajikan nginx repo INI sebagai halaman publik.
///
/// **Kenapa halaman ini harus HTML statis, bukan cuma rute Flutter.** Rute
/// Flutter publik (`/kebijakan-privasi`, `/hapus-akun`) tetap ada dan tetap
/// dipakai — tombol di layar Privasi & Akun memanggilnya lewat `context.push`.
/// Tapi rute itu hanya terbaca oleh klien yang MENJALANKAN aplikasi: web M-BIS
/// dibangun sebagai SPA WasmGC, sehingga pengambil HTTP biasa hanya menerima
/// cangkang `index.html` tanpa satu kata pun naskah kebijakan. Pemeriksa otomatis
/// Google Play (dan mesin pencari) mengambil URL persis seperti itu — tanpa
/// menjalankan JS/WASM. Halaman yang tampil kosong bagi mereka dianggap sama saja
/// dengan tidak ada kebijakan, dan itu memicu penolakan review.
///
/// Karena itu ada dua penyajian dari SATU naskah:
///   - muat langsung / bot  -> berkas statis di `web/` (dibangkitkan berkas ini),
///     dipetakan nginx ke URL tanpa akhiran `.html`;
///   - navigasi di dalam aplikasi -> layar Flutter, dirender dari naskah Dart.
///
/// **Riwayat, supaya tidak berputar lagi.** Versi HTML pernah dihapus 27 Juli
/// 2026 ("rute Flutter sudah cukup"), lalu dihidupkan lagi 30 Juli 2026 di repo
/// BACKEND karena saat itu web prod direncanakan hidup di IP privat dan hanya
/// backend yang punya alamat publik. Rencana itu tidak jadi dipakai: proxy host
/// kini memetakan `https://mbis.askrindo.co.id/app/` ke web ini, jadi web sudah
/// punya alamat publik sendiri dan halamannya pulang ke repo ini — satu tempat
/// dengan naskahnya, tanpa perlu repo tetangga ter-checkout.
///
/// **Naskahnya tidak disalin.** Berkas ini membaca sumber Dart yang sama dengan
/// yang dirender aplikasi, jadi tetap ada satu naskah. Keluarannya berkas turunan
/// — lihat [bannerGenerated] — dan `test/src/legal/policy_html_drift_test.dart`
/// menolak lulus bila berkas di `web/` tidak lagi sama dengan hasil render ini.
///
/// Berkas ini sengaja di `tool/` (bukan `lib/`) supaya tidak ikut terbundel ke
/// aplikasi. Murni Dart, tanpa import Flutter.
library;

import 'package:mbis/src/legal/hapus_akun_content.dart';
import 'package:mbis/src/legal/kebijakan_privasi_content.dart';
import 'package:mbis/src/legal/legal_routes.dart';
import 'package:mbis/src/legal/policy_document.dart';

/// Folder keluaran: `web/` di repo INI.
///
/// Dulu berupa peta nama-repo-frontend -> folder `legal/` di repo backend
/// pasangannya, karena keluarannya menyeberang repo. Pemetaan itu perlu supaya
/// generator yang dijalankan dari repo produksi tidak diam-diam menulis ke repo
/// staging (keempat repo biasanya ter-checkout bersebelahan, jadi "cari mana yang
/// ada duluan" selalu menemukan yang salah).
///
/// Seluruh persoalan itu hilang begitu keluarannya pindah ke repo sendiri: tidak
/// ada lagi repo tetangga yang bisa tertukar, dan drift test tidak lagi perlu
/// di-skip di CI yang meng-checkout satu repo saja.
///
/// Isi `web/` disalin apa adanya oleh `flutter build web` ke `build/web/`, lalu
/// disajikan nginx — jalur yang sama persis dengan `auth.html`.
const String folderKeluaranWeb = 'web';

/// Ditempel di awal tiap berkas keluaran. Satu-satunya pertahanan terhadap orang
/// yang mengedit HTML-nya langsung lalu heran kenapa perubahannya hilang.
const String bannerGenerated = '''
<!--
  BERKAS TURUNAN — JANGAN DIEDIT TANGAN.

  Dibangkitkan dari naskah Dart di repo ini:
      lib/src/legal/kebijakan_privasi_content.dart
      lib/src/legal/hapus_akun_content.dart

  Cara memperbarui (dari akar repo ini):
      dart run tool/gen_policy_html.dart

  Suntingan langsung di berkas ini akan tertimpa, dan
  test/src/legal/policy_html_drift_test.dart akan gagal lebih dulu.
-->''';

/// Escape karakter yang bermakna di HTML.
///
/// Naskah kebijakan memuat `&`, tanda kutip, dan `<`/`>` (mis. "Profil → Privasi",
/// alamat surel). Tanpa escape, satu karakter saja bisa merusak sisa dokumen —
/// pada halaman yang justru dibaca regulator.
String esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Menerjemahkan `**tebal**` jadi `<strong>`, memakai parser yang SAMA dengan
/// yang dipakai aplikasi (`parseInline`) supaya penegasannya tidak bisa berbeda.
String inline(String source) => parseInline(source)
    .map((s) => s.bold ? '<strong>${esc(s.text)}</strong>' : esc(s.text))
    .join();

/// Rute Flutter -> tautan relatif.
///
/// Relatif, bukan absolut, dan TANPA akhiran `.html`. Kedua halaman disajikan
/// bersebelahan di bawah prefix yang berbeda-beda per environment (`/app/` di
/// prod, akar di staging dan lokal), jadi tautan relatif benar di semua tempat
/// tanpa ada domain atau prefix yang di-hardcode.
///
/// Tanpa `.html` karena nginx memetakan URL bersih itu ke berkasnya (lihat blok
/// `location = /kebijakan-privasi` di `nginx.conf`). Kalau blok nginx itu hilang,
/// tautan silang antar-halaman ikut mati — keduanya satu paket.
String routeHref(String route) => route.startsWith('/') ? route.substring(1) : route;

String _renderBlock(PolicyBlock block) {
  switch (block) {
    case PolicyText(:final text):
      // \n di dalam paragraf dipakai blok alamat -> <br>, sepola dengan PolicyView.
      final body = text.split('\n').map(inline).join('<br>');
      return '    <p>$body</p>';

    case PolicySubheading(:final text):
      return '    <h3>${inline(text)}</h3>';

    case PolicyList(:final items, :final numbered):
      final tag = numbered ? 'ol' : 'ul';
      final li = items.map((i) => '      <li>${inline(i)}</li>').join('\n');
      return '    <$tag>\n$li\n    </$tag>';

    case PolicyTable(:final headers, :final rows):
      final head =
          headers.map((h) => '<th scope="col">${inline(h)}</th>').join();
      final body = rows
          .map((r) =>
              '        <tr>${r.map((c) => '<td>${inline(c)}</td>').join()}</tr>')
          .join('\n');
      // Dibungkus div ber-overflow: tabel tiga kolom tidak muat di layar ponsel,
      // dan reviewer Google membukanya dari ponsel.
      return '    <div class="tabel-scroll">\n'
          '      <table>\n'
          '        <thead><tr>$head</tr></thead>\n'
          '        <tbody>\n$body\n        </tbody>\n'
          '      </table>\n'
          '    </div>';

    case PolicyCallout(:final text, :final warning):
      final kelas = warning ? 'callout callout-warning' : 'callout';
      return '    <div class="$kelas">${inline(text)}</div>';

    case PolicyRouteLink(:final label, :final route):
      return '    <p><a class="tombol" href="${esc(routeHref(route))}">'
          '${esc(label)}</a></p>';

    case PolicyMailLink(:final label, :final email, :final subject):
      final href = 'mailto:${Uri.encodeComponent(email)}'
          '?subject=${Uri.encodeQueryComponent(subject)}';
      return '    <p><a class="tombol" href="${esc(href)}">${esc(label)}</a></p>';
  }
}

String _renderSection(PolicySection s) {
  final blocks = s.blocks.map(_renderBlock).join('\n');
  return '  <section>\n'
      '    <h2>${esc(stripInline(s.heading))}</h2>\n'
      '$blocks\n'
      '  </section>';
}

/// CSS ditulis inline — halaman ini harus tampil utuh di balik proxy korporat,
/// tanpa CDN, tanpa font eksternal, dan tanpa aset lain yang bisa gagal dimuat.
/// Halaman yang tampil rusak dianggap sama saja dengan halaman yang tidak ada.
const String _css = '''
  :root { color-scheme: light dark; }
  * { box-sizing: border-box; }
  body {
    margin: 0; padding: 24px 16px 64px;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
    line-height: 1.6; color: #1a2233; background: #f4f6fa;
  }
  main { max-width: 820px; margin: 0 auto; }
  header.doc { margin-bottom: 24px; }
  h1 { font-size: 1.6rem; margin: 0 0 4px; }
  .subtitle { margin: 0 0 12px; color: #4a5568; }
  .meta { margin: 0; color: #64748b; font-size: 0.9rem; }
  section {
    background: #fff; border-radius: 12px; padding: 20px 22px; margin-bottom: 16px;
    box-shadow: 0 1px 2px rgba(16, 24, 40, 0.06);
  }
  h2 { font-size: 1.1rem; color: #14406b; margin: 0 0 12px; }
  h3 { font-size: 0.98rem; margin: 18px 0 6px; }
  p { margin: 0 0 12px; }
  ul, ol { margin: 0 0 12px; padding-left: 22px; }
  li { margin-bottom: 6px; }
  .callout {
    border-left: 4px solid #14406b; background: #eef3f9;
    padding: 12px 14px; border-radius: 6px; margin: 0 0 12px;
  }
  .callout-warning { border-left-color: #b45309; background: #fdf5e6; }
  .tabel-scroll { overflow-x: auto; margin: 0 0 12px; }
  table { border-collapse: collapse; width: 100%; min-width: 460px; font-size: 0.94rem; }
  th, td { border: 1px solid #dfe5ee; padding: 8px 10px; text-align: left; vertical-align: top; }
  th { background: #eef3f9; }
  a { color: #14406b; }
  a.tombol {
    display: inline-block; padding: 10px 16px; border-radius: 8px;
    background: #14406b; color: #fff; text-decoration: none; font-weight: 600;
  }
  .banner {
    border-left: 4px solid #b45309; background: #fdf5e6;
    padding: 12px 14px; border-radius: 6px; margin: 0 0 16px; font-weight: 600;
  }
  @media (prefers-color-scheme: dark) {
    body { background: #0f1620; color: #e6ebf2; }
    section { background: #172231; box-shadow: none; }
    h2 { color: #8ab4e8; }
    .subtitle, .meta { color: #9fb0c4; }
    .callout { background: #1d2b3d; border-left-color: #8ab4e8; }
    .callout-warning { background: #35291a; border-left-color: #d99a3a; }
    th { background: #1d2b3d; }
    th, td { border-color: #2b3a4d; }
    a { color: #8ab4e8; }
    a.tombol { background: #2b5f9e; color: #fff; }
  }
''';

/// Merender satu dokumen kebijakan jadi halaman HTML utuh.
String renderPolicyHtml({
  required String pageTitle,
  required String documentTitle,
  required String subtitle,
  required List<(String, String)> meta,
  required String? banner,
  required List<PolicySection> sections,
}) {
  final metaHtml = meta.isEmpty
      ? ''
      : '    <p class="meta">${meta.map((m) => '${esc(m.$1)}: ${esc(m.$2)}').join('<br>')}</p>\n';
  final bannerHtml =
      banner == null ? '' : '  <div class="banner">${inline(banner)}</div>\n';
  final body = sections.map(_renderSection).join('\n');

  return '''$bannerGenerated
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="index, follow">
<title>${esc(pageTitle)} — ${esc(subtitle)}</title>
<style>
$_css</style>
</head>
<body>
<main>
  <header class="doc">
    <h1>${esc(documentTitle)}</h1>
    <p class="subtitle">${esc(subtitle)}</p>
$metaHtml  </header>
$bannerHtml$body
</main>
</body>
</html>
''';
}

/// Kebijakan privasi — header disamakan dengan `KebijakanPrivasiScreen`.
String renderKebijakanPrivasiHtml() => renderPolicyHtml(
      pageTitle: 'Kebijakan Privasi',
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
    );

/// Permintaan penghapusan akun — header disamakan dengan `HapusAkunScreen`.
String renderHapusAkunHtml() => renderPolicyHtml(
      pageTitle: 'Hapus Akun',
      documentTitle: judulHapusAkun,
      subtitle: namaPerusahaan,
      meta: const [],
      banner: null,
      sections: hapusAkun,
    );

/// Nama berkas keluaran, dipakai generator DAN test drift.
/// Kuncinya sengaja rute publik Flutter supaya keduanya mustahil berbeda.
const Map<String, String> berkasKeluaran = {
  rutePublikKebijakan: 'kebijakan-privasi.html',
  rutePublikHapusAkun: 'hapus-akun.html',
};

/// Isi HTML per rute publik.
Map<String, String> renderSemuaHalaman() => {
      rutePublikKebijakan: renderKebijakanPrivasiHtml(),
      rutePublikHapusAkun: renderHapusAkunHtml(),
    };
