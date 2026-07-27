import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/utils/schedule_status.dart';

/// Regresi BUG RM: satu jadwal yang sama tampil "Terlambat" di dashboard tapi
/// "Mendatang" saat dibuka lewat halaman customer. Penyebabnya dua aturan yang
/// berbeda — dashboard memakai ember waktu dari server, kartu pipeline hanya
/// membedakan DONE vs bukan-DONE. Sekarang keduanya lewat helper ini.
void main() {
  final now = DateTime(2026, 7, 23, 9, 0);

  group('scheduleTimeBucket (cermin DashboardService.toTimeBucket)', () {
    test('kemarin = overdue, walau jamnya pagi', () {
      expect(
        scheduleTimeBucket(DateTime(2026, 7, 22, 6, 19), now: now),
        'overdue',
      );
    });

    test('hari ini = today, walau jamnya sudah lewat', () {
      expect(
        scheduleTimeBucket(DateTime(2026, 7, 23, 6, 19), now: now),
        'today',
      );
    });

    test('besok = upcoming', () {
      expect(
        scheduleTimeBucket(DateTime(2026, 7, 24, 6, 19), now: now),
        'upcoming',
      );
    });
  });

  group('pipelineScheduleBadge', () {
    test('OPEN yang tanggalnya lewat = Terlambat, bukan Mendatang', () {
      final badge = pipelineScheduleBadge(
        status: 'OPEN',
        isoDate: '2026-07-22T06:19:00',
        now: now,
      );
      expect(badge.label, 'Terlambat');
      expect(
        badge.label,
        scheduleBadgeOf('overdue').label,
        reason: 'harus sama persis dengan label dashboard',
      );
    });

    test('OPEN hari ini = Hari ini', () {
      expect(
        pipelineScheduleBadge(
          status: 'OPEN',
          isoDate: '2026-07-23T15:00:00',
          now: now,
        ).label,
        'Hari ini',
      );
    });

    test('OPEN mendatang = Mendatang', () {
      expect(
        pipelineScheduleBadge(
          status: 'OPEN',
          isoDate: '2026-07-25T15:00:00',
          now: now,
        ).label,
        'Mendatang',
      );
    });

    test('status persistensi menang atas tanggal', () {
      expect(
        pipelineScheduleBadge(
          status: 'DONE',
          isoDate: '2026-07-22T06:19:00',
          now: now,
        ).label,
        'Selesai',
      );
      expect(
        pipelineScheduleBadge(
          status: 'CANCELLED',
          isoDate: '2026-07-22T06:19:00',
          now: now,
        ).label,
        'Dibatalkan',
      );
    });

    test('tanggal tak terbaca tidak melempar exception', () {
      expect(
        pipelineScheduleBadge(status: 'OPEN', isoDate: null, now: now).label,
        'Terjadwal',
      );
    });
  });
}
