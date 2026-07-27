import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tampilan badge status satu jadwal kunjungan.
class ScheduleBadge {
  const ScheduleBadge(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

/// Ember waktu sebuah jadwal: `today` | `upcoming` | `overdue`.
///
/// CERMINAN dari `DashboardService.toTimeBucket` di backend: dibandingkan
/// per-TANGGAL (bukan per-jam), sehingga jadwal pukul 06.19 hari kemarin tetap
/// "overdue" sepanjang hari ini. Dashboard memakai nilai dari server; layar
/// pipeline menghitungnya sendiri dari tanggal jadwal karena API pipeline hanya
/// mengirim status persistensi (OPEN/DONE/CANCELLED).
String scheduleTimeBucket(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final d = DateTime(date.year, date.month, date.day);
  final t = DateTime(today.year, today.month, today.day);
  if (d.isAtSameMomentAs(t)) return 'today';
  return d.isAfter(t) ? 'upcoming' : 'overdue';
}

/// Label + warna untuk sebuah ember waktu. SATU-SATUNYA tempat pemetaan ini
/// ditulis — dulu dashboard dan detail pipeline memakai aturannya masing-masing,
/// sehingga jadwal yang sama bisa tampil "Terlambat" di dashboard tapi
/// "Mendatang" saat dibuka dari customer.
ScheduleBadge scheduleBadgeOf(String? bucket) {
  switch ((bucket ?? '').toLowerCase()) {
    case 'today':
      return const ScheduleBadge(
        'Hari ini',
        AppColors.secondaryOrange,
        Icons.access_time,
      );
    case 'overdue':
      return const ScheduleBadge(
        'Terlambat',
        AppColors.errorRed,
        Icons.error_outline,
      );
    case 'upcoming':
      return const ScheduleBadge(
        'Mendatang',
        AppColors.primaryNavy,
        Icons.calendar_today,
      );
    default:
      return const ScheduleBadge(
        'Terjadwal',
        AppColors.primaryNavy,
        Icons.calendar_today,
      );
  }
}

/// Badge untuk satu jadwal pipeline: status persistensi menang (Selesai /
/// Dibatalkan), selebihnya dihitung dari tanggalnya.
ScheduleBadge pipelineScheduleBadge({
  required String status,
  required String? isoDate,
  DateTime? now,
}) {
  switch (status.toUpperCase()) {
    case 'DONE':
      return const ScheduleBadge(
        'Selesai',
        AppColors.successGreen,
        Icons.check_circle_outline,
      );
    case 'CANCELLED':
      return const ScheduleBadge(
        'Dibatalkan',
        AppColors.grayStage,
        Icons.cancel_outlined,
      );
  }
  final parsed = DateTime.tryParse(isoDate ?? '')?.toLocal();
  if (parsed == null) return scheduleBadgeOf(null);
  return scheduleBadgeOf(scheduleTimeBucket(parsed, now: now));
}
