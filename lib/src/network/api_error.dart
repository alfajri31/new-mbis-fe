import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;

/// Mengubah error jaringan/exception apa pun jadi kalimat yang boleh dilihat
/// pengguna.
///
/// Sebelumnya layar-layar admin menampilkan `e.toString()` apa adanya, sehingga
/// yang muncul di layar berupa teks teknis lengkap dengan URL endpoint, mis.
///
///   ClientException: Connection closed before full header was received,
///   uri=http://localhost:8080/api/rm-handovers/RH-123/revert
///
/// Selain tak bisa dipahami pengguna, itu juga membocorkan alamat internal API.
///
/// [operationHint] dipakai untuk kasus koneksi putus di tengah operasi yang
/// MENGUBAH data (pindah RM, pemindahan cabang): servernya bisa jadi sudah
/// selesai walau klien menyerah menunggu, jadi pesannya menyarankan menyegarkan
/// alih-alih menyatakan operasinya gagal.
String friendlyError(
  Object error, {
  String fallback = 'Terjadi kesalahan. Coba lagi.',
  bool operationMayHaveSucceeded = false,
}) {
  final unfinished = operationMayHaveSucceeded
      ? ' Perubahan mungkin sudah tersimpan di server — tarik layar untuk menyegarkan sebelum mencoba lagi.'
      : '';

  if (error is TimeoutException) {
    return 'Server terlalu lama merespons.$unfinished';
  }
  if (error is SocketException) {
    return 'Tidak dapat terhubung ke server. Periksa koneksi Anda, lalu coba lagi.';
  }
  if (error is ClientException) {
    // Termasuk "Connection closed before full header was received" — biasanya
    // request panjang yang diputus klien/proxy, bukan kesalahan pengguna.
    return 'Koneksi ke server terputus.$unfinished';
  }
  if (error is HttpException) {
    return 'Server tidak merespons dengan benar.$unfinished';
  }

  // Exception buatan repository sudah berisi pesan dari backend (message JSON):
  // tampilkan apa adanya setelah membuang awalan teknis.
  final text = error.toString().replaceFirst('Exception: ', '').trim();
  if (text.isEmpty) return fallback;
  // Jangan pernah tampilkan teks yang masih membawa jejak teknis (URL/kelas).
  if (text.contains('uri=') ||
      text.contains('http://') ||
      text.contains('https://') ||
      text.contains('Exception')) {
    return fallback;
  }
  return text;
}
