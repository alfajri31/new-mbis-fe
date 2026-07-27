import 'package:flutter/widgets.dart';

/// Menjalankan [onDispose] saat [child] benar-benar dilepas dari widget tree.
///
/// Dipakai untuk isi `showModalBottomSheet` / `showDialog` yang memiliki
/// `TextEditingController` lokal. Future dari kedua fungsi itu selesai saat
/// route **di-pop**, PADAHAL route-nya masih dianimasikan keluar dan isinya
/// masih di-rebuild beberapa frame lagi. Membuang controller tepat setelah
/// `await` membuat rebuild sisa itu menyentuh controller yang sudah mati:
///
///   A TextEditingController was used after being disposed
///   → '_dependents.isEmpty': is not true        (layar merah, seluruh app)
///   → Tried to build dirty widget in the wrong build scope
///
/// Bug itu muncul kalau ada rebuild ekstra selama animasi keluar — mis. rotasi
/// layar, keyboard menutup, atau tekan Back beruntun. Dengan widget ini
/// pembuangan mengikuti daur hidup elemen (dipanggil setelah animasi selesai),
/// bukan waktu penyelesaian future.
class DisposeCallback extends StatefulWidget {
  const DisposeCallback({
    super.key,
    required this.onDispose,
    required this.child,
  });

  /// Dipanggil sekali, saat state dibuang. Tempat memanggil `controller.dispose()`.
  final VoidCallback onDispose;

  final Widget child;

  @override
  State<DisposeCallback> createState() => _DisposeCallbackState();
}

class _DisposeCallbackState extends State<DisposeCallback> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
