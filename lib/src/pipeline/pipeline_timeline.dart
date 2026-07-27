import '../visit/visit_repository.dart';
import 'pipeline_repository.dart';

/// What produced a timeline entry. Drives the icon/colour and the EDIT filter.
enum TimelineKind { stage, edit, visit }

/// One row of the merged "Riwayat": pipeline stage changes, field edits, and
/// visits on a single chronological axis.
///
/// Both sources are merged client-side rather than server-side because every
/// screen that shows the timeline already fetches both lists — a merged endpoint
/// would be a third round-trip for data we hold.
class TimelineEntry {
  final TimelineKind kind;
  final DateTime at;
  final String title;
  final String? detail;
  final String? actorName;

  /// Set only for [TimelineKind.visit], so the card can open the visit detail
  /// sheet (mini-map + photo). Null for stage/edit entries.
  final VisitModel? visit;

  const TimelineEntry({
    required this.kind,
    required this.at,
    required this.title,
    this.detail,
    this.actorName,
    this.visit,
  });

  bool get isEdit => kind == TimelineKind.edit;
}

/// Merges stage/edit history with visits, newest first.
///
/// Entries whose timestamp can't be parsed are dropped rather than defaulted:
/// an entry at the wrong position in a chronological list is worse than one
/// that's absent, since it silently misrepresents what happened when.
List<TimelineEntry> mergePipelineTimeline({
  required List<PipelineHistoryModel> history,
  required List<VisitModel> visits,
  bool includeEdits = true,
}) {
  final entries = <TimelineEntry>[];

  for (final h in history) {
    final at = DateTime.tryParse(h.changedAt ?? '');
    if (at == null) continue;
    if (h.isEdit && !includeEdits) continue;
    entries.add(TimelineEntry(
      kind: h.isEdit ? TimelineKind.edit : TimelineKind.stage,
      at: at.toLocal(),
      title: h.note ?? (h.isEdit ? 'Pipeline diubah' : 'Perubahan status'),
      actorName: h.changedByName,
    ));
  }

  for (final v in visits) {
    final at = DateTime.tryParse(v.activityDate ?? '');
    if (at == null) continue;
    entries.add(TimelineEntry(
      kind: TimelineKind.visit,
      at: at.toLocal(),
      title: _visitTitle(v.type),
      detail: (v.notes != null && v.notes!.trim().isNotEmpty) ? v.notes!.trim() : null,
      visit: v,
    ));
  }

  entries.sort((a, b) => b.at.compareTo(a.at));
  return entries;
}

String _visitTitle(String? type) {
  switch (type) {
    case 'CALL':
      return 'Telepon';
    case 'ONLINE':
      return 'Pertemuan online';
    case 'ADMIN':
      return 'Aktivitas admin';
    case 'VISIT':
    default:
      return 'Kunjungan';
  }
}
