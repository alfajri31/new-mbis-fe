import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Notifikasi bawah "isian wajib belum lengkap" — dipakai form panjang
/// (Tambah Pipeline, Ajukan Agen) supaya user tahu APA yang kurang tanpa harus
/// menyusuri layar sendiri.
///
/// Sebelumnya layar otomatis di-scroll ke field bermasalah, tapi itu justru
/// membingungkan karena posisi melompat. Pola yang dipakai sekarang sama dengan
/// notifikasi proses tender: pop-up di bawah yang MENYEBUT nama isiannya.
void showMissingFieldsNotice(
  ScaffoldMessengerState messenger,
  List<String> labels, {
  /// Maksimal nama yang ditulis; sisanya diringkas jadi "+n lainnya" supaya
  /// snackbar tidak menutupi separuh layar pada form yang benar-benar kosong.
  int maxShown = 4,
}) {
  if (labels.isEmpty) return;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: AppColors.errorRed,
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
      content: missingFieldsContent(labels, maxShown: maxShown),
    ),
  );
}

/// Isi notifikasi (judul + nama isian yang kurang) tanpa wadahnya.
///
/// Dipisah supaya form yang tampil sebagai **bottom sheet** bisa memakai
/// redaksi yang sama secara inline: di dalam sheet, snackbar dirender oleh
/// `ScaffoldMessenger` milik halaman DI BELAKANG sheet sehingga tertutup dan
/// baru terlihat setelah sheet ditutup (TEMUAN-01).
Widget missingFieldsContent(
  List<String> labels, {
  int maxShown = 4,
  Color color = Colors.white,
}) {
  final shown = labels.take(maxShown).toList();
  final sisa = labels.length - shown.length;

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        labels.length == 1
            ? '1 isian wajib belum lengkap'
            : '${labels.length} isian wajib belum lengkap',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: color,
        ),
      ),
      const SizedBox(height: 4),
      for (final label in shown)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('• $label', style: TextStyle(fontSize: 12, color: color)),
        ),
      if (sisa > 0)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '• +$sisa lainnya',
            style: TextStyle(fontSize: 12, color: color),
          ),
        ),
    ],
  );
}

/// Kotak pesan merah **di dalam** form/sheet — pengganti snackbar untuk konten
/// yang muncul di atas halaman (modal bottom sheet), lihat [missingFieldsContent].
class InlineErrorNotice extends StatelessWidget {
  final Widget child;
  const InlineErrorNotice({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.redLight,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.errorRed),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.errorRed),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}
