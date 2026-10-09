import 'package:reindeer/features/adherence/domain/dose_timeline.dart';
import 'package:reindeer/features/adherence/domain/models/dose_log.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';

/// Stored in a plan's "what is it for" so TB medicines can be told apart.
const tbCondition = 'Tuberculosis (DOTS)';

/// Standard daily regimen for drug-sensitive TB in India: two months of four
/// medicines (intensive phase), then four months of three (continuation).
const tbIntensiveDays = 56;
const tbContinuationDays = 112;
const tbTotalDays = tbIntensiveDays + tbContinuationDays;

enum TbPhase { notStarted, intensive, continuation, completed }

/// Tablets of the daily fixed-dose combination by body weight (adult chart).
/// The doctor's card always wins; this only suggests a starting number.
class WeightBand {
  const WeightBand(this.label, this.tablets);
  final String label;
  final int tablets;
}

const weightBands = <WeightBand>[
  WeightBand('25 to 34 kg', 2),
  WeightBand('35 to 49 kg', 3),
  WeightBand('50 to 64 kg', 4),
  WeightBand('65 to 79 kg', 5),
  WeightBand('80 kg or more', 5),
];

/// One person's TB treatment: when it started and who watches the doses.
class TbProgramme {
  const TbProgramme({
    required this.start,
    required this.supporterName,
    this.supporterPhone = '',
    this.nikshayId = '',
    this.pinHash = '',
  });

  final DateTime start;
  final String supporterName;
  final String supporterPhone;
  final String nikshayId;
  final String pinHash;

  DateTime get firstDay => dateOnly(start);

  /// Day 1 is the start date.
  int dayNumber(DateTime today) {
    final a = DateTime.utc(firstDay.year, firstDay.month, firstDay.day);
    final b = DateTime.utc(today.year, today.month, today.day);
    return b.difference(a).inDays + 1;
  }

  TbPhase phaseOn(DateTime today) {
    final n = dayNumber(today);
    if (n < 1) return TbPhase.notStarted;
    if (n <= tbIntensiveDays) return TbPhase.intensive;
    if (n <= tbTotalDays) return TbPhase.continuation;
    return TbPhase.completed;
  }

  DateTime dateOfDay(int n) =>
      DateTime(firstDay.year, firstDay.month, firstDay.day + n - 1);

  DateTime get lastDay => dateOfDay(tbTotalDays);

  int daysLeft(DateTime today) {
    final left = tbTotalDays - dayNumber(today);
    return left < 0 ? 0 : left;
  }

  /// Fraction of the six months gone, 0..1.
  double progress(DateTime today) =>
      (dayNumber(today) / tbTotalDays).clamp(0.0, 1.0);

  /// Check-ups to ask the TB centre about. Dates are the usual ones; the
  /// health worker decides.
  List<TbFollowUp> followUps() => [
    TbFollowUp('Sputum test, end of month 2', dateOfDay(tbIntensiveDays)),
    TbFollowUp('Sputum test, end of month 5', dateOfDay(140)),
    TbFollowUp('End of treatment check', dateOfDay(tbTotalDays)),
  ];

  TbProgramme copyWith({
    DateTime? start,
    String? supporterName,
    String? supporterPhone,
    String? nikshayId,
    String? pinHash,
  }) => TbProgramme(
    start: start ?? this.start,
    supporterName: supporterName ?? this.supporterName,
    supporterPhone: supporterPhone ?? this.supporterPhone,
    nikshayId: nikshayId ?? this.nikshayId,
    pinHash: pinHash ?? this.pinHash,
  );
}

class TbFollowUp {
  const TbFollowUp(this.label, this.date);
  final String label;
  final DateTime date;
}

/// Not a security feature: it only stops a patient from ticking the
/// supporter's box by accident. FNV-1a over a fixed prefix and the PIN.
String hashPin(String pin) {
  var h = 0x811c9dc5;
  for (final c in 'reindeer-dots:${pin.trim()}'.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

bool isValidPin(String pin) => RegExp(r'^[0-9]{4}$').hasMatch(pin.trim());

/// How TB doses have gone. Built from dose entries and the doses a supporter
/// has confirmed (keys are [PlannedDose.key]).
class TbAdherence {
  const TbAdherence({
    required this.taken,
    required this.missed,
    required this.skipped,
    required this.observed,
    required this.missedDaysInARow,
  });

  final int taken;
  final int missed;
  final int skipped;

  /// Taken doses a supporter watched.
  final int observed;

  /// Whole days at the end of the record on which every dose was missed.
  final int missedDaysInARow;

  int get resolved => taken + missed + skipped;

  double? get takenFraction => resolved == 0 ? null : taken / resolved;

  double? get observedFraction => taken == 0 ? null : observed / taken;

  static TbAdherence from(
    List<DoseEntry> entries,
    Set<String> observedKeys,
    DateTime now,
  ) {
    var taken = 0, missed = 0, skipped = 0, observed = 0;
    final byDay = <DateTime, List<DoseStatus>>{};
    for (final e in entries) {
      if (e.plan.condition != tbCondition) continue;
      if (e.dose.at.isAfter(now)) continue;
      switch (e.status) {
        case DoseStatus.taken:
          taken++;
          if (observedKeys.contains(e.dose.key)) observed++;
        case DoseStatus.missed:
          missed++;
        case DoseStatus.skipped:
          skipped++;
        case DoseStatus.scheduled:
        case DoseStatus.snoozed:
          continue;
      }
      byDay.putIfAbsent(dateOnly(e.dose.at), () => []).add(e.status);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    var streak = 0;
    for (final d in days) {
      if (byDay[d]!.every((s) => s == DoseStatus.missed)) {
        streak++;
      } else {
        break;
      }
    }
    return TbAdherence(
      taken: taken,
      missed: missed,
      skipped: skipped,
      observed: observed,
      missedDaysInARow: streak,
    );
  }
}

/// Text for the health worker. Always English so it can be read by anyone.
String buildDotsReport({
  required String patient,
  required TbProgramme programme,
  required TbAdherence adherence,
  required DateTime today,
}) {
  String d(DateTime x) => formatLongDate(x);
  String pct(double? f) => f == null ? 'no data yet' : '${(f * 100).round()}%';
  final phase = switch (programme.phaseOn(today)) {
    TbPhase.notStarted => 'not started',
    TbPhase.intensive => 'intensive phase',
    TbPhase.continuation => 'continuation phase',
    TbPhase.completed => 'course finished',
  };
  final b = StringBuffer()
    ..writeln('TB treatment report (Reindeer)')
    ..writeln('Patient: ${patient.isEmpty ? '-' : patient}')
    ..writeln(
      'Nikshay ID: ${programme.nikshayId.isEmpty ? '-' : programme.nikshayId}',
    )
    ..writeln('Treatment started: ${d(programme.firstDay)}')
    ..writeln(
      'Day ${programme.dayNumber(today)} of $tbTotalDays ($phase), expected end ${d(programme.lastDay)}',
    )
    ..writeln('Treatment supporter: ${programme.supporterName}')
    ..writeln()
    ..writeln('Doses taken: ${adherence.taken}')
    ..writeln('Doses missed: ${adherence.missed}')
    ..writeln('Doses skipped: ${adherence.skipped}')
    ..writeln('Taken of those due: ${pct(adherence.takenFraction)}')
    ..writeln(
      'Taken doses watched by supporter: ${adherence.observed} (${pct(adherence.observedFraction)})',
    );
  if (adherence.missedDaysInARow > 0) {
    b.writeln('Days missed in a row at the end: ${adherence.missedDaysInARow}');
  }
  b
    ..writeln()
    ..writeln('Self-recorded in the app; not a medical record.');
  return b.toString();
}

/// Message to the supporter after a dose or a miss.
String supporterMessage({
  required String patient,
  required bool missed,
  required int day,
}) {
  final who = patient.isEmpty ? 'I' : patient;
  return missed
      ? '$who missed today\'s TB medicine (day $day of $tbTotalDays). '
            'Please check in with me.'
      : '$who took today\'s TB medicine (day $day of $tbTotalDays).';
}
