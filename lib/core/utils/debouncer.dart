import 'dart:async';
import 'package:flutter/foundation.dart';

/// Menunda eksekusi sebuah aksi sampai [duration] berlalu tanpa panggilan baru.
///
/// Dipakai pada search bar agar tiap ketukan tidak langsung memanggil server
/// (atau memfilter ulang list besar) — hanya panggilan terakhir dalam jeda
/// [duration] yang dijalankan. Mengganti pola `Timer? _debounce` yang sebelumnya
/// disalin berulang di beberapa layar.
///
/// Ingat memanggil [dispose] di `State.dispose()` agar timer yang menggantung
/// dibatalkan saat layar ditutup.
class Debouncer {
  Debouncer({this.duration = const Duration(milliseconds: 400)});

  final Duration duration;
  Timer? _timer;

  /// Jadwalkan [action]; membatalkan aksi tertunda sebelumnya bila ada.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Batalkan aksi tertunda tanpa menjalankannya (mis. saat kolom di-clear atau
  /// pengguna menekan submit sehingga pencarian dijalankan segera).
  void cancel() => _timer?.cancel();

  /// Apakah ada aksi yang masih menunggu dijalankan.
  bool get isActive => _timer?.isActive ?? false;

  void dispose() => _timer?.cancel();
}
