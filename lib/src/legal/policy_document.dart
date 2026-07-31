/// Model dokumen kebijakan — dipakai kebijakan privasi **dan** halaman
/// permintaan penghapusan akun.
///
/// Kedua halaman itu harus dapat dibuka **tanpa login** (syarat Google Play) dan
/// dari dalam aplikasi. Karena keduanya dirender oleh rute Flutter yang sama-sama
/// publik, naskahnya cukup ditulis sebagai data terstruktur di sini lalu dirender
/// satu kali oleh `PolicyView`.
///
/// Berkas ini **murni Dart** — tanpa import Flutter — supaya isi naskah bisa
/// diperiksa test tanpa membangun widget.
library;

/// Satu bagian dokumen. [number] boleh kosong untuk dokumen yang bagiannya tidak
/// bernomor (mis. halaman hapus akun).
class PolicySection {
  final String number;
  final String title;
  final List<PolicyBlock> blocks;

  const PolicySection(this.number, this.title, this.blocks);

  /// Judul siap tampil: "5. Berbagi Data" atau "Kontak" bila tanpa nomor.
  String get heading => number.isEmpty ? title : '$number. $title';
}

/// Satu potong isi di dalam sebuah [PolicySection].
///
/// Sengaja `sealed`: menambah jenis blok baru akan membuat renderer gagal
/// kompilasi sampai ia ditangani, sehingga tidak ada blok yang diam-diam tidak
/// tampil.
sealed class PolicyBlock {
  const PolicyBlock();
}

/// Paragraf. `\n` di dalamnya jadi pindah baris (dipakai blok alamat).
class PolicyText extends PolicyBlock {
  final String text;
  const PolicyText(this.text);
}

/// Sub-judul di dalam bagian (mis. "3.1 Data pengguna internal").
class PolicySubheading extends PolicyBlock {
  final String text;
  const PolicySubheading(this.text);
}

/// Daftar berpoin, atau bernomor bila [numbered].
class PolicyList extends PolicyBlock {
  final List<String> items;
  final bool numbered;
  const PolicyList(this.items, {this.numbered = false});
}

/// Tabel. Di layar sempit renderer memecahnya jadi kartu per baris — tabel tiga
/// kolom tidak terbaca di ponsel.
class PolicyTable extends PolicyBlock {
  final List<String> headers;
  final List<List<String>> rows;
  const PolicyTable(this.headers, this.rows);
}

/// Kotak sorot. [warning] untuk hal yang merugikan pengguna bila terlewat.
class PolicyCallout extends PolicyBlock {
  final String text;
  final bool warning;
  const PolicyCallout(this.text, {this.warning = false});
}

/// Tombol yang membuka rute lain di dalam aplikasi.
///
/// Rute, bukan URL: kedua halaman kebijakan kini rute Flutter publik, jadi
/// tautannya tidak perlu tahu domain final dan tetap bekerja luring di mobile.
class PolicyRouteLink extends PolicyBlock {
  final String label;
  final String route;
  const PolicyRouteLink(this.label, this.route);
}

/// Tombol yang membuka aplikasi surel.
class PolicyMailLink extends PolicyBlock {
  final String label;
  final String email;
  final String subject;
  const PolicyMailLink(this.label, this.email, this.subject);
}

/// Sepotong teks dengan satu tingkat penegasan.
class InlineSegment {
  final String text;
  final bool bold;
  const InlineSegment(this.text, {this.bold = false});
}

/// Memecah `**tebal**` jadi rangkaian [InlineSegment].
///
/// Sengaja bukan Markdown penuh — hanya penegasan yang dipakai naskahnya, jadi
/// tidak ada pustaka baru yang harus ditambahkan (dan tidak ada pihak ketiga
/// baru yang harus dideklarasikan di Data safety).
List<InlineSegment> parseInline(String source) {
  final segments = <InlineSegment>[];
  var index = 0;
  var bold = false;

  while (index < source.length) {
    final marker = source.indexOf('**', index);
    if (marker < 0) {
      segments.add(InlineSegment(source.substring(index), bold: bold));
      break;
    }
    if (marker > index) {
      segments.add(InlineSegment(source.substring(index, marker), bold: bold));
    }
    bold = !bold;
    index = marker + 2;
  }
  // Penanda ganjil (mis. `**` yang lupa ditutup) tidak boleh menelan sisa teks;
  // sisanya sudah ikut terdorong pada cabang `marker < 0` di atas.
  return segments.where((s) => s.text.isNotEmpty).toList(growable: false);
}

/// Membuang penanda `**` — dipakai untuk judul.
String stripInline(String source) => source.replaceAll('**', '');
