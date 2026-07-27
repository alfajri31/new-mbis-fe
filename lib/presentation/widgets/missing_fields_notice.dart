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
  final shown = labels.take(maxShown).toList();
  final sisa = labels.length - shown.length;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: AppColors.errorRed,
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labels.length == 1
                ? '1 isian wajib belum lengkap'
                : '${labels.length} isian wajib belum lengkap',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          for (final label in shown)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '• $label',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          if (sisa > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '• +$sisa lainnya',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    ),
  );
}
