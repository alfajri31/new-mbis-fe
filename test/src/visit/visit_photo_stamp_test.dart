import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mbis/src/visit/visit_photo_stamp.dart';

/// Mengunci ISI cap yang ditanam ke foto kunjungan (CR-12 / MTR-7).
///
/// Yang diuji baris teksnya, bukan pikselnya: penyusunan baris inilah yang memuat
/// aturan bisnisnya (label zona waktu ikut dicetak, koordinat tetap tampil walau
/// alamatnya kosong), sedangkan penggambarannya milik paket `image`.
/// Pemisah baris, dibangun dari kode karakternya supaya escape-nya tidak bisa
/// tergerus alat penyunting apa pun — bug yang diuji di sini justru soal newline.
final String newline = String.fromCharCode(10);

void main() {
  group('VisitPhotoStamp - baris cap', () {
    final takenAt = DateTime(2026, 8, 18, 9, 5);

    test('baris pertama selalu waktu + label zona', () {
      final lines = VisitPhotoStamp.buildLinesForTest(
        takenAt: takenAt,
        timeZoneLabel: 'WITA',
      );

      // Label zona WAJIB ikut: satu perusahaan memakai tiga zona, jadi "09:05"
      // tanpa keterangan zona bukan bukti waktu yang bisa dipakai.
      expect(lines.first, '18 Agu 2026 09:05 WITA');
    });

    test('alamat dan koordinat dicetak keduanya bila tersedia', () {
      final lines = VisitPhotoStamp.buildLinesForTest(
        takenAt: takenAt,
        timeZoneLabel: 'WIB',
        locationLabel: 'Jl. Sudirman No. 1, Jakarta',
        latitude: -6.208763,
        longitude: 106.845599,
      );

      expect(lines, hasLength(3));
      expect(lines[1], 'Jl. Sudirman No. 1, Jakarta');
      expect(lines[2], '-6.208763, 106.845599');
    });

    test('koordinat tetap tercetak walau geocoding gagal (alamat kosong)', () {
      // Kunjungan di daerah tanpa sinyal sering gagal geocoding. Kalau koordinatnya
      // ikut hilang, foto kehilangan seluruh bukti lokasinya.
      final lines = VisitPhotoStamp.buildLinesForTest(
        takenAt: takenAt,
        timeZoneLabel: 'WIB',
        locationLabel: '   ',
        latitude: -6.2,
        longitude: 106.8,
      );

      expect(lines, hasLength(2));
      expect(lines[1], '-6.200000, 106.800000');
    });

    test('label multi-baris dipecah, koordinat tidak kembar', () {
      // Regresi on-device 2026-08-18: layar kunjungan menyusun labelnya sebagai
      // alamat + baris baru + koordinat. Diserahkan bulat-bulat ke penggambar
      // satu-baris, bagian sesudah baris baru tertimpa di baris yang sama sehingga
      // koordinatnya tak terbaca.
      final lines = VisitPhotoStamp.buildLinesForTest(
        takenAt: takenAt,
        timeZoneLabel: 'WIB',
        locationLabel:
            'Jalan Selangit, Kemayoran, Jakarta Pusat$newline-6.15602, 106.84431',
        latitude: -6.156022,
        longitude: 106.844305,
      );

      for (final line in lines) {
        expect(line, isNot(contains(newline)),
            reason: 'baris cap tidak boleh multi-baris');
      }
      expect(lines, hasLength(3));
      expect(lines[1], 'Jalan Selangit, Kemayoran, Jakarta Pusat');
      expect(lines[2], '-6.156022, 106.844305');
    });

    test('label yang HANYA koordinat (geocoding gagal) tidak jadi dua baris kembar', () {
      final lines = VisitPhotoStamp.buildLinesForTest(
        takenAt: takenAt,
        timeZoneLabel: 'WIB',
        locationLabel: '-6.15602, 106.84431',
        latitude: -6.156022,
        longitude: 106.844305,
      );

      expect(lines, hasLength(2));
      expect(lines[1], '-6.156022, 106.844305');
    });

    test('tanpa lokasi sama sekali, cap tetap berisi waktu', () {
      final lines = VisitPhotoStamp.buildLinesForTest(
        takenAt: takenAt,
        timeZoneLabel: 'WIT',
      );

      expect(lines, hasLength(1));
    });

    test('koordinat parsial (lat tanpa lng) tidak dicetak setengah-setengah', () {
      final lines = VisitPhotoStamp.buildLinesForTest(
        takenAt: takenAt,
        timeZoneLabel: 'WIB',
        latitude: -6.2,
      );

      expect(lines, hasLength(1));
    });
  });

  group('VisitPhotoStamp - tata letak baris', () {
    final font = img.arial24;

    int widthOf(String s) {
      var w = 0;
      for (final c in s.codeUnits) {
        w += font.characters[c]?.xAdvance ?? (font.base ~/ 2);
      }
      return w;
    }

    test('alamat panjang dipecah agar tidak melewati lebar gambar', () {
      // Regresi dari temuan on-device 2026-08-18: alamat hasil geocoding lebih lebar
      // daripada fotonya, drawString menulis menembus akhir buffer piksel, dan
      // kelebihannya MELINGKAR ke bagian atas gambar — cap tampak tercetak dua kali.
      const alamat =
          'Jalan Selangit, RW 10, Gunung Sahari Selatan, Kemayoran, Jakarta Pusat, '
          'Daerah Khusus Ibukota Jakarta, 10620, Indonesia';
      const maxWidth = 600;

      final lines = layoutStampLines(font, ['18 Agu 2026 14:58 WIB', alamat], maxWidth);

      expect(lines.length, greaterThan(2), reason: 'alamat panjang harus terpecah');
      for (final line in lines) {
        expect(widthOf(line), lessThanOrEqualTo(maxWidth), reason: 'baris "$line" meluber');
      }
    });

    test('kata tunggal yang lebih lebar dari gambar dipotong, bukan diloloskan', () {
      final lines = layoutStampLines(font, ['-6.156023,106.844319'], 60);

      expect(lines, isNotEmpty);
      for (final line in lines) {
        expect(widthOf(line), lessThanOrEqualTo(60));
      }
    });

    test('panel dibatasi agar tidak menelan foto', () {
      final banyak = List.generate(20, (i) => 'baris ke-$i yang cukup panjang untuk dipecah');

      final lines = layoutStampLines(font, banyak, 300, maxLines: 6);

      expect(lines, hasLength(6));
    });

    test('teks yang sudah muat dibiarkan utuh', () {
      final lines = layoutStampLines(font, ['18 Agu 2026 14:58 WIB'], 5000);

      expect(lines, ['18 Agu 2026 14:58 WIB']);
    });
  });
}
