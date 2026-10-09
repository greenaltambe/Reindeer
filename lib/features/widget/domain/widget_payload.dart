import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/adherence/domain/dose_timeline.dart';
import 'package:reindeer/features/adherence/domain/models/dose_log.dart';

/// One row on the home-screen widget.
class WidgetRow {
  const WidgetRow({required this.key, required this.text, required this.late});

  /// The dose identity (`PlannedDose.key`), used when it is ticked off.
  final String key;
  final String text;

  /// The dose time has already passed and it is still waiting.
  final bool late;
}

/// What the home-screen widget shows.
class WidgetPayload {
  const WidgetPayload({
    required this.header,
    required this.rows,
    this.footer = '',
  });

  final String header;
  final List<WidgetRow> rows;

  /// Extra line, for example which medicines are running low.
  final String footer;

  /// Plain text sent to the Android side. Line 1 is the header, then one line
  /// per dose as `L<tab>key<tab>text` (late) or `N<tab>key<tab>text`, then an
  /// optional `F<tab>text` footer.
  String encode() => [
    header,
    for (final r in rows) '${r.late ? 'L' : 'N'}\t${r.key}\t${r.text}',
    if (footer.isNotEmpty) 'F\t$footer',
  ].join('\n');
}

/// Builds the widget content from today's and tomorrow's doses.
///
/// [entries] may span several days. Only waiting doses are listed (at most
/// [maxRows]); the header counts today's doses that are done.
WidgetPayload buildWidgetPayload(
  List<DoseEntry> entries,
  DateTime now, {
  int maxRows = 4,
}) {
  final today = dateOnly(now);
  final todays = [
    for (final e in entries)
      if (dateOnly(e.dose.at) == today) e,
  ];
  final done = todays.where((e) => e.status == DoseStatus.taken).length;
  final pending = [
    for (final e in entries)
      if (e.isPending) e,
  ]..sort((a, b) => a.dose.at.compareTo(b.dose.at));

  final String header;
  if (entries.isEmpty) {
    header = 'No medicines yet';
  } else if (todays.isEmpty) {
    header = 'Nothing due today';
  } else if (pending.every((e) => dateOnly(e.dose.at) != today)) {
    header = 'All done today ($done of ${todays.length})';
  } else {
    header = 'Today: $done of ${todays.length} taken';
  }

  final rows = <WidgetRow>[];
  for (final e in pending.take(maxRows)) {
    final day = dateOnly(e.dose.at);
    final when = day == today
        ? formatTime(e.dose.at)
        : 'Tomorrow ${formatTime(e.dose.at)}';
    final amount = e.plan.doseUnit.describe(e.dose.amount);
    rows.add(
      WidgetRow(
        key: e.dose.key,
        text: '$when  ${e.plan.name} · $amount',
        late: e.dose.at.isBefore(now),
      ),
    );
  }
  final low = <String>{
    for (final e in entries)
      if (e.plan.isLowStock) e.plan.name,
  };
  final footer = low.isEmpty ? '' : 'Running low: ${low.take(2).join(', ')}';
  return WidgetPayload(header: header, rows: rows, footer: footer);
}
